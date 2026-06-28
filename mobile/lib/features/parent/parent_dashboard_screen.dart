import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/post_model.dart';
import 'attendance_calendar_screen.dart';
import 'submit_leave_screen.dart';
import 'post_feed_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});
  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _tab = 0;
  List<dynamic> children = [];
  List<PostModel> posts = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    try {
      final childData = await ApiService.get('/parents/children');
      children = childData as List<dynamic>;
      try {
        final postData = await ApiService.get('/posts');
        posts = (postData as List).map((p) => PostModel.fromJson(p)).toList();
      } catch (_) {}
      if (mounted) setState(() => isLoading = false);
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: TPSTheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_tab != 0) {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        backgroundColor: TPSTheme.background,
        appBar: AppBar(
          backgroundColor: TPSTheme.primary,
          automaticallyImplyLeading: false,
          title: Row(children: [
            const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('TPS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          actions: [
            Stack(children: [
              IconButton(icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white), onPressed: () {}),
              Positioned(top: 10, right: 10, child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: TPSTheme.warning, shape: BoxShape.circle),
              )),
            ]),
            Container(
              margin: const EdgeInsets.only(right: 12),
              width: 34, height: 34,
              decoration: const BoxDecoration(
                  color: TPSTheme.accent, shape: BoxShape.circle),
              child: Center(child: Text(
                  children.isNotEmpty ? children[0]['name'][0].toUpperCase() : 'P',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: TPSTheme.textMid))),
            ),
          ],
        ),
        body: _tab == 0 ? _homeTab() : _tab == 1
            ? const PostFeedScreen()
            : _tab == 2 ? _attendanceTab()
            : _tab == 3 ? _leaveTab()
            : _profileTab(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          backgroundColor: TPSTheme.surface,
          indicatorColor: TPSTheme.accentLight,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: TPSTheme.primary), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article, color: TPSTheme.primary), label: 'Posts'),
            NavigationDestination(icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today, color: TPSTheme.primary), label: 'Attendance'),
            NavigationDestination(icon: Icon(Icons.mail_outline),
                selectedIcon: Icon(Icons.mail, color: TPSTheme.primary), label: 'Leaves'),
            NavigationDestination(icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: TPSTheme.primary), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  // ─── HOME TAB ─────────────────────────────────
  Widget _homeTab() => RefreshIndicator(
    onRefresh: _loadAll,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hello, Parent 👋',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: TPSTheme.textDark, fontWeight: FontWeight.w600)),
        Text(_todayLabel(),
            style: const TextStyle(fontSize: 13, color: TPSTheme.textLight)),
        const SizedBox(height: 16),

        // Child cards
        if (children.isNotEmpty)
          ...children.map((child) => _childCard(child)),

        if (children.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TPSTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TPSTheme.accentBorder),
            ),
            child: const Center(child: Text('No children linked to this account',
                style: TextStyle(color: TPSTheme.textLight))),
          ),

        const SizedBox(height: 12),

        // Quick actions
        Row(children: [
          _quickBtn('📅', 'Attendance\nCalendar', () {
            if (children.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AttendanceCalendarScreen(
                      studentId: children[0]['student_id'].toString(),
                      studentName: children[0]['name'])));
            }
          }),
          const SizedBox(width: 8),
          _quickBtn('✉️', 'Apply\nLeave', () {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => SubmitLeaveScreen(children: children)));
          }),
          const SizedBox(width: 8),
          _quickBtn('🔔', 'Notifications', () {}),
        ]),
        const SizedBox(height: 16),

        // Posts section
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Recent posts', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
          TextButton(onPressed: () => setState(() => _tab = 1),
              child: const Text('See all →',
                  style: TextStyle(fontSize: 12, color: TPSTheme.primaryLight))),
        ]),

        if (posts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('No posts yet',
                style: TextStyle(color: TPSTheme.textLight))),
          )
        else
          ...posts.take(3).map((p) => _postCard(p)),
      ],
    ),
  );

  // ─── ATTENDANCE TAB ───────────────────────────
  Widget _attendanceTab() {
    if (children.isEmpty) {
      return const Center(child: Text('No children linked', style: TextStyle(color: TPSTheme.textLight)));
    }
    return AttendanceCalendarScreen(
        studentId: children[0]['student_id'].toString(),
        studentName: children[0]['name']);
  }

  // ─── LEAVE TAB ────────────────────────────────
  Widget _leaveTab() {
    return SubmitLeaveScreen(children: children);
  }

  // ─── PROFILE TAB ──────────────────────────────
  Widget _profileTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 40, backgroundColor: TPSTheme.accentLight,
              child: const Icon(Icons.person, size: 40, color: TPSTheme.primary)),
          const SizedBox(height: 16),
          const Text('Parent Profile', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
          const SizedBox(height: 8),
          if (children.isNotEmpty)
            Text('${children.length} ${children.length == 1 ? "child" : "children"} linked',
                style: const TextStyle(color: TPSTheme.textLight)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await ApiService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout, color: TPSTheme.error),
            label: const Text('Logout', style: TextStyle(color: TPSTheme.error)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: TPSTheme.error)),
          ),
        ]),
      ),
    );
  }

  // ─── CHILD CARD ───────────────────────────────
  Widget _childCard(dynamic child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: TPSTheme.primary,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 23, backgroundColor: TPSTheme.accent,
            child: Text(child['name'][0].toUpperCase(), style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: TPSTheme.textMid))),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(child['name'],
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 2),
          Text('${child['class_name'] ?? 'No Class'} · ${child['branch_name'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: TPSTheme.accent)),
        ]),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: TPSTheme.accent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('✓ Linked',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: TPSTheme.textMid)),
      ),
    ]),
  );

  // ─── QUICK BTN ────────────────────────────────
  Widget _quickBtn(String icon, String label, VoidCallback onTap) => Expanded(
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
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                  color: TPSTheme.primary)),
        ]),
      ),
    ),
  );

  // ─── POST CARD ────────────────────────────────
  Widget _postCard(PostModel p) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _catBadge(p),
        Text(_formatDate(p.createdAt),
            style: const TextStyle(fontSize: 11, color: TPSTheme.textHint)),
      ]),
      const SizedBox(height: 8),
      Text(p.title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
      if (p.content.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(p.content, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: TPSTheme.textMid)),
      ],
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.person_outline, size: 13, color: TPSTheme.textHint),
        const SizedBox(width: 4),
        Text(p.authorName,
            style: const TextStyle(fontSize: 11, color: TPSTheme.textHint)),
      ]),
    ]),
  );

  Widget _catBadge(PostModel p) {
    final colors = {
      'homework': [const Color(0xFF185FA5), const Color(0xFFE6F1FB)],
      'circular': [const Color(0xFF534AB7), const Color(0xFFEEEDFE)],
      'event':    [const Color(0xFF854F0B), TPSTheme.warningLight],
      'photos':   [const Color(0xFF8B185F), const Color(0xFFFBE6F4)],
      'holiday':  [TPSTheme.primary, TPSTheme.accentLight],
    };
    final c = colors[p.category] ?? [TPSTheme.primary, TPSTheme.accentLight];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: c[1], borderRadius: BorderRadius.circular(20)),
      child: Text('${p.categoryEmoji} ${p.categoryLabel}',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: c[0])),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday-1]}, ${now.day} ${months[now.month-1]} ${now.year}';
  }
}
