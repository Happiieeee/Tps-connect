class PostModel {
  final String postId;
  final String branchId;
  final String? classId;
  final String? className;
  final String postedBy;
  final String authorName;
  final String category;
  final String title;
  final String content;
  final List<String> fileUrls;
  final DateTime createdAt;

  PostModel({
    required this.postId,
    required this.branchId,
    this.classId,
    this.className,
    required this.postedBy,
    required this.authorName,
    required this.category,
    required this.title,
    required this.content,
    required this.fileUrls,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
        postId: json['post_id'] ?? '',
        branchId: json['branch_id'] ?? '',
        classId: json['class_id'],
        className: json['class_name'],
        postedBy: json['posted_by'] ?? '',
        authorName: json['author_name'] ?? 'Unknown',
        category: json['category'] ?? '',
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        fileUrls: json['file_urls'] != null
            ? List<String>.from(json['file_urls'])
            : [],
        createdAt: DateTime.parse(json['created_at']),
      );

  String get categoryEmoji {
    switch (category) {
      case 'homework': return '📚';
      case 'circular': return '📢';
      case 'event': return '🎉';
      case 'photos': return '📷';
      case 'holiday': return '🏖️';
      default: return '📌';
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'homework': return 'Homework';
      case 'circular': return 'Circular';
      case 'event': return 'Event';
      case 'photos': return 'Photos';
      case 'holiday': return 'Holiday';
      default: return 'Post';
    }
  }
}
