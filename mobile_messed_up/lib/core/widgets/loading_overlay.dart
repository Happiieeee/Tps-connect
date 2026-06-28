import 'package:flutter/material.dart';
import 'dart:async';
import '../../config/theme.dart';

/// Global loading overlay — shows a spinner card after 2s delay.
/// Zero configuration required — ApiService calls this automatically.
class LoadingOverlay {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static bool _visible = false;
  static int _callCount = 0; // handles concurrent API calls

  static void show(BuildContext context) {
    _callCount++;
    if (_visible) return;

    // Only show if operation takes > 2 seconds
    _timer ??= Timer(const Duration(seconds: 2), () {
      if (!_visible && _callCount > 0) {
        final overlay = Navigator.of(context).overlay ?? Overlay.maybeOf(context);
        if (overlay != null) {
          _visible = true;
          _entry = OverlayEntry(builder: (_) => const _LoadingOverlayWidget());
          overlay.insert(_entry!);
        }
      }
    });
  }

  static void hide() {
    _callCount = (_callCount - 1).clamp(0, 99);
    if (_callCount > 0) return; // still waiting for other calls

    _timer?.cancel();
    _timer = null;

    if (_visible && _entry != null) {
      if (_entry!.mounted) {
        _entry!.remove();
      }
      _entry = null;
      _visible = false;
    }
  }
}

class _LoadingOverlayWidget extends StatefulWidget {
  const _LoadingOverlayWidget();

  @override
  State<_LoadingOverlayWidget> createState() => _LoadingOverlayWidgetState();
}

class _LoadingOverlayWidgetState extends State<_LoadingOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // Dim background, blocks touches
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withOpacity(0.35),
          ),

          // Spinner card
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: TPSTheme.primary.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          TPSTheme.primary),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Loading',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: TPSTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
