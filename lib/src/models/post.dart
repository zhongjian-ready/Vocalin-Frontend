enum PostType { photo, note }

class Post {
  final int id;
  final PostType type;
  final String? content; // Note content or Photo description
  final String? imageUrl; // For photos
  final DateTime createdAt;
  final String? color; // For notes
  final bool isBurned; // For notes

  Post({
    required this.id,
    required this.type,
    this.content,
    this.imageUrl,
    required this.createdAt,
    this.color,
    this.isBurned = false,
  });

  // Adapter to create Post from Backend Photo model
  factory Post.fromPhotoJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] ?? json['ID']) as int,
      type: PostType.photo,
      imageUrl: json['url'] as String?,
      content: json['description'] as String?,
      createdAt: DateTime.tryParse((json['createdAt'] ??
                  json['CreatedAt'] ??
                  json['created_at']) as String? ??
              '') ??
          DateTime.now(),
    );
  }

  // Adapter to create Post from Backend Note model
  factory Post.fromNoteJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] ?? json['ID']) as int,
      type: PostType.note,
      content: json['content'] as String?,
      color: json['color'] as String?,
      isBurned: json['is_burned'] as bool? ?? false,
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? json['CreatedAt'])
                    as String? ??
                '',
          ) ??
          DateTime.now(),
    );
  }
}
