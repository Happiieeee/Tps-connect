import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class StudentProfileScreen extends StatefulWidget {
  final String studentId;
  const StudentProfileScreen({super.key, required this.studentId});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Map<String, dynamic>? student;
  List<dynamic> parents = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final s = await ApiService.get('/students/${widget.studentId}');
      final p = await ApiService.get('/parents/student/${widget.studentId}');
      setState(() {
        student = s;
        parents = p;
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; errorMessage = e.toString(); });
    }
  }

  Future<void> _linkParent() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: AlertDialog(
            title: const Text('Link Parent Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Parent Name *')),
                  const SizedBox(height: 8),
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 8),
                  TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password *'), obscureText: true),
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
                    await ApiService.post('/parents', {
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'password': passwordController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'student_id': widget.studentId,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Parent linked!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Profile')),
        body: Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(student!['name'] ?? 'Student Profile'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundImage: student!['photo_url'] != null
                    ? NetworkImage(student!['photo_url'])
                    : null,
                backgroundColor: Colors.green.shade100,
                child: student!['photo_url'] == null
                    ? const Icon(Icons.child_care, size: 52, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // Details card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoTile(Icons.class_, 'Class', student!['class_name'] ?? '-'),
                    _infoTile(Icons.business, 'Branch', student!['branch_name'] ?? '-'),
                    _infoTile(Icons.cake, 'Date of Birth', student!['dob'] ?? '-'),
                    _infoTile(Icons.school, 'Admission Date', student!['admission_date'] ?? '-'),
                    _infoTile(Icons.phone_in_talk, 'Emergency Contact', student!['emergency_contact'] ?? '-'),
                    _infoTile(Icons.medical_services, 'Medical Notes', student!['medical_notes'] ?? 'None'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Linked Parents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (parents.length < 2)
                  TextButton.icon(
                    onPressed: _linkParent,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Parent'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (parents.isEmpty)
              const Text('No parents linked yet.', style: TextStyle(color: Colors.grey))
            else
              ...parents.map((p) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(p['name'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['email'] ?? ''),
                      if (p['phone'] != null) Text(p['phone']),
                    ],
                  ),
                  isThreeLine: p['phone'] != null,
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
