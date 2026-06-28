import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/post_model.dart';
import '../../config/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mark_attendance_screen.dart';
import 'create_post_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  String? branchId;
  String branchName = '';
  String teacherName = 'Teacher';
  List<dynamic> classes = [];
  List<PostModel> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final userData = await getUserRole();
      final bid = userData['branch_id']?.toString() ?? '';
      final name = userData['name'] ?? 'Teacher';
      final bName = userData['branch_name'] ?? '';

      List<dynamic> cls = [];
      List<PostModel> branchPosts = [];

      await Future.wait([
        ApiService.get('/classes?branch_id=$bid').then((d) {
          cls = d as List;
        }).catchError((_) {}),
        ApiService.get('/posts').then((d) {
          branchPosts = (d as List).map((p) => PostModel.fromJson(p)).toList();
        }).catchError((_) {}),
      ]);

      if (mounted) {
        setState(() {
          branchId = bid;
          branchName = bName;
          teacherName = name;
          classes = cls;
          posts = branchPosts;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday-1]}, ${now.day} ${months[now.month-1]} ${now.year}';
  }

  // ── Profile Bottom Sheet ─────────────────────────
  void _showProfileSheet() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? teacherName;
    final email = user?.email ?? 'N/A';
    final photoUrl = user?.photoURL;
    final initials = displayName.isNotEmpty
        ? displayName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'T';

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
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(initials, style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700,
                    color: TPSTheme.primary))
                : null,
          ),
          const SizedBox(height: 14),
          Text(displayName, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: TPSTheme.textDark)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.email_outlined, size: 15, color: TPSTheme.textLight),
            const SizedBox(width: 6),
            Text(email, style: const TextStyle(fontSize: 13, color: TPSTheme.textLight)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: TPSTheme.accentLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TPSTheme.accentBorder)),
            child: Text('Teacher${branchName.isNotEmpty ? ' — $branchName' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: TPSTheme.primary)),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: TPSTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final initials = teacherName.isNotEmpty
        ? teacherName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'T';

    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('TPS', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          if (branchName.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: TPSTheme.primary,
                  borderRadius: BorderRadius.circular(20)),
                child: Text(branchName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: TPSTheme.accent,
                      fontWeight: FontWeight.w600)),
              ),
            ),
          ],
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
                border: Border.all(color: TPSTheme.accent, width: 2),
                image: photoUrl != null
                    ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: photoUrl == null
                  ? Center(child: Text(initials, style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))
                  : null,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Greeting ──
            Text('${_greeting()}, $teacherName 👋',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: TPSTheme.textDark)),
            const SizedBox(height: 4),
            Text(_todayLabel(),
                style: const TextStyle(fontSize: 13, color: TPSTheme.textLight)),
            const SizedBox(height: 20),

            // ── Quick Actions ──
            Row(children: [
              _quickAction('📝', 'Mark\nAttendance', _showClassPicker),
              const SizedBox(width: 10),
              _quickAction('📢', 'Create\nPost', () {
                if (branchId != null) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CreatePostScreen(
                        branchId: branchId!, classes: classes)));
                }
              }),
            ]),
            const SizedBox(height: 20),

            // ── Your Classes ──
            _sectionHeader('Your Classes', '${classes.length} classes'),
            const SizedBox(height: 10),
            if (classes.isEmpty)
              _emptyState('No classes assigned yet', Icons.school_outlined)
            else
              ...classes.map((c) => _classCard(c)),

            const SizedBox(height: 20),

            // ── Recent Posts ──
            _sectionHeader('Recent Posts', posts.isNotEmpty ? '${posts.length} posts' : ''),
            const SizedBox(height: 10),
            if (posts.isEmpty)
              _emptyState('No posts yet', Icons.article_outlined)
            else
              ...posts.take(5).map((p) => _postCard(p)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showClassPicker() {
    if (classes.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2))),
          const Text('Select Class for Attendance',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: TPSTheme.textDark)),
          const SizedBox(height: 12),
          ...classes.map((c) => ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: TPSTheme.accentLight,
                borderRadius: BorderRadius.circular(9)),
              child: Center(child: Text(
                  c['class_name'][0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: TPSTheme.primary))),
            ),
            title: Text(c['class_name'],
              style: const TextStyle(fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
            trailing: const Icon(Icons.chevron_right, color: TPSTheme.textLight),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MarkAttendanceScreen(
                  classId: c['class_id'].toString(),
                  className: c['class_name'])));
            },
          )),
        ]),
      ),
    );
  }

  // ── Widgets ──

  Widget _quickAction(String icon, String label, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: TPSTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TPSTheme.accentBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: TPSTheme.accentLight,
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: TPSTheme.primary, height: 1.3)),
          ),
          const Icon(Icons.chevron_right, color: TPSTheme.textLight, size: 18),
        ]),
      ),
    ),
  );

  Widget _sectionHeader(String title, String trailing) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: TPSTheme.textDark)),
      if (trailing.isNotEmpty)
        Text(trailing, style: const TextStyle(
            fontSize: 12, color: TPSTheme.textLight)),
    ],
  );

  Widget _emptyState(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder)),
    child: Column(children: [
      Icon(icon, size: 32, color: TPSTheme.textHint),
      const SizedBox(height: 8),
      Text(text, style: const TextStyle(fontSize: 13, color: TPSTheme.textLight)),
    ]),
  );

  Widget _classCard(dynamic c) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: TPSTheme.primary,
          borderRadius: BorderRadius.circular(11)),
        child: Center(child: Text(
            c['class_name'][0].toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
      ),
      title: Text(c['class_name'],
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
      subtitle: const Text('Tap to mark attendance',
          style: TextStyle(fontSize: 11, color: TPSTheme.textLight)),
      trailing: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: TPSTheme.accentLight,
          borderRadius: BorderRadius.circular(9)),
        child: const Icon(Icons.how_to_reg_rounded,
            color: TPSTheme.primary, size: 18),
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => MarkAttendanceScreen(
          classId: c['class_id'].toString(),
          className: c['class_name']))),
    ),
  );

  Widget _postCard(PostModel p) {
    final colors = {
      'homework': [const Color(0xFF185FA5), const Color(0xFFE6F1FB)],
      'circular': [const Color(0xFF534AB7), const Color(0xFFEEEDFE)],
      'event':    [const Color(0xFF854F0B), TPSTheme.warningLight],
      'photos':   [const Color(0xFF8B185F), const Color(0xFFFBE6F4)],
      'holiday':  [TPSTheme.primary, TPSTheme.accentLight],
    };
    final c = colors[p.category] ?? [TPSTheme.primary, TPSTheme.accentLight];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TPSTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TPSTheme.accentBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: c[1], borderRadius: BorderRadius.circular(20)),
            child: Text('${p.categoryEmoji} ${p.categoryLabel}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c[0])),
          ),
          const Spacer(),
          Text(_fmtDate(p.createdAt),
              style: const TextStyle(fontSize: 11, color: TPSTheme.textHint)),
        ]),
        const SizedBox(height: 8),
        Text(p.title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
        if (p.content.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(p.content,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: TPSTheme.textMid, height: 1.4)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.person_outline, size: 13, color: TPSTheme.textHint),
          const SizedBox(width: 4),
          Text(p.authorName,
              style: const TextStyle(fontSize: 11, color: TPSTheme.textHint)),
          if (p.fileUrls.isNotEmpty) ...[
            const SizedBox(width: 10),
            const Icon(Icons.attach_file, size: 13, color: TPSTheme.textHint),
            const SizedBox(width: 2),
            Text('${p.fileUrls.length}', style: const TextStyle(fontSize: 11, color: TPSTheme.textHint)),
          ],
        ]),
      ]),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
