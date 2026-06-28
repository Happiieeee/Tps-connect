import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 'select' | 'phone' | 'otp'
  String view = 'select';

  final phoneController = TextEditingController();
  final otpController   = TextEditingController();
  String? verificationId;
  bool isLoading = false;
  String? error;

  void _setError(String msg) =>
    setState(() { error = msg; isLoading = false; });

  // ── Send OTP ──────────────────────────────
  Future<void> _sendOtp() async {
    final phone = phoneController.text.trim();
    if (phone.length < 10) {
      _setError('Enter a valid phone number'); return;
    }

    // Prepend +91 if not already international
    final formatted = phone.startsWith('+') ? phone : '+91$phone';

    setState(() { isLoading = true; error = null; });

    await AuthService.sendOtp(
      phoneNumber: formatted,
      onCodeSent: (id) {
        setState(() {
          verificationId = id;
          view = 'otp';
          isLoading = false;
        });
      },
      onError: (msg) => _setError(msg),
    );
  }

  // ── Verify OTP ────────────────────────────
  Future<void> _verifyOtp() async {
    if (otpController.text.trim().length != 6) {
      _setError('Enter the 6-digit OTP'); return;
    }
    setState(() { isLoading = true; error = null; });

    try {
      final user = await AuthService.verifyOtp(
        verificationId: verificationId!,
        otp: otpController.text.trim(),
      );
      if (user != null && mounted) _navigate(user);
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Google Sign-In ────────────────────────
  Future<void> _googleSignIn() async {
    setState(() { isLoading = true; error = null; });
    try {
      final user = await AuthService.signInWithGoogle();
      if (user != null && mounted) _navigate(user);
      else setState(() => isLoading = false);
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Role-based navigation ─────────────────
  void _navigate(Map<String, dynamic> user) {
    final role = user['role'];
    switch (role) {
      case 'superadmin':
        Navigator.pushReplacementNamed(context, '/super-admin');
        break;
      case 'branchadmin':
        Navigator.pushReplacementNamed(context, '/branch-admin');
        break;
      case 'teacher':
        Navigator.pushReplacementNamed(context, '/teacher');
        break;
      case 'parent':
        Navigator.pushReplacementNamed(context, '/parent');
        break;
      default:
        _setError('Unknown role. Contact admin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Logo / brand
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B6D11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('TPS',
                    style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                view == 'otp'
                  ? 'Enter OTP'
                  : view == 'phone'
                    ? 'Parent login'
                    : 'Welcome back',
                style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3A08)),
              ),
              const SizedBox(height: 6),
              Text(
                view == 'otp'
                  ? 'Sent to +91 ${phoneController.text.trim()}'
                  : view == 'phone'
                    ? 'Enter your registered mobile number'
                    : 'How would you like to sign in?',
                style: const TextStyle(
                  fontSize: 14, color: Color(0xFF639922)),
              ),

              const SizedBox(height: 40),

              // ── SELECT VIEW ──────────────────────────
              if (view == 'select') ...[
                // Parent login option
                _optionCard(
                  icon: Icons.phone_android_rounded,
                  title: 'I\'m a parent',
                  subtitle: 'Sign in with mobile number + OTP',
                  color: const Color(0xFF3B6D11),
                  bgColor: const Color(0xFFEAF3DE),
                  onTap: () => setState(() => view = 'phone'),
                ),

                const SizedBox(height: 12),

                // Staff Google option
                _optionCard(
                  icon: Icons.account_circle_rounded,
                  title: 'I\'m staff',
                  subtitle: 'Teachers & admins — sign in with Google',
                  color: const Color(0xFF185FA5),
                  bgColor: const Color(0xFFE6F1FB),
                  onTap: isLoading ? null : _googleSignIn,
                  trailing: isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                ),
              ],

              // ── PHONE VIEW ───────────────────────────
              if (view == 'phone') ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFC0DD97)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Color(0xFFC0DD97)))),
                      child: const Text('+91',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: Color(0xFF3B6D11))),
                    ),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          hintText: 'Mobile number',
                          hintStyle: TextStyle(color: Color(0xFF97C459)),
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        ),
                        style: const TextStyle(
                          fontSize: 16, color: Color(0xFF1A3A08)),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B6D11),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                      : const Text('Send OTP',
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => view = 'select'),
                  child: const Text('← Back',
                    style: TextStyle(color: Color(0xFF639922))),
                ),
              ],

              // ── OTP VIEW ─────────────────────────────
              if (view == 'otp') ...[
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700,
                    letterSpacing: 12, color: Color(0xFF1A3A08)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    hintStyle: const TextStyle(
                      color: Color(0xFFC0DD97), letterSpacing: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFC0DD97))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFC0DD97))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B6D11), width: 2)),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B6D11),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                      : const Text('Verify OTP',
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () =>
                        setState(() { view = 'phone'; otpController.clear(); }),
                      child: const Text('← Change number',
                        style: TextStyle(color: Color(0xFF639922))),
                    ),
                    TextButton(
                      onPressed: isLoading ? null : _sendOtp,
                      child: const Text('Resend OTP',
                        style: TextStyle(color: Color(0xFF639922))),
                    ),
                  ],
                ),
              ],

              // Error message
              if (error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF09595)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                      color: Color(0xFFA32D2D), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error!,
                        style: const TextStyle(
                          color: Color(0xFFA32D2D), fontSize: 13))),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback? onTap,
    Widget? trailing,
  }) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFC0DD97)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A3A08))),
                const SizedBox(height: 2),
                Text(subtitle,
                  style: const TextStyle(
                    fontSize: 12, color: Color(0xFF97C459))),
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right, color: color, size: 20),
        ]),
      ),
    );
}
