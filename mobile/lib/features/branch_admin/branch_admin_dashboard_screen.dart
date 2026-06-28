import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../branch_admin/class_management_screen.dart';
import '../branch_admin/student_management_screen.dart';
import '../branch_admin/teacher_management_screen.dart';
import '../branch_admin/leave_requests_screen.dart';

class BranchAdminDashboardScreen extends StatefulWidget {
  const BranchAdminDashboardScreen({super.key});
  @override
  State<BranchAdminDashboardScreen> createState() =>
      _BranchAdminDashboardScreenState();
}

class _BranchAdminDashboardScreenState
    extends State<BranchAdminDashboardScreen> {
  bool isLoading = true;
  Map<String, dynamic> dashData = {};
  String branchName = 'Branch';
  String adminName = 'Admin';
  String? branchId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userData = await getUserRole();
      branchId = userData['branch_id']?.toString();
      adminName = userData['name'] ?? 'Admin';
      branchName = userData['branch_name'] ?? adminName;
      final today = DateTime.now().toIso8601String().split('T')[0];
      try {
        final overview = await ApiService.get('/attendance/overview/branch?date=$today');
        dashData = {'overview': overview};
      } catch (_) {}
      setState(() => isLoading = false);
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primary,
        title: Row(children: [
          const Text('TPS'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(branchName,
                style: const TextStyle(fontSize: 11, color: TPSTheme.accent)),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
              }
            },
            offset: const Offset(0, 40),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 34, height: 34,
              decoration: const BoxDecoration(
                  color: TPSTheme.accent, shape: BoxShape.circle),
              child: const Center(
                child: Text('BA',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700, color: TPSTheme.textMid)),
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Greeting
                  Text('Good morning, $adminName 👋',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: TPSTheme.textDark, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_todayLabel(),
                      style: const TextStyle(fontSize: 13, color: TPSTheme.textLight)),
                  const SizedBox(height: 16),

                  // Quick actions
                  _quickActions(context),
                  const SizedBox(height: 12),

                  // Attendance overview
                  _attendanceCard(),
                  const SizedBox(height: 12),

                  // Bottom row
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _leaveCard()),
                    const SizedBox(width: 10),
                    Expanded(child: _postsCard()),
                  ]),
                ],
              ),
            ),
    );
  }

  Widget _quickActions(BuildContext context) => Row(children: [
    _actionBtn(context, '📚', 'Manage\nClasses', () {
      if (branchId != null) {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => ClassManagementScreen(branchId: branchId!)));
      }
    }),
    const SizedBox(width: 8),
    _actionBtn(context, '🎒', 'Manage\nStudents', () {
      if (branchId != null) {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => StudentManagementScreen(branchId: branchId!)));
      }
    }),
    const SizedBox(width: 8),
    _actionBtn(context, '👨🏫', 'Manage\nTeachers', () {
      if (branchId != null) {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => TeacherManagementScreen(branchId: branchId!)));
      }
    }),
    const SizedBox(width: 8),
    _actionBtn(context, '📅', 'Leave\nRequests', () {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const LeaveRequestsScreen()));
    }),
  ]);

  Widget _actionBtn(BuildContext ctx, String icon, String label, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: TPSTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TPSTheme.accentBorder),
            ),
            child: Column(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: TPSTheme.accentLight,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w500,
                      color: TPSTheme.primary)),
            ]),
          ),
        ),
      );

  Widget _attendanceCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Today's attendance",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: TPSTheme.textMid)),
        TextButton(onPressed: () {},
            child: const Text('View all →',
                style: TextStyle(fontSize: 12, color: TPSTheme.primaryLight))),
      ]),
      _attBar('Playgroup', 0.95),
      _attBar('Nursery',   0.88),
      _attBar('LKG',       0.72),
      _attBar('UKG',       1.0),
    ]),
  );

  Widget _attBar(String cls, double pct) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 72,
          child: Text(cls, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: TPSTheme.primary))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: TPSTheme.accentLight,
            valueColor: AlwaysStoppedAnimation(
                pct < 0.8 ? TPSTheme.warning : TPSTheme.primary),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 36,
          child: Text('${(pct * 100).toInt()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: TPSTheme.textMid))),
    ]),
  );

  Widget _leaveCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Leave requests',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: TPSTheme.textMid)),
      const SizedBox(height: 10),
      _miniListItem('Pending', 'No pending leaves', true),
    ]),
  );

  Widget _miniListItem(String name, String sub, bool pending) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      CircleAvatar(radius: 14,
          backgroundColor: TPSTheme.accentLight,
          child: Text(name[0],
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: TPSTheme.primary))),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: TPSTheme.textDark)),
        Text(sub, style: const TextStyle(fontSize: 10, color: TPSTheme.textHint)),
      ])),
    ]),
  );

  Widget _postsCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recent posts',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: TPSTheme.textMid)),
      const SizedBox(height: 10),
      _miniPostItem('Welcome msg', 'Circ', const Color(0xFF534AB7), const Color(0xFFEEEDFE)),
    ]),
  );

  Widget _miniPostItem(String title, String tag, Color tagColor, Color tagBg) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: TPSTheme.textDark))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: tagBg, borderRadius: BorderRadius.circular(20)),
            child: Text(tag,
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600, color: tagColor)),
          ),
        ]),
      );

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday-1]}, ${now.day} ${months[now.month-1]} ${now.year}';
  }
}
