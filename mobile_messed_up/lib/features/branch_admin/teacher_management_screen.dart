import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/models/user_model.dart';

class TeacherManagementScreen extends StatefulWidget {
  final String branchId;
  const TeacherManagementScreen({super.key, required this.branchId});

  @override
  State<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  List<UserModel> teachers = [];
  List<dynamic> classes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final tData = await ApiService.get('/teachers?branch_id=${widget.branchId}');
      List<dynamic> cData = [];
      try {
        cData = await ApiService.get('/classes?branch_id=${widget.branchId}');
      } catch (_) {}
      setState(() {
        teachers = (tData as List).map((t) => UserModel.fromJson(t)).toList();
        classes = cData;
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; errorMessage = e.toString(); });
    }
  }

  Future<void> _addTeacher() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedClassId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Teacher'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name *')),
                const SizedBox(height: 8),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 8),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password *'), obscureText: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Assign to Class'),
                  value: selectedClassId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No class')),
                    ...classes.map<DropdownMenuItem<String>>((c) =>
                      DropdownMenuItem(value: c['class_id'].toString(), child: Text(c['class_name']))),
                  ],
                  onChanged: (val) => setDialogState(() => selectedClassId = val),
                ),
                const SizedBox(height: 8),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name, email, and password are required')),
                  );
                  return;
                }
                try {
                  await ApiService.post('/teachers', {
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'password': passwordController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'class_id': selectedClassId,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
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
      ),
    );
  }

  Future<void> _deleteTeacher(String teacherId, String name, bool isActive) async {
    final action = isActive ? 'Deactivate' : 'Permanently Delete';
    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Teacher'),
        content: Text('What would you like to do with $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (isActive)
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'deactivate'),
              child: const Text('Deactivate'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == 'deactivate') {
      await ApiService.delete('/teachers/$teacherId');
      _loadData();
    } else if (confirm == 'delete') {
      try {
        await ApiService.delete('/teachers/$teacherId/permanent');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTeacher,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Teacher'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : teachers.isEmpty
                  ? const Center(child: Text('No teachers yet. Add one!'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: teachers.length,
                      itemBuilder: (ctx, i) {
                        final t = teachers[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: t.isActive ? Colors.blue : Colors.grey,
                            child: Text(t.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(t.email),
                          trailing: IconButton(
                            icon: Icon(
                              t.isActive ? Icons.remove_circle_outline : Icons.delete_forever,
                              color: Colors.red,
                            ),
                            tooltip: t.isActive ? 'Manage' : 'Delete',
                            onPressed: () => _deleteTeacher(t.userId, t.name, t.isActive),
                          ),
                        );
                      },
                    ),
    );
  }
}
