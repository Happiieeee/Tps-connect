import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'branch_detail_screen.dart';
import 'branch_students_screen.dart';
import 'branch_teachers_screen.dart';
import 'superadmin_broadcast_screen.dart';
import 'all_pending_leaves_screen.dart';
import 'create_branch_admin_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});
  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState
    extends State<SuperAdminDashboardScreen> {
  bool isLoading = true;
  Map<String, dynamic> stats = {};
  List<dynamic> branches = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      try {
        final s = await ApiService.get('/superadmin/stats');
        stats = s as Map<String, dynamic>;
      } catch (_) {}
      try {
        final b = await ApiService.get('/superadmin/branches');
        branches = b as List<dynamic>;
      } catch (_) {}
      setState(() => isLoading = false);
    } catch (_) { setState(() => isLoading = false); }
  }

  void _showProfileSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Super Admin';
    final email = user?.email ?? 'N/A';
    final photoUrl = user?.photoURL;
    final initials = displayName.isNotEmpty
        ? displayName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'SA';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: TPSTheme.accentLight,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(initials,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: TPSTheme.primary))
                : null,
          ),
          const SizedBox(height: 14),

          // Name
          Text(displayName,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: TPSTheme.textDark)),
          const SizedBox(height: 4),

          // Email
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.email_outlined, size: 15, color: TPSTheme.textLight),
            const SizedBox(width: 6),
            Text(email,
                style: const TextStyle(
                    fontSize: 13, color: TPSTheme.textLight)),
          ]),
          const SizedBox(height: 10),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: TPSTheme.accentLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TPSTheme.accentBorder),
            ),
            child: const Text('Super Admin',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: TPSTheme.primary)),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCEBEB),
                foregroundColor: const Color(0xFFA32D2D),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Branches sheet ─────────────────────────────────────────
  void _showBranchesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _sheetWrap(
        title: 'All Branches',
        child: branches.isEmpty
          ? const Center(child: Text('No branches'))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: branches.length,
              itemBuilder: (ctx, i) {
                final b = branches[i];
                return ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: TPSTheme.accentLight,
                      borderRadius: BorderRadius.circular(9)),
                    child: const Center(child: Text('🏫')),
                  ),
                  title: Text(b['name'] ?? '', style: const TextStyle(
                    fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
                  subtitle: Text('Code: ${b['code']}  ·  ${b['total_students']} students'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      BranchDetailScreen(
                        branchId: b['branch_id'].toString(),
                        branchName: b['name'] ?? 'Branch',
                      ))).then((_) => _load());
                  },
                );
              },
            ),
      ),
    );
  }

  // ── Students — branch picker then class picker ─────────────
  void _showStudentsBranchPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _sheetWrap(
        title: 'Students — Select Branch',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: branches.length,
          itemBuilder: (ctx, i) {
            final b = branches[i];
            return ListTile(
              leading: const Text('🏫', style: TextStyle(fontSize: 20)),
              title: Text(b['name'] ?? '', style: const TextStyle(
                fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
              subtitle: Text('${b['total_students']} students'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  BranchStudentsScreen(
                    branchId: b['branch_id'].toString(),
                    branchName: b['name'] ?? 'Branch',
                  )));
              },
            );
          },
        ),
      ),
    );
  }

  // ── Teachers — branch picker ───────────────────────────────
  void _showTeachersBranchPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _sheetWrap(
        title: 'Teachers — Select Branch',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: branches.length,
          itemBuilder: (ctx, i) {
            final b = branches[i];
            return ListTile(
              leading: const Text('🏫', style: TextStyle(fontSize: 20)),
              title: Text(b['name'] ?? '', style: const TextStyle(
                fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
              subtitle: Text('${b['total_teachers']} teachers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  BranchTeachersScreen(
                    branchId: b['branch_id'].toString(),
                    branchName: b['name'] ?? 'Branch',
                  )));
              },
            );
          },
        ),
      ),
    );
  }

  // ── Pending leaves across all branches ────────────────────
  void _showPendingLeaves() {
    Navigator.push(context, MaterialPageRoute(builder: (_) =>
      const AllPendingLeavesScreen()));
  }

  // ── Add Admin branch picker ────────────────────────────────
  void _showAddAdminBranchPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _sheetWrap(
        title: 'Select Branch for New Admin',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: branches.length,
          itemBuilder: (ctx, i) {
            final b = branches[i];
            return ListTile(
              leading: const Text('🏫', style: TextStyle(fontSize: 20)),
              title: Text(b['name'] ?? '', style: const TextStyle(
                fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  CreateBranchAdminScreen(
                    branchId: b['branch_id'].toString(),
                    branchName: b['name'] ?? 'Branch',
                  ))).then((_) => _load());
              },
            );
          },
        ),
      ),
    );
  }

  // ── Logs — branch picker → opens BranchDetailScreen on Logs tab ───────────
  void _showLogsBranchPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _sheetWrap(
        title: 'Logs — Select Branch',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: branches.length,
          itemBuilder: (ctx, i) {
            final b = branches[i];
            return ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: TPSTheme.accentLight,
                  borderRadius: BorderRadius.circular(9)),
                child: const Center(child: Text('🏫'))),
              title: Text(b['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: TPSTheme.textDark)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BranchDetailScreen(
                    branchId: b['branch_id'].toString(),
                    branchName: b['name'] ?? 'Branch',
                    initialTab: 3, // Logs tab
                  ),
                )).then((_) => _load());
              },
            );
          },
        ),
      ),
    );
  }

  // ── Shared sheet wrapper ───────────────────────────────────
  Widget _sheetWrap({required String title, required Widget child}) =>
    Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2)),
        ),
        Text(title, style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: TPSTheme.textDark)),
        const SizedBox(height: 12),
        Flexible(child: child),
      ]),
    );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('TPS'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: TPSTheme.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Super Admin',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: TPSTheme.textMid)),
          ),
        ]),
        actions: [
          GestureDetector(
            onTap: () => _showProfileSheet(context),
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: TPSTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: TPSTheme.accent, width: 2),
              ),
              child: const Center(child: Text('SA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
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
                  const Text('Network Overview 🌿',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600,
                          color: TPSTheme.textDark)),
                  Text(_todayLabel(),
                      style: const TextStyle(fontSize: 13, color: TPSTheme.textLight)),
                  const SizedBox(height: 14),

                  // Network stats
                  Row(children: [
                    _netCard('🏫', '${stats['total_branches'] ?? branches.length}', 'Branches', () {
                      _showBranchesSheet();
                    }),
                    const SizedBox(width: 8),
                    _netCard('🎒', '${stats['total_students'] ?? 0}', 'Students', () {
                      _showStudentsBranchPicker();
                    }),
                    const SizedBox(width: 8),
                    _netCard('👨🏫', '${stats['total_teachers'] ?? 0}', 'Teachers', () {
                      _showTeachersBranchPicker();
                    }),
                    const SizedBox(width: 8),
                    _netCard('📋', '${stats['pending_leaves'] ?? 0}', 'Pending', () {
                      _showPendingLeaves();
                    }),
                  ]),
                  const SizedBox(height: 14),

                  // Quick actions
                  const Text('Quick Actions',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: TPSTheme.textDark)),
                  const SizedBox(height: 8),
                   Row(children: [
                    _actionBtn('👤', 'Add Branch\nAdmin', () => _showAddAdminBranchPicker()),
                    const SizedBox(width: 8),
                    _actionBtn('📢', 'Broadcast\nto All', () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SuperAdminBroadcastScreen()))),
                    const SizedBox(width: 8),
                    _actionBtn('📋', 'Logs', () => _showLogsBranchPicker()),
                  ]),
                  const SizedBox(height: 14),

                  // Branches
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('All Branches',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                            color: TPSTheme.textDark)),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TPSTheme.primary,
                        side: const BorderSide(color: TPSTheme.accentBorder),
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                      child: const Text('+ Add', style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  if (branches.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: TPSTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TPSTheme.accentBorder),
                      ),
                      child: const Center(child: Text('No branches found',
                          style: TextStyle(color: TPSTheme.textLight))),
                    )
                  else
                    ...branches.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: TPSTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BranchDetailScreen(
                              branchId: b['branch_id'].toString(),
                              branchName: b['name'] ?? 'Branch',
                            )),
                          ).then((_) => _load()),
                          borderRadius: BorderRadius.circular(14),
                          child: _branchCard(
                            b['name'] ?? 'Branch',
                            b['code'] ?? '',
                            int.tryParse('${b['total_students']}') ?? 0,
                            int.tryParse('${b['total_teachers']}') ?? 0,
                            int.tryParse('${b['pending_leaves']}') ?? 0,
                          ),
                        ),
                      ),
                    )),
                ],
              ),
            ),
    );
  }

  Widget _netCard(String icon, String val, String label, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: TPSTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TPSTheme.accentBorder),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: TPSTheme.textDark)),
          Text(label, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500, color: TPSTheme.textLight)),
        ]),
      ),
    ),
  );

  Widget _actionBtn(String icon, String label, VoidCallback onTap) => Expanded(
    child: Material(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TPSTheme.accentBorder),
          ),
        child: Column(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: TPSTheme.accentLight,
                borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(icon,
                style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                  color: TPSTheme.primary)),
        ]),
      ),
    ),
    ),
  );

  Widget _branchCard(String name, String code, int students, int teachers, int pending) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TPSTheme.accentBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: TPSTheme.accentLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('🏫',
                  style: TextStyle(fontSize: 17))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: TPSTheme.textDark)),
              Text('Code: $code',
                  style: const TextStyle(fontSize: 11, color: TPSTheme.textHint)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: TPSTheme.accentLight,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('● Active',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: TPSTheme.primary)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _metric('$students', 'Students'),
            _metric('$teachers', 'Teachers'),
            _metric('$pending', 'Pending'),
          ]),
        ]),
      );

  Widget _metric(String val, String label) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: TPSTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(val, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: TPSTheme.textDark)),
        Text(label, style: const TextStyle(
            fontSize: 10, color: TPSTheme.textHint)),
      ]),
    ),
  );

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday-1]}, ${now.day} ${months[now.month-1]} ${now.year} · ${branches.length} branches';
  }
}
