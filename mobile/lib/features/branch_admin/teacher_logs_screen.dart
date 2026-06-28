import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class TeacherLogsScreen extends StatefulWidget {
  const TeacherLogsScreen({super.key});
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
        logs = data;
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
        appBar: AppBar(title: const Text('Activity Logs')),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : logs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No logs yet',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final log = logs[i];
                        final ts = DateTime.parse(log['timestamp']);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(_icon(log['action']),
                                color: Colors.blue, size: 20),
                          ),
                          title: Text(log['user_name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(_label(log['action'])),
                          trailing: Text(
                            '${ts.day}/${ts.month} '
                            '${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
      );
}
