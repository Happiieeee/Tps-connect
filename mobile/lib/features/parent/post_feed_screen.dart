import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../../core/models/post_model.dart';

class PostFeedScreen extends StatefulWidget {
  const PostFeedScreen({super.key});

  @override
  State<PostFeedScreen> createState() => _PostFeedScreenState();
}

class _PostFeedScreenState extends State<PostFeedScreen> {
  List<PostModel> posts = [];
  bool isLoading = true;
  String? selectedCategory;

  final List<Map<String, String?>> filters = [
    {'label': 'All', 'value': null},
    {'label': '📚 Homework', 'value': 'homework'},
    {'label': '📢 Circular', 'value': 'circular'},
    {'label': '🎉 Event', 'value': 'event'},
    {'label': '📷 Photos', 'value': 'photos'},
    {'label': '🏖️ Holiday', 'value': 'holiday'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => isLoading = true);
    try {
      final endpoint = selectedCategory != null
          ? '/posts?category=$selectedCategory'
          : '/posts';
      final data = await ApiService.get(endpoint);
      setState(() {
        posts = (data as List).map((p) => PostModel.fromJson(p)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'homework': return Colors.blue;
      case 'circular': return Colors.purple;
      case 'event': return Colors.orange;
      case 'photos': return Colors.pink;
      case 'holiday': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts')),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: filters.length,
              itemBuilder: (ctx, i) {
                final filter = filters[i];
                final selected = selectedCategory == filter['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter['label']!),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => selectedCategory = filter['value']);
                      _loadPosts();
                    },
                  ),
                );
              },
            ),
          ),

          // Post list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                    ? const Center(child: Text('No posts yet'))
                    : RefreshIndicator(
                        onRefresh: _loadPosts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: posts.length,
                          itemBuilder: (ctx, i) => _buildPostCard(posts[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: category badge + class name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _categoryColor(post.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _categoryColor(post.category)),
                  ),
                  child: Text(
                    '${post.categoryEmoji} ${post.categoryLabel}',
                    style: TextStyle(
                      color: _categoryColor(post.category),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (post.className != null)
                  Text(post.className!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),

            const SizedBox(height: 10),

            // Title
            Text(post.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(post.content, style: const TextStyle(color: Colors.black87)),
            ],

            // File attachments
            if (post.fileUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...post.fileUrls.map((url) => InkWell(
                    onTap: () => launchUrl(Uri.parse(url)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              url.split('/').last,
                              style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],

            const SizedBox(height: 10),

            // Footer: author + date
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(post.authorName,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Spacer(),
                Text(_formatDate(post.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
