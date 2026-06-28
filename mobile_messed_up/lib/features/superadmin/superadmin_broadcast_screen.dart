import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../config/theme.dart';

class SuperAdminBroadcastScreen extends StatefulWidget {
  const SuperAdminBroadcastScreen({super.key});
  @override
  State<SuperAdminBroadcastScreen> createState() =>
      _SuperAdminBroadcastScreenState();
}

class _SuperAdminBroadcastScreenState
    extends State<SuperAdminBroadcastScreen> {
  final titleController = TextEditingController();
  final bodyController  = TextEditingController();
  List<dynamic> branches = [];
  String? selectedBranchId;
  bool isSending = false;
  bool isLoading = true;

  // null = all branches, branchId = specific branch
  String targetLabel = 'All branches (entire network)';

  @override
  void initState() { super.initState(); _loadBranches(); }

  Future<void> _loadBranches() async {
    try {
      final data = await ApiService.get('/superadmin/branches');
      setState(() { branches = data; isLoading = false; });
    } catch (_) { setState(() => isLoading = false); }
  }

  Future<void> _send() async {
    if (titleController.text.trim().isEmpty ||
        bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Title and message are required')));
      return;
    }
    setState(() => isSending = true);
    try {
      // For global/branch broadcasts, we can use category 'circular' as a default if not selectable.
      // Assuming backend expects a category for POST /posts. Wait, does the API expect category?
      // Yes, POST /posts expects title and category. Let's send category: 'circular'.
      await ApiService.post('/posts', {
        'title': titleController.text.trim(),
        'content':  bodyController.text.trim(),
        'category': 'circular', // Defaulting to circular for super admin broadcast.
        if (selectedBranchId != null) 'target_branch_id': selectedBranchId,
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sent to $targetLabel'),
        backgroundColor: Colors.green));
      titleController.clear();
      bodyController.clear();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to send'),
        backgroundColor: Colors.red));
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        title: const Text('Broadcast Notification'),
        foregroundColor: Colors.white,
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Target selector
                const Text('Send to',
                  style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TPSTheme.textDark)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: TPSTheme.accentBorder),
                    borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    // All branches option
                    RadioListTile<String?>(
                      value: null,
                      groupValue: selectedBranchId,
                      title: const Text('All branches (entire network)',
                        style: TextStyle(
                          fontSize: 13, color: TPSTheme.textDark)),
                      activeColor: TPSTheme.primary,
                      onChanged: (v) => setState(() {
                        selectedBranchId = v;
                        targetLabel = 'All branches (entire network)';
                      }),
                    ),
                    const Divider(height: 1),
                    // Individual branches
                    ...branches.map((b) => Column(children: [
                      RadioListTile<String?>(
                        value: b['branch_id'].toString(),
                        groupValue: selectedBranchId,
                        title: Text(b['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 13, color: TPSTheme.textDark)),
                        activeColor: TPSTheme.primary,
                        onChanged: (v) => setState(() {
                          selectedBranchId = v;
                          targetLabel = b['name'] ?? 'branch';
                        }),
                      ),
                      const Divider(height: 1),
                    ])),
                  ]),
                ),

                const SizedBox(height: 20),

                // Title
                const Text('Title',
                  style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TPSTheme.textDark)),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Notification title',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: TPSTheme.accentBorder)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: TPSTheme.accentBorder)),
                  ),
                ),

                const SizedBox(height: 16),

                // Message
                const Text('Message',
                  style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TPSTheme.textDark)),
                const SizedBox(height: 8),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write your message...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: TPSTheme.accentBorder)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: TPSTheme.accentBorder)),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSending ? null : _send,
                    icon: isSending
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                    label: Text(
                      isSending ? 'Sending...' : 'Send to $targetLabel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TPSTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
