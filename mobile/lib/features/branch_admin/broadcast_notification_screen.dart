import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class BroadcastNotificationScreen extends StatefulWidget {
  final List<dynamic> classes;
  const BroadcastNotificationScreen({super.key, required this.classes});

  @override
  State<BroadcastNotificationScreen> createState() =>
      _BroadcastNotificationScreenState();
}

class _BroadcastNotificationScreenState
    extends State<BroadcastNotificationScreen> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  String? selectedClassId;
  bool isSending = false;

  Future<void> _send() async {
    if (titleController.text.trim().isEmpty ||
        bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required')),
      );
      return;
    }

    setState(() => isSending = true);

    try {
      await ApiService.post('/notifications/broadcast', {
        'title': titleController.text.trim(),
        'body': bodyController.text.trim(),
        'class_id': selectedClassId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notification sent!'),
            backgroundColor: Colors.green,
          ),
        );

        titleController.clear();
        bodyController.clear();
        setState(() => selectedClassId = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send notification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target audience
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Send to',
                border: OutlineInputBorder(),
              ),
              value: selectedClassId,
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Entire Branch')),
                ...widget.classes.map<DropdownMenuItem<String>>((c) =>
                    DropdownMenuItem(
                      value: c['class_id'].toString(),
                      child: Text(c['class_name']),
                    )),
              ],
              onChanged: (val) => setState(() => selectedClassId = val),
            ),

            const SizedBox(height: 16),

            // Title
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Body
            TextField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: 'Message *',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSending ? null : _send,
                icon: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(isSending ? 'Sending...' : 'Send Notification'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
