import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../branch_admin/class_management_screen.dart';
import '../branch_admin/student_management_screen.dart';
import '../branch_admin/teacher_management_screen.dart';
import '../branch_admin/leave_requests_screen.dart';
import '../branch_admin/teacher_logs_screen.dart';
import '../teacher/mark_attendance_screen.dart';
import '../teacher/create_post_screen.dart';
import 'broadcast_notification_screen.dart';
import '../../core/utils/time_utils.dart';
class BranchAdminDashboardScreen extends StatefulWidget {
  const BranchAdminDashboardScreen({super.key});
  @override
  State<BranchAdminDashboardScreen> createState() =>
      _BranchAdminDashboardScreenState();
}

class _BranchAdminDashboardScreenState
    extends State<BranchAdminDashboardScreen> {
  bool isLoading = true;
  String branchName = 'Branch';
  String adminName  = 'Admin';
  String? branchId;
  int pendingLeaves = 0;
  List<dynamic> recentLogs = [];
  List<dynamic> classes = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final userData = await getUserRole();
      branchId   = userData['branch_id']?.toString();
      adminName  = userData['name'] ?? 'Admin';
      branchName = userData['branch_name'] ?? adminName;

      if (branchId != null) {
        // Load leaves, logs, classes in parallel
        await Future.wait([
          ApiService.get('/leaves?status=pending').then((d) {
            pendingLeaves = (d as List).length;
          }).catchError((_) {}),
          ApiService.get('/logs?limit=5').then((d) {
            recentLogs = (d as List)
              .where((l) => !l['action'].toString()
                .contains('attendance'))
              .take(5).toList();
          }).catchError((_) {}),
          ApiService.get('/classes?branch_id=$branchId').then((d) {
            classes = d as List;
          }).catchError((_) {}),
        ]);
      }

      setState(() => isLoading = false);
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  void _showProfileSheet() {
    final user = FirebaseAuth.instance.currentUser;
    final name     = adminName;
    final email    = user?.email ?? '';
    final photoUrl = user?.photoURL;
    final initials = name.split(' ')
      .map((w) => w.isNotEmpty ? w[0] : '')
      .take(2).join().toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
          ),
          CircleAvatar(
            radius: 40,
            backgroundColor: TPSTheme.accentLight,
            backgroundImage: photoUrl != null
              ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
              ? Text(initials, style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: TPSTheme.primary))
              : null,
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: TPSTheme.textDark)),
          const SizedBox(height: 4),
          if (email.isNotEmpty)
            Text(email, style: const TextStyle(
              fontSize: 13, color: TPSTheme.textLight)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: TPSTheme.accentLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TPSTheme.accentBorder)),
            child: Text('Branch Admin — $branchName',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TPSTheme.primary)),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await AuthService.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(
                    context, '/login');
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCEBEB),
                foregroundColor: const Color(0xFFA32D2D),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Icon(Icons.eco_rounded,
            color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('TPS',
            style: TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: TPSTheme.primary,
                borderRadius: BorderRadius.circular(20)),
              child: Text(branchName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: TPSTheme.accent,
                  fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        actions: [
          GestureDetector(
            onTap: _showProfileSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: TPSTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: TPSTheme.accent, width: 2)),
              child: Center(
                child: Text(
                  adminName.isNotEmpty
                    ? adminName.split(' ')
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .take(2).join().toUpperCase()
                    : 'BA',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white))),
            ),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: TPSTheme.textDark)),
                const SizedBox(height: 4),
                Text(_todayLabel(),
                  style: const TextStyle(
                    fontSize: 13, color: TPSTheme.textLight)),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                  children: [
                    _actionBtn('📚', 'Classes', () {
                      if (branchId != null) Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                          ClassManagementScreen(branchId: branchId!)));
                    }),
                    _actionBtn('🎒', 'Students', () {
                      if (branchId != null) Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                          StudentManagementScreen(branchId: branchId!)));
                    }),
                    _actionBtn('👨‍🏫', 'Teachers', () {
                      if (branchId != null) Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                          TeacherManagementScreen(branchId: branchId!)));
                    }),
                    _actionBtn('📋', 'Leaves', () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const LeaveRequestsScreen()));
                    }, badge: pendingLeaves > 0 ? '$pendingLeaves' : null),
                    _actionBtn('✅', 'Attendance', _showAttendanceClassPicker),
                    _actionBtn('📊', 'Att. Logs', _showAttendanceLogs),
                    _actionBtn('📢', 'Post', () {
                      if (branchId != null) Navigator.push(context,
                        MaterialPageRoute(builder: (_) => CreatePostScreen(
                          branchId: branchId!, classes: classes)));
                    }),
                    _actionBtn('🔔', 'Notify', () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => BroadcastNotificationScreen(
                          classes: classes)));
                    }),
                  ],
                ),

                const SizedBox(height: 16),

                // Leave requests card
                _leaveCard(),
                const SizedBox(height: 12),

                // Teacher logs card
                _logsCard(),
                const SizedBox(height: 12),

                // Attendance overview
                _attendanceCard(),
              ],
            ),
          ),
    );
  }

  void _showAttendanceClassPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2))),
          const Text('Select Class',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: TPSTheme.textDark)),
          const SizedBox(height: 12),
          ...classes.map((c) => ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: TPSTheme.accentLight,
                borderRadius: BorderRadius.circular(9)),
              child: const Center(
                child: Text('📚'))),
            title: Text(c['class_name'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: TPSTheme.textDark)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MarkAttendanceScreen(
                  classId: c['class_id'].toString(),
                  className: c['class_name'],
                )));
            },
          )),
        ]),
      ),
    );
  }

  void _showAttendanceLogs() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const TeacherLogsScreen(
        attendanceOnly: true)));
  }

  Widget _actionBtn(String icon, String label, VoidCallback onTap,
      {String? badge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: TPSTheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TPSTheme.accentBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: TPSTheme.accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: const TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: TPSTheme.primary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: TPSTheme.error,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _leaveCard() => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => const LeaveRequestsScreen())),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TPSTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TPSTheme.accentBorder)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: pendingLeaves > 0
              ? const Color(0xFFFAEEDA)
              : TPSTheme.accentLight,
            borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: Text(
              pendingLeaves > 0 ? '📋' : '✅',
              style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Leave Requests',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TPSTheme.textDark)),
              const SizedBox(height: 2),
              Text(
                pendingLeaves > 0
                  ? '$pendingLeaves pending approval'
                  : 'No pending requests',
                style: TextStyle(
                  fontSize: 12,
                  color: pendingLeaves > 0
                    ? const Color(0xFF854F0B)
                    : TPSTheme.textLight)),
            ],
          ),
        ),
        if (pendingLeaves > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$pendingLeaves',
              style: const TextStyle(
                color: Color(0xFF854F0B),
                fontWeight: FontWeight.w700,
                fontSize: 13)),
          ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right,
          color: TPSTheme.textLight, size: 20),
      ]),
    ),
  );

  Widget _logsCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Teacher Activity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TPSTheme.textDark)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) =>
                const TeacherLogsScreen())),
            child: const Text('View all →',
              style: TextStyle(
                fontSize: 12, color: TPSTheme.primary))),
        ]),
        const SizedBox(height: 12),
        if (recentLogs.isEmpty)
          const Text('No recent activity',
            style: TextStyle(
              fontSize: 13, color: TPSTheme.textLight))
        else
          ...recentLogs.map((log) {
            final ts = DateTime.parse(log['timestamp']);
            final action = (log['action'] as String)
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.isNotEmpty
                ? w[0].toUpperCase() + w.substring(1) : '')
              .join(' ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: TPSTheme.accentLight,
                    borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: Text(
                      log['action'].toString().contains('post')
                        ? '📝' : '👤',
                      style: const TextStyle(fontSize: 14))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['user_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TPSTheme.textDark)),
                      Text(action,
                        style: const TextStyle(
                          fontSize: 11,
                          color: TPSTheme.textLight)),
                    ],
                  ),
                ),
                Text(
                  TimeUtils.formatTime(log['timestamp']),
                  style: const TextStyle(
                    fontSize: 11, color: TPSTheme.textHint)),
              ]),
            );
          }),
      ],
    ),
  );

  Widget _attendanceCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text("Today's Attendance",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TPSTheme.textDark)),
          const Spacer(),
          GestureDetector(
            onTap: _showAttendanceClassPicker,
            child: const Text('Take →',
              style: TextStyle(
                fontSize: 12, color: TPSTheme.primary))),
        ]),
        const SizedBox(height: 12),
        ...classes.map((c) => _attBar(c['class_name'], 0.0)),
        if (classes.isEmpty)
          const Text('No classes found',
            style: TextStyle(
              fontSize: 13, color: TPSTheme.textLight)),
      ],
    ),
  );

  Widget _attBar(String cls, double pct) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 72,
        child: Text(cls, style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: TPSTheme.primary))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: TPSTheme.accentLight,
            valueColor: AlwaysStoppedAnimation(
              pct < 0.8 ? TPSTheme.warning : TPSTheme.primary)),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 36,
        child: Text('${(pct * 100).toInt()}%',
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TPSTheme.textDark))),
    ]),
  );

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Monday','Tuesday','Wednesday',
      'Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday-1]}, ${now.day} '
      '${months[now.month-1]} ${now.year}';
  }
}
