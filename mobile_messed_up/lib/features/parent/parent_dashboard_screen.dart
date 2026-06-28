import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/models/post_model.dart';
import 'attendance_calendar_screen.dart';
import 'submit_leave_screen.dart';
import 'post_feed_screen.dart';
import 'notification_history_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});
  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _tab = 0;
  List<dynamic> children = [];
  List<PostModel> posts = [];
  Map<String, dynamic>? meData;
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
      try {
        final me = await ApiService.get('/auth/me');
        meData = me as Map<String, dynamic>?;
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

    return Scaffold(
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
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationHistoryScreen())),
            ),
            Positioned(top: 10, right: 10, child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: TPSTheme.warning, shape: BoxShape.circle),
            )),
          ]),
          GestureDetector(
            onTap: () => _showProfileSheet(context),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 34, height: 34,
              decoration: const BoxDecoration(
                  color: TPSTheme.accent, shape: BoxShape.circle),
              child: (children.isNotEmpty && children[0]['photo_url'] != null)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.network(children[0]['photo_url'],
                        width: 34, height: 34, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(child: Text(
                            children[0]['name'][0].toUpperCase(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TPSTheme.textMid))))
                  )
                : Center(child: Text(
                    children.isNotEmpty ? children[0]['name'][0].toUpperCase() : 'P',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: TPSTheme.textMid))),
            ),
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
          ...children.map((child) => _detailedChildCard(child)),

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
          _quickBtn('🔔', 'Notifications', () {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const NotificationHistoryScreen()));
          }),
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
    return SubmitLeaveScreen(
      children: children,
      onHome: () => setState(() => _tab = 0),
    );
  }

  // ─── PROFILE TAB ──────────────────────────────
  Widget _profileTab() {
    final user = FirebaseAuth.instance.currentUser;
    final phone = meData?['phone'] ?? user?.phoneNumber ?? '';

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Parent info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TPSTheme.primary,
              borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: TPSTheme.accent,
                child: Text(
                  meData?['name'] != null
                    ? meData!['name'][0].toUpperCase() : 'P',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: TPSTheme.textMid)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meData?['name'] ?? 'Parent',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.phone_outlined,
                          size: 13, color: TPSTheme.accent),
                        const SizedBox(width: 5),
                        Text(phone,
                          style: const TextStyle(
                            fontSize: 13, color: TPSTheme.accent)),
                      ]),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                      child: const Text('Parent Account',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Children section
          const Text('Linked Children',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: TPSTheme.textDark)),
          const SizedBox(height: 10),

          if (children.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TPSTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TPSTheme.accentBorder)),
              child: const Center(
                child: Text('No children linked',
                  style: TextStyle(color: TPSTheme.textLight))),
            )
          else
            ...children.map((child) => _detailedChildCard(child)),

          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await AuthService.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
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
        ],
      ),
    );
  }

  // ─── CHILD CARD ───────────────────────────────
  Widget _detailedChildCard(dynamic child) {
    // Calculate age from DOB if available
    String? age;
    if (child['dob'] != null) {
      try {
        final dob = DateTime.parse(child['dob']);
        final now = DateTime.now();
        int years = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          years--;
        }
        age = '$years years old';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TPSTheme.accentBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Header strip
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TPSTheme.accentLight,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16))),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: TPSTheme.primary,
              backgroundImage: child['photo_url'] != null
                ? NetworkImage(child['photo_url']) : null,
              child: child['photo_url'] == null
                ? Text(
                    (child['name'] as String).isNotEmpty
                      ? child['name'][0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white))
                : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: TPSTheme.textDark)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: TPSTheme.primary,
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        child['class_name'] ?? 'No Class',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.verified,
              color: TPSTheme.primary, size: 20),
          ]),
        ),

        // Details
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (age != null)
              _infoRow(Icons.cake_outlined, 'Age', age),
            _infoRow(Icons.school_outlined, 'Branch',
              child['branch_name'] ?? 'N/A'),
            _infoRow(Icons.class_outlined, 'Class',
              child['class_name'] ?? 'N/A'),
            if (child['emergency_contact'] != null &&
                child['emergency_contact'].toString().isNotEmpty)
              _infoRow(Icons.emergency_outlined,
                'Emergency', child['emergency_contact']),
            if (child['medical_notes'] != null &&
                child['medical_notes'].toString().isNotEmpty)
              _infoRow(Icons.medical_information_outlined,
                'Medical', child['medical_notes']),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: TPSTheme.accentLight,
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon,
            size: 16, color: TPSTheme.primary),
        ),
        const SizedBox(width: 12),
        Text('$label  ',
          style: const TextStyle(
            fontSize: 12,
            color: TPSTheme.textLight,
            fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
            style: const TextStyle(
              fontSize: 13,
              color: TPSTheme.textDark,
              fontWeight: FontWeight.w600))),
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
  Widget _postCard(PostModel p) => GestureDetector(
    onTap: () => _showPostDetail(p),
    child: Container(
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
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, size: 11, color: TPSTheme.textHint),
        ]),
      ]),
    ),
  );

  // ─── POST DETAIL SHEET ─────────────────────────
  void _showPostDetail(PostModel p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          _catBadge(p),
          const SizedBox(height: 12),
          Text(p.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: TPSTheme.textDark)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.person_outline, size: 13, color: TPSTheme.textHint),
            const SizedBox(width: 4),
            Text(p.authorName, style: const TextStyle(fontSize: 12, color: TPSTheme.textHint)),
            const SizedBox(width: 12),
            const Icon(Icons.calendar_today_outlined, size: 12, color: TPSTheme.textHint),
            const SizedBox(width: 4),
            Text(_formatDate(p.createdAt), style: const TextStyle(fontSize: 12, color: TPSTheme.textHint)),
          ]),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.content.isNotEmpty ? p.content : 'No additional details.',
                    style: const TextStyle(fontSize: 14, color: TPSTheme.textDark, height: 1.6),
                  ),
                  if (p.fileUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Attachments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TPSTheme.textHint)),
                    const SizedBox(height: 8),
                    ...p.fileUrls.map((url) => GestureDetector(
                          onTap: () {
                            launchUrl(Uri.parse(url));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, size: 20, color: TPSTheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    url.split('/').last,
                                    style: const TextStyle(
                                        color: TPSTheme.primary,
                                        decoration: TextDecoration.underline),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── PROFILE SHEET ─────────────────────────────
  void _showProfileSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Get phone from either meData (DB) or Firebase user
    final phone = meData?['phone'] ?? user?.phoneNumber ?? 'N/A';
    final initials = children.isNotEmpty ? children[0]['name'][0].toUpperCase() : 'P';
    final displayName = meData?['name'] ?? 'Parent';

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
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),

          // Avatar (showing first child's picture or initials, exactly as requested)
          CircleAvatar(
            radius: 40,
            backgroundColor: TPSTheme.accentLight,
            backgroundImage: (children.isNotEmpty && children[0]['photo_url'] != null)
                ? NetworkImage(children[0]['photo_url'])
                : null,
            child: (children.isEmpty || children[0]['photo_url'] == null)
                ? Text(initials, style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: TPSTheme.primary))
                : null,
          ),
          const SizedBox(height: 14),

          // Name
          Text(displayName, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: TPSTheme.textDark)),
          const SizedBox(height: 4),

          // Phone
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.phone_outlined, size: 15, color: TPSTheme.textLight),
            const SizedBox(width: 6),
            Text(phone, style: const TextStyle(fontSize: 13, color: TPSTheme.textLight)),
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
            child: const Text('Parent', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: TPSTheme.primary)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

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
