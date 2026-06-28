import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class AttendanceOverviewScreen extends StatefulWidget {
  final String branchId;
  const AttendanceOverviewScreen({super.key, required this.branchId});

  @override
  State<AttendanceOverviewScreen> createState() => _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<AttendanceOverviewScreen> {
  List<dynamic> overview = [];
  bool isLoading = true;
  String? errorMessage;
  final String today = DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final data = await ApiService.get(
        '/attendance/overview/branch?date=$today&target_branch_id=${widget.branchId}',
      );
      setState(() {
        overview = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; errorMessage = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = overview.fold<int>(
        0, (sum, row) => sum + int.parse(row['total_students'].toString()));
    final totalPresent = overview.fold<int>(
        0, (sum, row) => sum + int.parse(row['present'].toString()));
    final overallPct = totalStudents > 0
        ? (totalPresent / totalStudents * 100).toStringAsFixed(0)
        : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Overview'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : overview.isEmpty
                  ? const Center(child: Text('No data for today'))
                  : Column(
                      children: [
                        // Date + overall banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          color: Colors.blue[700],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(today,
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                              Text('Overall: $overallPct% ($totalPresent/$totalStudents)',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: overview.length,
                            itemBuilder: (ctx, i) {
                              final row = overview[i];
                              final total = int.parse(row['total_students'].toString());
                              final present = int.parse(row['present'].toString());
                              final absent = int.parse(row['absent'].toString());
                              final onLeave = int.parse(row['on_leave'].toString());
                              final notMarked = int.parse(row['not_marked'].toString());
                              final pct = total > 0
                                  ? (present / total * 100).toStringAsFixed(0)
                                  : '0';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(row['class_name'],
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                          Text('$pct%',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: int.parse(pct) >= 75
                                                      ? Colors.green
                                                      : Colors.red)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: total > 0 ? present / total : 0,
                                          backgroundColor: Colors.red.shade100,
                                          color: Colors.green,
                                          minHeight: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _statBadge('✅ Present', present, Colors.green),
                                          _statBadge('❌ Absent', absent, Colors.red),
                                          _statBadge('🏖 Leave', onLeave, Colors.orange),
                                          _statBadge('Total', total, Colors.blue),
                                        ],
                                      ),
                                      if (notMarked > 0) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '⚠️ $notMarked students not yet marked',
                                          style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _statBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
