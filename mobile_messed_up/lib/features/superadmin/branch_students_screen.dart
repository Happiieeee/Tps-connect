import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../config/theme.dart';

class BranchStudentsScreen extends StatefulWidget {
  final String branchId;
  final String branchName;
  const BranchStudentsScreen({
    super.key, required this.branchId, required this.branchName});
  @override
  State<BranchStudentsScreen> createState() => _BranchStudentsScreenState();
}

class _BranchStudentsScreenState extends State<BranchStudentsScreen> {
  List<dynamic> classes = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await ApiService.get(
        '/superadmin/branches/${widget.branchId}');
      // Group students by class
      final students = (data['students'] as List);
      final Map<String, List<dynamic>> grouped = {};
      for (final s in students) {
        final cls = s['class_name'] ?? 'No Class';
        grouped.putIfAbsent(cls, () => []).add(s);
      }
      setState(() {
        classes = grouped.entries
          .map((e) => {'class_name': e.key, 'students': e.value})
          .toList();
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
        title: Text('${widget.branchName} — Students'),
        foregroundColor: Colors.white,
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : classes.isEmpty
          ? const Center(child: Text('No students in this branch'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: classes.length,
              itemBuilder: (ctx, i) {
                final cls = classes[i];
                final students = cls['students'] as List;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16, bottom: 8),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: TPSTheme.accentLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: TPSTheme.accentBorder)),
                          child: Text(cls['class_name'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: TPSTheme.primary)),
                        ),
                        const SizedBox(width: 8),
                        Text('${students.length} students',
                          style: const TextStyle(
                            fontSize: 12,
                            color: TPSTheme.textLight)),
                      ]),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: TPSTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TPSTheme.accentBorder),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1, indent: 56),
                        itemBuilder: (ctx, j) {
                          final s = students[j];
                          final initials = (s['name'] as String)
                            .split(' ')
                            .map((w) => w.isNotEmpty ? w[0] : '')
                            .take(2).join().toUpperCase();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: TPSTheme.accentLight,
                              child: Text(initials,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: TPSTheme.primary)),
                            ),
                            title: Text(s['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: TPSTheme.textDark)),
                            trailing: s['is_active'] == true
                              ? const Icon(Icons.circle,
                                  color: Colors.green, size: 10)
                              : const Icon(Icons.circle,
                                  color: Colors.grey, size: 10),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
