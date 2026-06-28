import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'create_branch_admin_screen.dart';

class BranchDetailScreen extends StatefulWidget {
  final String branchId;
  final String branchName;
  const BranchDetailScreen({
    super.key, required this.branchId, required this.branchName});
  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? branchData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.get('/superadmin/branches/${widget.branchId}');
      setState(() { branchData = data; isLoading = false; });
    } catch (_) { setState(() => isLoading = false); }
  }

  Future<void> _toggleUser(String userId) async {
    try {
      await ApiService.put('/superadmin/users/$userId/toggle', {});
      _load();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed'), backgroundColor: Colors.red));
    }
  }

  Widget _userTile(Map<String, dynamic> user) => ListTile(
    leading: CircleAvatar(
      backgroundColor: user['is_active'] == true
        ? Colors.green[50] : Colors.grey[100],
      child: Icon(Icons.person,
        color: user['is_active'] == true ? Colors.green : Colors.grey),
    ),
    title: Text(user['name'] ?? ''),
    subtitle: Text(user['email'] ?? ''),
    trailing: Switch(
      value: user['is_active'] == true,
      onChanged: (_) => _toggleUser(user['user_id']),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.branchName),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Admins'),
          Tab(text: 'Teachers'),
          Tab(text: 'Students'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Branch Admin',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) =>
                CreateBranchAdminScreen(
                  branchId: widget.branchId,
                  branchName: widget.branchName,
                )),
            ).then((_) => _load()),
          ),
        ],
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [

            // Admins tab
            branchData!['admins'].isEmpty
              ? const Center(child: Text('No admins yet — add one with the + button'))
              : ListView(children:
                  (branchData!['admins'] as List)
                    .map<Widget>((a) => _userTile(a)).toList()),

            // Teachers tab
            branchData!['teachers'].isEmpty
              ? const Center(child: Text('No teachers in this branch'))
              : ListView(children:
                  (branchData!['teachers'] as List)
                    .map<Widget>((t) => _userTile(t)).toList()),

            // Students tab
            branchData!['students'].isEmpty
              ? const Center(child: Text('No students in this branch'))
              : ListView.builder(
                  itemCount: (branchData!['students'] as List).length,
                  itemBuilder: (ctx, i) {
                    final s = branchData!['students'][i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.child_care)),
                      title: Text(s['name'] ?? ''),
                      subtitle: Text(s['class_name'] ?? 'No class'),
                    );
                  }),
          ]),
    );
  }
}
