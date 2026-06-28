import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/api_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  const AttendanceReportScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  bool isDownloading = false;

  final months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  Future<void> _download() async {
    setState(() => isDownloading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final token = await user.getIdToken();

      final uri = Uri.parse(
        '${ApiService.baseUrl}/reports/attendance'
        '?student_id=${widget.studentId}'
        '&month=$selectedMonth&year=$selectedYear',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) throw Exception('Failed');

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/attendance_${widget.studentName}_'
        '${months[selectedMonth - 1]}_$selectedYear.pdf',
      );
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Download failed'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Report')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.studentName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                  labelText: 'Month', border: OutlineInputBorder()),
              value: selectedMonth,
              items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                      value: i + 1, child: Text(months[i]))),
              onChanged: (v) => setState(() => selectedMonth = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                  labelText: 'Year', border: OutlineInputBorder()),
              value: selectedYear,
              items: [2025, 2026, 2027]
                  .map((y) =>
                      DropdownMenuItem(value: y, child: Text(y.toString())))
                  .toList(),
              onChanged: (v) => setState(() => selectedYear = v!),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isDownloading ? null : _download,
                icon: isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download),
                label: Text(isDownloading
                    ? 'Downloading...'
                    : 'Download PDF Report'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
