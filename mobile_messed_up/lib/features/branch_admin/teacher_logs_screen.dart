import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../config/theme.dart';

class TeacherLogsScreen extends StatefulWidget {
  final bool attendanceOnly;
  const TeacherLogsScreen({super.key, this.attendanceOnly = false});
  @override
  State<TeacherLogsScreen> createState() => _TeacherLogsScreenState();
}

class _TeacherLogsScreenState extends State<TeacherLogsScreen> {
  List<dynamic> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.get('/logs');
      setState(() {
        logs = widget.attendanceOnly
          ? (data as List).where((l) =>
              l['action'].toString().contains('attendance')).toList()
          : (data as List).where((l) =>
              !l['action'].toString().contains('attendance')).toList();
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  IconData _icon(String action) {
    if (action.contains('attendance')) return Icons.check_circle;
    if (action.contains('post')) return Icons.article;
    if (action.contains('leave')) return Icons.event_busy;
    return Icons.history;
  }

  String _label(String action) => action
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
      .join(' ');

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TPSTheme.background,
        appBar: AppBar(
          backgroundColor: TPSTheme.primaryDark,
          foregroundColor: Colors.white,
          title: Text(widget.attendanceOnly
            ? 'Attendance Logs' : 'Activity Logs'),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.attendanceOnly
                            ? Icons.check_circle_outline
                            : Icons.history,
                          size: 48, color: TPSTheme.textLight),
                        const SizedBox(height: 8),
                        Text(widget.attendanceOnly
                          ? 'No attendance logs yet'
                          : 'No activity logs yet',
                            style: const TextStyle(
                              color: TPSTheme.textLight)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final log = logs[i];
                        final ts = DateTime.parse(log['timestamp']);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: TPSTheme.accentLight,
                            child: Icon(_icon(log['action']),
                                color: TPSTheme.primary, size: 20),
                          ),
                          title: Text(log['user_name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: TPSTheme.textDark)),
                          subtitle: Text(_label(log['action']),
                              style: const TextStyle(
                                  color: TPSTheme.textLight)),
                          trailing: Text(
                            '${ts.day}/${ts.month} '
                            '${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: TPSTheme.textHint, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
      );
}
