import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/models/leave_model.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});
  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<LeaveModel> pending = [];
  List<LeaveModel> reviewed = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final all = await ApiService.get('/leaves');
      final leaves =
          (all as List).map((l) => LeaveModel.fromJson(l)).toList();
      setState(() {
        pending = leaves.where((l) => l.status == 'pending').toList();
        reviewed = leaves.where((l) => l.status != 'pending').toList();
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _review(String leaveId, String status) async {
    try {
      await ApiService.put('/leaves/$leaveId', {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Leave $status'),
            backgroundColor:
                status == 'approved' ? Colors.green : Colors.red));
      }
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildCard(LeaveModel l, {bool showActions = false}) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(l.studentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: l.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: l.statusColor),
                  ),
                  child: Text(l.statusLabel,
                      style:
                          TextStyle(color: l.statusColor, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                '${l.fromDate.day}/${l.fromDate.month}/${l.fromDate.year}'
                ' → ${l.toDate.day}/${l.toDate.month}/${l.toDate.year}',
                style: const TextStyle(color: Colors.grey),
              ),
              if (l.parentName != null) ...[
                const SizedBox(height: 4),
                Text('Parent: ${l.parentName}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
              if (l.reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Reason: ${l.reason}'),
              ],
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _review(l.leaveId, 'rejected'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _review(l.leaveId, 'approved'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text('Approve',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Leave Requests'),
          bottom: TabBar(controller: _tabs, tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Reviewed (${reviewed.length})'),
          ]),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tabs, children: [
                pending.isEmpty
                    ? const Center(child: Text('No pending requests'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                            padding: const EdgeInsets.all(12),
                            children: pending
                                .map((l) =>
                                    _buildCard(l, showActions: true))
                                .toList())),
                reviewed.isEmpty
                    ? const Center(child: Text('No reviewed requests'))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: reviewed
                            .map((l) => _buildCard(l))
                            .toList()),
              ]),
      );
}
