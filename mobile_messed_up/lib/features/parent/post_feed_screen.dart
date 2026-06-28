import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../../core/models/post_model.dart';
import '../../config/theme.dart';

class PostFeedScreen extends StatefulWidget {
  const PostFeedScreen({super.key});
  @override
  State<PostFeedScreen> createState() => _PostFeedScreenState();
}

class _PostFeedScreenState extends State<PostFeedScreen> {
  List<PostModel> posts = [];
  bool isLoading = true;
  String? selectedCategory;

  final filters = [
    {'label': 'All',         'value': null},
    {'label': '📚 Homework', 'value': 'homework'},
    {'label': '📢 Circular', 'value': 'circular'},
    {'label': '🎉 Event',    'value': 'event'},
    {'label': '📷 Photos',   'value': 'photos'},
    {'label': '🏖️ Holiday',  'value': 'holiday'},
  ];

  final _catConfig = {
    'homework': {'color': Color(0xFF185FA5), 'bg': Color(0xFFE6F1FB), 'emoji': '📚'},
    'circular': {'color': Color(0xFF534AB7), 'bg': Color(0xFFEEEDFE), 'emoji': '📢'},
    'event':    {'color': Color(0xFF854F0B), 'bg': Color(0xFFFAEEDA), 'emoji': '🎉'},
    'photos':   {'color': Color(0xFF8B185F), 'bg': Color(0xFFFBE6F4), 'emoji': '📷'},
    'holiday':  {'color': Color(0xFF1A5C2A), 'bg': Color(0xFFEAF3DE), 'emoji': '🏖️'},
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final endpoint = selectedCategory != null
        ? '/posts?category=$selectedCategory' : '/posts';
      final data = await ApiService.get(endpoint);
      setState(() {
        posts = (data as List).map((p) => PostModel.fromJson(p)).toList();
        isLoading = false;
      });
    } catch (_) { setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filter bar
      Container(
        height: 48,
        color: Colors.white,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          itemCount: filters.length,
          itemBuilder: (_, i) {
            final f = filters[i];
            final selected = selectedCategory == f['value'];
            return GestureDetector(
              onTap: () {
                setState(() => selectedCategory = f['value'] as String?);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 0),
                decoration: BoxDecoration(
                  color: selected
                    ? TPSTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                      ? TPSTheme.primary : TPSTheme.accentBorder),
                ),
                child: Center(
                  child: Text(f['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected
                        ? Colors.white : TPSTheme.textDark)),
                ),
              ),
            );
          },
        ),
      ),
      const Divider(height: 1),

      // Post list
      Expanded(
        child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📭',
                      style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('No posts yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: TPSTheme.textLight)),
                  ],
                ))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: posts.length,
                  itemBuilder: (_, i) => _postCard(posts[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _postCard(PostModel post) {
    final cfg = _catConfig[post.category] ??
      {'color': TPSTheme.primary, 'bg': TPSTheme.accentLight, 'emoji': '📌'};
    final color = cfg['color'] as Color;
    final bg    = cfg['bg'] as Color;

    return GestureDetector(
      onTap: () => _showDetail(post),
      child: Container(
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
          // Coloured top strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16))),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${cfg['emoji']}  ${post.categoryLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
                  ),
                  const Spacer(),
                  if (post.className != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: TPSTheme.accentLight,
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(post.className!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: TPSTheme.primary,
                          fontWeight: FontWeight.w500)),
                    ),
                ]),

                const SizedBox(height: 10),

                Text(post.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: TPSTheme.textDark)),

                if (post.content.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: TPSTheme.textMid,
                      height: 1.5)),
                ],

                if (post.fileUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.attach_file,
                      size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      '${post.fileUrls.length} attachment'
                      '${post.fileUrls.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500)),
                  ]),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                Row(children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: TPSTheme.accentLight,
                    child: Text(
                      post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: TPSTheme.primary)),
                  ),
                  const SizedBox(width: 6),
                  Text(post.authorName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TPSTheme.textLight,
                      fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(_fmt(post.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: TPSTheme.textHint)),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios,
                    size: 11, color: color),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showDetail(PostModel post) {
    final cfg = _catConfig[post.category] ??
      {'color': TPSTheme.primary, 'bg': TPSTheme.accentLight, 'emoji': '📌'};
    final color = cfg['color'] as Color;
    final bg    = cfg['bg'] as Color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24))),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header with colour
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${cfg['emoji']}  ${post.categoryLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
                ),
                const SizedBox(height: 10),
                Text(post.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TPSTheme.textDark)),
                const SizedBox(height: 8),
                Row(children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: color.withOpacity(0.2),
                    child: Text(
                      post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase() : 'T',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color)),
                  ),
                  const SizedBox(width: 6),
                  Text(post.authorName,
                    style: const TextStyle(
                      fontSize: 12, color: TPSTheme.textMid)),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today_outlined,
                    size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(_fmt(post.createdAt),
                    style: const TextStyle(
                      fontSize: 12, color: TPSTheme.textMid)),
                ]),
              ],
            ),
          ),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.content.isNotEmpty)
                    Text(post.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: TPSTheme.textDark,
                        height: 1.7))
                  else
                    const Text('No additional details.',
                      style: TextStyle(
                        fontSize: 14,
                        color: TPSTheme.textLight,
                        fontStyle: FontStyle.italic)),

                  if (post.fileUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Attachments',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: TPSTheme.textDark)),
                    const SizedBox(height: 8),
                    ...post.fileUrls.map((url) => GestureDetector(
                      onTap: () => launchUrl(Uri.parse(url)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: color.withOpacity(0.2))),
                        child: Row(children: [
                          Icon(Icons.attach_file,
                            size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              url.split('/').last,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: color,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline))),
                          Icon(Icons.download_rounded,
                            size: 16, color: color),
                        ]),
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

  String _fmt(DateTime dt) =>
    '${dt.day}/${dt.month}/${dt.year}';
}
