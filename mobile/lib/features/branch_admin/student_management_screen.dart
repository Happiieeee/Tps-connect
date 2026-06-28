import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/models/student_model.dart';
import 'student_profile_screen.dart';

class StudentManagementScreen extends StatefulWidget {
  final String branchId;
  const StudentManagementScreen({super.key, required this.branchId});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  List<StudentModel> students = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final data = await ApiService.get('/students?branch_id=${widget.branchId}');
      setState(() {
        students = (data as List).map((s) => StudentModel.fromJson(s)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; errorMessage = e.toString(); });
    }
  }

  Future<void> _addStudent() async {
    // Load classes first
    List<dynamic> classes = [];
    try {
      classes = await ApiService.get('/classes?branch_id=${widget.branchId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load classes: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;

    final nameController = TextEditingController();
    final dobController = TextEditingController();
    final emergencyController = TextEditingController();
    final medicalController = TextEditingController();
    String? selectedClassId;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name *')),
              const SizedBox(height: 8),
              TextField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth (YYYY-MM-DD)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    dobController.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Class *'),
                items: classes.map<DropdownMenuItem<String>>((c) =>
                  DropdownMenuItem(value: c['class_id'].toString(), child: Text(c['class_name']))
                ).toList(),
                onChanged: (val) => selectedClassId = val,
              ),
              const SizedBox(height: 8),
              TextField(controller: emergencyController, decoration: const InputDecoration(labelText: 'Emergency Contact')),
              const SizedBox(height: 8),
              TextField(controller: medicalController, decoration: const InputDecoration(labelText: 'Medical Notes'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || selectedClassId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Name and Class are required')),
                );
                return;
              }
              try {
                await ApiService.post('/students', {
                  'name': nameController.text.trim(),
                  'dob': dobController.text.trim().isEmpty ? null : dobController.text.trim(),
                  'class_id': selectedClassId,
                  'emergency_contact': emergencyController.text.trim(),
                  'medical_notes': medicalController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadStudents();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStudents),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        icon: const Icon(Icons.child_care),
        label: const Text('Add Student'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : students.isEmpty
                  ? const Center(child: Text('No students yet. Add one!'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: students.length,
                      itemBuilder: (ctx, i) {
                        final s = students[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: s.photoUrl != null ? NetworkImage(s.photoUrl!) : null,
                            child: s.photoUrl == null
                                ? Text(s.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                : null,
                            backgroundColor: Colors.green,
                          ),
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(s.className ?? 'No class assigned'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentProfileScreen(studentId: s.studentId),
                            ),
                          ).then((_) => _loadStudents()),
                        );
                      },
                    ),
    );
  }
}
