import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'branch_detail_screen.dart';

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
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
              }
            },
            offset: const Offset(0, 40),
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              width: 34, height: 34,
              decoration: const BoxDecoration(
                  color: TPSTheme.primary, shape: BoxShape.circle),
              child: const Center(child: Text('SA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white))),
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
                  const Text('Network Overview 🌿',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600,
                          color: TPSTheme.textDark)),
                  Text(_todayLabel(),
                      style: const TextStyle(fontSize: 13, color: TPSTheme.textLight)),
                  const SizedBox(height: 14),

                  // Network stats
                  Row(children: [
                    _netCard('🏫', '${stats['total_branches'] ?? branches.length}', 'Branches'),
                    const SizedBox(width: 8),
                    _netCard('🎒', '${stats['total_students'] ?? 0}', 'Students'),
                    const SizedBox(width: 8),
                    _netCard('👨🏫', '${stats['total_teachers'] ?? 0}', 'Teachers'),
                    const SizedBox(width: 8),
                    _netCard('📋', '${stats['pending_leaves'] ?? 0}', 'Pending'),
                  ]),
                  const SizedBox(height: 14),

                  // Quick actions
                  const Text('Quick Actions',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: TPSTheme.textDark)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _actionBtn('🏫', 'Add Branch', () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Branch coming soon')));
                    }),
                    const SizedBox(width: 8),
                    _actionBtn('👤', 'Add Branch\nAdmin', () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a branch below to add its admin')));
                    }),
                    const SizedBox(width: 8),
                    _actionBtn('📢', 'Broadcast\nto All', () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast coming soon')));
                    }),
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

  Widget _netCard(String icon, String val, String label) => Expanded(
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
