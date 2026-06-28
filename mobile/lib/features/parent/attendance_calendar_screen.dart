import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  const AttendanceCalendarScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  Map<String, String> attendanceMap = {}; // date string → status
  Map<String, dynamic>? summary;
  bool isLoading = true;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final report = await ApiService.get(
        '/attendance/report/student/${widget.studentId}?month=$selectedMonth&year=$selectedYear',
      );
      final map = <String, String>{};
      for (final day in report['daily']) {
        final dateKey = day['date'].toString().split('T')[0];
        map[dateKey] = day['status'];
      }
      setState(() {
        attendanceMap = map;
        summary = report['summary'];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      if (selectedMonth == 1) { selectedMonth = 12; selectedYear--; }
      else { selectedMonth--; }
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      if (selectedMonth == 12) { selectedMonth = 1; selectedYear++; }
      else { selectedMonth++; }
    });
    _load();
  }

  Color _colorForStatus(String? status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'on_leave': return Colors.orange;
      default: return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
    final firstWeekday = DateTime(selectedYear, selectedMonth, 1).weekday % 7;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.studentName} — Attendance')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Month selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                      Text(
                        '${_monthName(selectedMonth)} $selectedYear',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Summary row
                  if (summary != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summaryCard('Present', '${summary!['days_present'] ?? 0}', Colors.green),
                            _summaryCard('Absent', '${summary!['days_absent'] ?? 0}', Colors.red),
                            _summaryCard('Leave', '${summary!['days_on_leave'] ?? 0}', Colors.orange),
                            _summaryCard('Attendance', '${summary!['attendance_percentage'] ?? 0}%', Colors.blue),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Day headers (Sun–Sat)
                  Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(d,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),

                  // Calendar grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: daysInMonth + firstWeekday,
                    itemBuilder: (ctx, index) {
                      if (index < firstWeekday) return const SizedBox();

                      final day = index - firstWeekday + 1;
                      final dateStr =
                          '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                      final status = attendanceMap[dateStr];

                      return Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _colorForStatus(status),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: status != null ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend('Present', Colors.green),
                      const SizedBox(width: 12),
                      _legend('Absent', Colors.red),
                      const SizedBox(width: 12),
                      _legend('Leave', Colors.orange),
                      const SizedBox(width: 12),
                      _legend('No data', Colors.grey.shade200),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }
}
