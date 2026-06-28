import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/attendance_model.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String classId;
  final String className;
  const MarkAttendanceScreen({
    super.key, required this.classId, required this.className});
  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  List<AttendanceRecord> records = [];
  bool isLoading = true;
  bool isSaving  = false;
  final today = DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.get(
          '/attendance/class?class_id=${widget.classId}&date=$today');
      setState(() {
        records = (data as List).map((r) => AttendanceRecord.fromJson(r)).toList();
        isLoading = false;
      });
    } catch (_) { setState(() => isLoading = false); }
  }

  void _markAll() {
    setState(() { for (var r in records) r.status = 'present'; });
  }

  Future<void> _save() async {
    setState(() => isSaving = true);
    try {
      await ApiService.post('/attendance/mark', {
        'class_id': widget.classId, 'date': today,
        'records': records
            .where((r) => r.status != 'not_marked')
            .map((r) => {'student_id': r.studentId, 'status': r.status})
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Attendance saved'), backgroundColor: TPSTheme.primary));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to save'), backgroundColor: TPSTheme.error));
      }
    } finally { if (mounted) setState(() => isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final p = records.where((r) => r.status == 'present').length;
    final a = records.where((r) => r.status == 'absent').length;
    final l = records.where((r) => r.status == 'on_leave').length;
    final u = records.where((r) => r.status == 'not_marked').length;

    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mark Attendance — ${widget.className}'),
          Text(today, style: const TextStyle(fontSize: 11, color: TPSTheme.accent)),
        ]),
        actions: [
          TextButton(onPressed: _markAll,
              child: const Text('All Present',
                  style: TextStyle(color: Colors.white, fontSize: 12))),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Lock warning
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TPSTheme.warningLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFAC775)),
                ),
                child: const Row(children: [
                  Text('⏰', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Text('Attendance locks at 8:00 PM',
                      style: TextStyle(fontSize: 12, color: Color(0xFF854F0B))),
                ]),
              ),

              // Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  _sumCard('$p', 'Present', TPSTheme.primary),
                  const SizedBox(width: 8),
                  _sumCard('$a', 'Absent', TPSTheme.error),
                  const SizedBox(width: 8),
                  _sumCard('$l', 'Leave', TPSTheme.warning),
                  const SizedBox(width: 8),
                  _sumCard('$u', 'Unmarked', TPSTheme.textHint),
                ]),
              ),

              // Bulk bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: TPSTheme.accentLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TPSTheme.accentBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mark everyone present',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: TPSTheme.textMid)),
                    ElevatedButton(
                      onPressed: _markAll,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 14)),
                      child: const Text('All Present ✓', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

              // Student list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                  itemCount: records.length,
                  itemBuilder: (ctx, i) => _studentTile(records[i]),
                ),
              ),
            ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: isSaving ? null : _save,
            child: isSaving
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Attendance'),
          ),
        ),
      ),
    );
  }

  Widget _sumCard(String val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: TPSTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TPSTheme.accentBorder),
      ),
      child: Column(children: [
        Text(val, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w500, color: TPSTheme.textLight)),
      ]),
    ),
  );

  Widget _studentTile(AttendanceRecord r) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: TPSTheme.accentBorder),
    ),
    child: Row(children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: TPSTheme.accentLight,
        backgroundImage: r.photoUrl != null ? NetworkImage(r.photoUrl!) : null,
        child: r.photoUrl == null
            ? Text(r.studentName.isNotEmpty ? r.studentName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: TPSTheme.primary, fontWeight: FontWeight.w600))
            : null,
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.studentName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: TPSTheme.textDark)),
        Text(widget.className,
            style: const TextStyle(fontSize: 11, color: TPSTheme.textHint)),
      ])),
      _palBtn(r, 'P', 'present', TPSTheme.primary),
      const SizedBox(width: 5),
      _palBtn(r, 'A', 'absent', TPSTheme.error),
      const SizedBox(width: 5),
      _palBtn(r, 'L', 'on_leave', TPSTheme.warning),
    ]),
  );

  Widget _palBtn(AttendanceRecord r, String label, String status, Color color) {
    final active = r.status == status;
    return GestureDetector(
      onTap: () => setState(() => r.status = status),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: active ? color : TPSTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : TPSTheme.accentBorder),
        ),
        child: Center(child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? Colors.white : TPSTheme.primary))),
      ),
    );
  }
}
