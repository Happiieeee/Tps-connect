import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';
import 'create_branch_admin_screen.dart';

class BranchDetailScreen extends StatefulWidget {
  final String branchId;
  final String branchName;
  final int initialTab;
  const BranchDetailScreen({
    super.key,
    required this.branchId,
    required this.branchName,
    this.initialTab = 0,
  });
  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? branchData;
  bool isLoading = true;
  String? selectedClassId;
  String? selectedClassName;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.get(
          '/superadmin/branches/${widget.branchId}');
      setState(() { branchData = data; isLoading = false; });
    } catch (_) { setState(() => isLoading = false); }
  }

  List<dynamic> get classes =>
      (branchData?['classes'] as List?) ?? [];

  List<dynamic> get teachers =>
      (branchData?['teachers'] as List?) ?? [];

  List<dynamic> get students {
    final all = (branchData?['students'] as List?) ?? [];
    if (selectedClassId == null) return all;
    return all.where((s) => s['class_id'] == selectedClassId).toList();
  }

  List<dynamic> get attendance =>
      (branchData?['attendance_today'] as List?) ?? [];

  List<dynamic> get logs =>
      (branchData?['logs'] as List?) ?? [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.branchName),
          const Text('Branch Overview',
              style: TextStyle(fontSize: 11, color: TPSTheme.accent)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: Colors.white),
            tooltip: 'Add Branch Admin',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => CreateBranchAdminScreen(
                  branchId: widget.branchId,
                  branchName: widget.branchName,
                ))).then((_) => _load()),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: TPSTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Classes'),
            Tab(text: 'Teachers'),
            Tab(text: 'Students'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [
              _classesTab(),
              _teachersTab(),
              _studentsTab(),
              _logsTab(),
            ]),
    );
  }

  // ── CLASSES TAB ────────────────────────────────────────────────────────────
  Widget _classesTab() {
    if (classes.isEmpty) {
      return _emptyState('No classes in this branch', '📚');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (ctx, i) {
        final c = classes[i];
        final classStudents = (branchData?['students'] as List? ?? [])
            .where((s) => s['class_id'] == c['class_id']).length;
        return _card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: TPSTheme.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('📚', style: TextStyle(fontSize: 18))),
            ),
            title: Text(c['class_name'] ?? '',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: TPSTheme.textDark)),
            subtitle: Text('$classStudents students',
                style: const TextStyle(
                    fontSize: 12, color: TPSTheme.textLight)),
            trailing: const Icon(Icons.chevron_right,
                color: TPSTheme.textHint),
            onTap: () {
              setState(() {
                selectedClassId = c['class_id'];
                selectedClassName = c['class_name'];
              });
              _tabs.animateTo(2); // Jump to Students tab
            },
          ),
        );
      },
    );
  }

  // ── TEACHERS TAB ───────────────────────────────────────────────────────────
  Widget _teachersTab() {
    if (teachers.isEmpty) {
      return _emptyState('No teachers in this branch', '👨‍🏫');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teachers.length,
      itemBuilder: (ctx, i) {
        final t = teachers[i];
        final isActive = t['is_active'] == true;
        return _card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: isActive
                  ? TPSTheme.accentLight : Colors.grey[100],
              child: Text(
                (t['name'] as String? ?? 'T')[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isActive ? TPSTheme.primary : Colors.grey,
                ),
              ),
            ),
            title: Text(t['name'] ?? '',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: TPSTheme.textDark)),
            subtitle: Text(t['email'] ?? '',
                style: const TextStyle(
                    fontSize: 11, color: TPSTheme.textLight)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? TPSTheme.accentLight : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: isActive
                        ? TPSTheme.primary : Colors.grey[600],
                  )),
            ),
          ),
        );
      },
    );
  }

  // ── STUDENTS TAB ───────────────────────────────────────────────────────────
  Widget _studentsTab() {
    return Column(children: [
      // Class filter bar
      if (classes.isNotEmpty) ...[
        Container(
          color: TPSTheme.surface,
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedClassName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Text('Showing: $selectedClassName',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: TPSTheme.primary)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        selectedClassId = null;
                        selectedClassName = null;
                      }),
                      child: const Text('Clear filter',
                          style: TextStyle(
                              fontSize: 11, color: TPSTheme.error,
                              decoration: TextDecoration.underline)),
                    ),
                  ]),
                ),
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: classes.length,
                  itemBuilder: (ctx, i) {
                    final c = classes[i];
                    final selected =
                        selectedClassId == c['class_id'];
                    return GestureDetector(
                      onTap: () => setState(() {
                        selectedClassId = selected
                            ? null : c['class_id'];
                        selectedClassName = selected
                            ? null : c['class_name'];
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? TPSTheme.primary : TPSTheme.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? TPSTheme.primary
                                  : TPSTheme.accentBorder),
                        ),
                        child: Text(c['class_name'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white : TPSTheme.primary,
                            )),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: TPSTheme.accentBorder),
      ],

      // Student list
      Expanded(
        child: students.isEmpty
            ? _emptyState(
                selectedClassId != null
                    ? 'No students in $selectedClassName'
                    : 'No students in this branch',
                '🎒')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: students.length,
                itemBuilder: (ctx, i) {
                  final s = students[i];
                  return _card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: TPSTheme.accentLight,
                        child: Text(
                          (s['name'] as String? ?? 'S')[0]
                              .toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TPSTheme.primary,
                          ),
                        ),
                      ),
                      title: Text(s['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: TPSTheme.textDark)),
                      subtitle: Text(
                          s['class_name'] ?? 'No class',
                          style: const TextStyle(
                              fontSize: 11,
                              color: TPSTheme.textLight)),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  // ── LOGS TAB ───────────────────────────────────────────────
  Widget _logsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(children: [
        Container(
          color: TPSTheme.surface,
          child: const TabBar(
            labelColor: TPSTheme.primary,
            unselectedLabelColor: TPSTheme.textHint,
            indicatorColor: TPSTheme.primary,
            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            isScrollable: true,
            tabs: [
              Tab(text: 'All Logs'),
              Tab(text: 'Attendance'),
              Tab(text: 'Teacher'),
              Tab(text: 'Admin'),
            ],
          ),
        ),
        const Divider(height: 1, color: TPSTheme.accentBorder),
        Expanded(
          child: TabBarView(children: [
            _logListView(logs),
            _logListView(logs.where((l) => l['action'] == 'mark_attendance').toList()),
            _logListView(logs.where((l) =>
              l['role'] == 'teacher' && l['action'] != 'mark_attendance').toList()),
            _logListView(logs.where((l) =>
              (l['role'] == 'branchadmin' || l['role'] == 'superadmin') &&
              l['action'] != 'mark_attendance').toList()),
          ]),
        ),
      ]),
    );
  }

  Widget _logListView(List<dynamic> items) {
    if (items.isEmpty) {
      return _emptyState('No logs found', '📋');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _logTile(items[i]),
    );
  }

  Widget _logTile(Map<String, dynamic> log) {
    final action   = log['action'] as String? ?? '';
    final userName = log['user_name'] as String? ?? 'Unknown';
    final role     = log['role'] as String? ?? '';
    final ts       = log['timestamp'];
    final meta     = log['meta'] is Map
        ? log['meta'] as Map<String, dynamic>
        : <String, dynamic>{};
    final className = log['class_name'] as String?;

    final isAttendance = action == 'mark_attendance';

    // Human-readable action label
    final actionLabel = _actionLabel(action, meta, className);

    // Role colour
    Color roleColor;
    switch (role) {
      case 'superadmin':  roleColor = const Color(0xFF534AB7); break;
      case 'branchadmin': roleColor = TPSTheme.warning; break;
      case 'teacher':     roleColor = TPSTheme.primary; break;
      default:            roleColor = TPSTheme.textHint;
    }

    return _ExpandableLogTile(
      icon: _actionIcon(action),
      iconBg: isAttendance ? TPSTheme.accentLight : const Color(0xFFE6F1FB),
      iconColor: isAttendance ? TPSTheme.primary : const Color(0xFF185FA5),
      title: actionLabel,
      subtitle: '$userName · ${_formatTime(ts)}',
      roleLabel: _roleLabel(role),
      roleColor: roleColor,
      expandedContent: _buildExpandedContent(log, meta, className, userName, ts),
    );
  }

  String _actionLabel(String action, Map<String, dynamic> meta, String? className) {
    switch (action) {
      case 'mark_attendance':
        final count = meta['count'] ?? 0;
        final cls   = className ?? 'Unknown class';
        return 'Marked attendance · $cls ($count students)';
      case 'create_post':
        final title    = meta['title'] ?? '';
        final category = meta['category'] ?? '';
        return 'Posted $category: $title';
      case 'add_student':
        return 'Added student: ${meta['name'] ?? ''}';
      case 'add_teacher':
        return 'Added teacher: ${meta['name'] ?? ''}';
      case 'approve_leave':
        return 'Approved leave for ${meta['student_name'] ?? 'student'}';
      case 'reject_leave':
        return 'Rejected leave for ${meta['student_name'] ?? 'student'}';
      case 'update_student':
        return 'Updated student: ${meta['name'] ?? ''}';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'mark_attendance': return Icons.check_circle_outline;
      case 'create_post':     return Icons.article_outlined;
      case 'add_student':     return Icons.child_care;
      case 'add_teacher':     return Icons.person_add_outlined;
      case 'approve_leave':   return Icons.event_available_outlined;
      case 'reject_leave':    return Icons.event_busy_outlined;
      default:                return Icons.history;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'superadmin':  return 'Super Admin';
      case 'branchadmin': return 'Branch Admin';
      case 'teacher':     return 'Teacher';
      default:            return role;
    }
  }

  Widget _buildExpandedContent(
    Map<String, dynamic> log,
    Map<String, dynamic> meta,
    String? className,
    String userName,
    dynamic ts,
  ) {
    final action = log['action'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TPSTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TPSTheme.accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always show who + when
          _detailRow(Icons.person_outline, 'By', userName),
          _detailRow(Icons.access_time, 'Time', _formatTimeFull(ts)),

          if (action == 'mark_attendance') ...[
            _detailRow(Icons.class_outlined, 'Class',
                className ?? meta['class_id'] ?? '—'),
            _detailRow(Icons.calendar_today_outlined, 'Date',
                meta['date'] ?? '—'),
            _detailRow(Icons.groups_outlined, 'Students marked',
                '${meta['count'] ?? 0}'),
            // Show per-student breakdown if available
            if (meta['students'] != null) ...[
              const SizedBox(height: 8),
              const Text('Students:',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: TPSTheme.textLight)),
              const SizedBox(height: 4),
              ...(meta['students'] as List).map((s) {
                final status = s['status'] as String? ?? '';
                Color sc;
                switch (status) {
                  case 'present': sc = TPSTheme.primary; break;
                  case 'absent':  sc = TPSTheme.error; break;
                  default:        sc = TPSTheme.warning;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                          color: sc, shape: BoxShape.circle),
                    ),
                    Expanded(child: Text(s['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: TPSTheme.textDark))),
                    Text(status,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: sc)),
                  ]),
                );
              }),
            ],
          ],

          if (action == 'create_post') ...[
            _detailRow(Icons.label_outline, 'Category',
                meta['category'] ?? '—'),
            _detailRow(Icons.title, 'Title', meta['title'] ?? '—'),
          ],

          if (action == 'add_student' || action == 'update_student') ...[
            _detailRow(Icons.child_care, 'Student', meta['name'] ?? '—'),
            if (meta['class_name'] != null)
              _detailRow(Icons.class_outlined, 'Class',
                  meta['class_name']),
          ],

          if (action == 'add_teacher') ...[
            _detailRow(Icons.person_outline, 'Teacher',
                meta['name'] ?? '—'),
            if (meta['email'] != null)
              _detailRow(Icons.email_outlined, 'Email', meta['email']),
          ],

          if (action == 'approve_leave' || action == 'reject_leave') ...[
            _detailRow(Icons.child_care, 'Student',
                meta['student_name'] ?? '—'),
            if (meta['from_date'] != null)
              _detailRow(Icons.date_range_outlined, 'Dates',
                  '${meta['from_date']} → ${meta['to_date'] ?? ''}'),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 14, color: TPSTheme.textLight),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: TPSTheme.textLight)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, color: TPSTheme.textDark)),
          ),
        ]),
      );

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final hour   = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) { return ts.toString(); }
  }

  String _formatTimeFull(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final hour   = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month-1]} ${dt.year} · $hour:$minute $period';
    } catch (_) { return ts.toString(); }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _emptyState(String message, String emoji) =>
      Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  fontSize: 14, color: TPSTheme.textLight)),
        ],
      ));

  Widget _card({required Widget child, EdgeInsets? margin}) =>
      Container(
        margin: margin,
        decoration: BoxDecoration(
          color: TPSTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TPSTheme.accentBorder),
        ),
        child: child,
      );

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString());
      return '${dt.day}/${dt.month}/${dt.year} '
          '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ts.toString(); }
  }
}

class _ExpandableLogTile extends StatefulWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String roleLabel;
  final Color roleColor;
  final Widget expandedContent;

  const _ExpandableLogTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.roleLabel,
    required this.roleColor,
    required this.expandedContent,
  });

  @override
  State<_ExpandableLogTile> createState() => _ExpandableLogTileState();
}

class _ExpandableLogTileState extends State<_ExpandableLogTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: TPSTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _expanded ? TPSTheme.primary : TPSTheme.accentBorder,
            width: _expanded ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Icon
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: widget.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon,
                      size: 18, color: widget.iconColor),
                ),
                const SizedBox(width: 10),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: TPSTheme.textDark)),
                      const SizedBox(height: 2),
                      Text(widget.subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: TPSTheme.textLight)),
                    ],
                  ),
                ),

                // Role badge + chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(widget.roleLabel,
                          style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w600,
                              color: widget.roleColor)),
                    ),
                    const SizedBox(height: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down,
                          size: 16, color: TPSTheme.textHint),
                    ),
                  ],
                ),
              ]),

              // Expanded content
              SizeTransition(
                sizeFactor: _expand,
                child: widget.expandedContent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
