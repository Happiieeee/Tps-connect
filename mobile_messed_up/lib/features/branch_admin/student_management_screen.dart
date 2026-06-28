import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/models/student_model.dart';
import '../../config/theme.dart';
import 'student_profile_screen.dart';

class StudentManagementScreen extends StatefulWidget {
  final String branchId;
  const StudentManagementScreen({super.key, required this.branchId});
  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  List<dynamic> classes = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.get(
        '/classes?branch_id=${widget.branchId}');
      setState(() { classes = data; isLoading = false; });
    } catch (_) { setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        foregroundColor: Colors.white,
        title: const Text('Manage Students'),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : classes.isEmpty
          ? const Center(child: Text('No classes found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (ctx, i) {
                final c = classes[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) =>
                      ClassStudentsScreen(
                        classId: c['class_id'].toString(),
                        className: c['class_name'],
                        branchId: widget.branchId,
                      )),
                  ).then((_) => _load()),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: TPSTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TPSTheme.accentBorder),
                    ),
                    child: Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: TPSTheme.accentLight,
                          borderRadius: BorderRadius.circular(12)),
                        child: const Center(
                          child: Text('🎒',
                            style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['class_name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: TPSTheme.textDark)),
                            const SizedBox(height: 3),
                            Text('Tap to view students',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TPSTheme.textLight)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                        color: TPSTheme.textLight),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

// ── Class Students Screen ─────────────────────────────────────────────────────
class ClassStudentsScreen extends StatefulWidget {
  final String classId;
  final String className;
  final String branchId;
  const ClassStudentsScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.branchId,
  });
  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  List<StudentModel> students = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.get(
        '/students?branch_id=${widget.branchId}&class_id=${widget.classId}');
      setState(() {
        students = (data as List)
          .map((s) => StudentModel.fromJson(s)).toList();
        isLoading = false;
      });
    } catch (_) { setState(() => isLoading = false); }
  }

  Future<void> _addStudent() async {
    List<dynamic> classes = [];
    try {
      classes = await ApiService.get(
        '/classes?branch_id=${widget.branchId}');
    } catch (_) { return; }

    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final dobCtrl  = TextEditingController();
    final emerCtrl = TextEditingController();
    final medCtrl  = TextEditingController();
    String? selectedClassId = widget.classId;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Student'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
              controller: dobCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today)),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime(2020),
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (d != null) dobCtrl.text =
                  '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Class *',
                border: OutlineInputBorder()),
              value: selectedClassId,
              items: classes.map<DropdownMenuItem<String>>((c) =>
                DropdownMenuItem(
                  value: c['class_id'].toString(),
                  child: Text(c['class_name']))).toList(),
              onChanged: (v) => selectedClassId = v,
            ),
            const SizedBox(height: 10),
            TextField(controller: emerCtrl,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact',
                border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: medCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Medical Notes',
                border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  selectedClassId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Name and class required')));
                return;
              }
              try {
                await ApiService.post('/students', {
                  'name': nameCtrl.text.trim(),
                  'dob': dobCtrl.text.isEmpty ? null : dobCtrl.text,
                  'class_id': selectedClassId,
                  'emergency_contact': emerCtrl.text.trim(),
                  'medical_notes': medCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error: $e'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Add Student')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        foregroundColor: Colors.white,
        title: Text(widget.className),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        backgroundColor: TPSTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : students.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎒',
                    style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('No students in ${widget.className}',
                    style: const TextStyle(
                      fontSize: 16, color: TPSTheme.textLight)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _addStudent,
                    child: const Text('Add first student')),
                ],
              ))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: students.length,
              itemBuilder: (ctx, i) {
                final s = students[i];
                final initials = s.name.split(' ')
                  .map((w) => w.isNotEmpty ? w[0] : '')
                  .take(2).join().toUpperCase();
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) =>
                      StudentProfileScreen(studentId: s.studentId)),
                  ).then((_) => _load()),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: TPSTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TPSTheme.accentBorder),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: TPSTheme.accentLight,
                        radius: 22,
                        child: Text(initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TPSTheme.primary,
                            fontSize: 14)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: TPSTheme.textDark)),
                            const SizedBox(height: 3),
                            Text(s.className ?? widget.className,
                              style: const TextStyle(
                                fontSize: 12,
                                color: TPSTheme.textLight)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                        color: TPSTheme.textLight),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
