import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class CreateBranchAdminScreen extends StatefulWidget {
  final String branchId;
  final String branchName;
  const CreateBranchAdminScreen({
    super.key, required this.branchId, required this.branchName});
  @override
  State<CreateBranchAdminScreen> createState() =>
      _CreateBranchAdminScreenState();
}

class _CreateBranchAdminScreenState extends State<CreateBranchAdminScreen> {
  final nameController     = TextEditingController();
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController    = TextEditingController();
  bool isCreating = false;
  bool obscurePassword = true;

  Future<void> _create() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Name, email and password are required')));
      return;
    }
    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password must be at least 6 characters')));
      return;
    }
    setState(() => isCreating = true);
    try {
      await ApiService.post(
        '/superadmin/branches/${widget.branchId}/admins', {
          'name':     nameController.text.trim(),
          'email':    emailController.text.trim(),
          'password': passwordController.text,
          'phone':    phoneController.text.trim(),
        });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Admin created for ${widget.branchName}'),
        backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed — email may already be in use'),
        backgroundColor: Colors.red));
    } finally {
      setState(() => isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Admin — ${widget.branchName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(obscurePassword
                  ? Icons.visibility : Icons.visibility_off),
                onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
              )),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCreating ? null : _create,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: isCreating
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Create Branch Admin',
                    style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}
