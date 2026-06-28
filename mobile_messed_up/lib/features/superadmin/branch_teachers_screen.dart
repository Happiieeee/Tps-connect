import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../config/theme.dart';

class BranchTeachersScreen extends StatefulWidget {
  final String branchId;
  final String branchName;
  const BranchTeachersScreen({
    super.key, required this.branchId, required this.branchName});
  @override
  State<BranchTeachersScreen> createState() => _BranchTeachersScreenState();
}

class _BranchTeachersScreenState extends State<BranchTeachersScreen> {
  List<dynamic> teachers = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await ApiService.get(
        '/superadmin/branches/${widget.branchId}');
      setState(() {
        teachers = data['teachers'] as List;
        isLoading = false;
      });
    } catch (_) { setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        title: Text('${widget.branchName} — Teachers'),
        foregroundColor: Colors.white,
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : teachers.isEmpty
          ? const Center(child: Text('No teachers in this branch'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: teachers.length,
              itemBuilder: (ctx, i) {
                final t = teachers[i];
                final initials = (t['name'] as String? ?? 'T')
                  .split(' ')
                  .map((w) => w.isNotEmpty ? w[0] : '')
                  .take(2).join().toUpperCase();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: TPSTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TPSTheme.accentBorder),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: TPSTheme.accentLight,
                      child: Text(initials,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: TPSTheme.primary)),
                    ),
                    title: Text(t['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: TPSTheme.textDark)),
                    subtitle: Text(t['email'] ?? t['phone'] ?? ''),
                    trailing: t['is_active'] == true
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3DE),
                            borderRadius: BorderRadius.circular(20)),
                          child: const Text('Active',
                            style: TextStyle(
                              fontSize: 11,
                              color: TPSTheme.primary,
                              fontWeight: FontWeight.w600)),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20)),
                          child: const Text('Inactive',
                            style: TextStyle(
                              fontSize: 11, color: Colors.grey,
                              fontWeight: FontWeight.w600)),
                        ),
                  ),
                );
              },
            ),
    );
  }
}
