import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../config/theme.dart';

class AllPendingLeavesScreen extends StatefulWidget {
  const AllPendingLeavesScreen({super.key});
  @override
  State<AllPendingLeavesScreen> createState() =>
      _AllPendingLeavesScreenState();
}

class _AllPendingLeavesScreenState extends State<AllPendingLeavesScreen> {
  List<dynamic> leaves = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await ApiService.get('/leaves?status=pending');
      setState(() { leaves = data; isLoading = false; });
    } catch (_) { setState(() => isLoading = false); }
  }

  Future<void> _review(String leaveId, String status) async {
    try {
      await ApiService.put('/leaves/$leaveId', {'status': status});
      _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Leave $status'),
        backgroundColor: status == 'approved' ? Colors.green : Colors.red));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        title: const Text('Pending Leaves'),
        foregroundColor: Colors.white,
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : leaves.isEmpty
          ? const Center(child: Text('No pending leave requests'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: leaves.length,
                itemBuilder: (ctx, i) {
                  final l = leaves[i];
                  final from = DateTime.parse(l['from_date']);
                  final to   = DateTime.parse(l['to_date']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: TPSTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TPSTheme.accentBorder)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(l['student_name'] ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: TPSTheme.textDark))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAEEDA),
                              borderRadius: BorderRadius.circular(20)),
                            child: const Text('⏳ Pending',
                              style: TextStyle(fontSize: 11,
                                color: Color(0xFF854F0B),
                                fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text('Parent: ${l['parent_name'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 12, color: TPSTheme.textLight)),
                        const SizedBox(height: 6),
                        Text(
                          '${from.day}/${from.month}/${from.year}'
                          ' → ${to.day}/${to.month}/${to.year}',
                          style: const TextStyle(
                            fontSize: 13, color: TPSTheme.textDark)),
                        if ((l['reason'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Reason: ${l['reason']}',
                            style: const TextStyle(
                              fontSize: 12, color: TPSTheme.textLight)),
                        ],
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: OutlinedButton(
                            onPressed: () =>
                              _review(l['leave_id'], 'rejected'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red)),
                            child: const Text('Reject'),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: ElevatedButton(
                            onPressed: () =>
                              _review(l['leave_id'], 'approved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TPSTheme.primary,
                              foregroundColor: Colors.white),
                            child: const Text('Approve'),
                          )),
                        ]),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
