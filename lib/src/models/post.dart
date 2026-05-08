import 'album.dart';

enum PostType { photo, note }

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value.trim());
}

bool _parseSharedValue(Map<String, dynamic> json) {
  final dynamic sharedValue =
      json['is_shared'] ?? json['isShared'] ?? json['shared'];
  if (sharedValue is bool) {
    return sharedValue;
  }
  if (sharedValue is num) {
    return sharedValue != 0;
  }
  if (sharedValue is String) {
    final normalized = sharedValue.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'shared' ||
        normalized == 'public';
  }

  final dynamic visibilityValue = json['visibility'];
  if (visibilityValue is String) {
    final normalizedVisibility = visibilityValue.trim().toLowerCase();
    return normalizedVisibility == 'shared' || normalizedVisibility == 'public';
  }

  return false;
}

String? _firstNonEmptyString(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
  }

  return null;
}

Map<String, dynamic> _extractPostOwner(Map<String, dynamic> json) {
  for (final key in const ['user', 'owner', 'author', 'creator', 'editor']) {
    final candidate = json[key];
    if (candidate is Map<String, dynamic> && candidate.isNotEmpty) {
      return candidate;
    }
  }

  return const {};
}

String? _parseOwnerNickname(Map<String, dynamic> json) {
  final owner = _extractPostOwner(json);
  return _firstNonEmptyString([
    json['owner_nickname'],
    json['author_nickname'],
    json['creator_nickname'],
    json['updated_by_nickname'],
    json['nickname'],
    owner['nickname'],
    owner['name'],
    owner['username'],
  ]);
}

String? _parseOwnerAvatarUrl(Map<String, dynamic> json) {
  final owner = _extractPostOwner(json);
  return _firstNonEmptyString([
    json['owner_avatar_url'],
    json['author_avatar_url'],
    json['creator_avatar_url'],
    json['updated_by_avatar_url'],
    json['avatar_url'],
    owner['avatar_url'],
    owner['avatarUrl'],
    owner['avatar'],
  ]);
}

class Post {
  final int id;
  final PostType type;
  final String? content;
  final String? imageUrl;
  final String? ownerNickname;
  final String? ownerAvatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? color; // For notes
  final bool isBurned; // For notes
  final bool isShared; // For notes

  Post({
    required this.id,
    required this.type,
    this.content,
    this.imageUrl,
    this.ownerNickname,
    this.ownerAvatarUrl,
    required this.createdAt,
    DateTime? updatedAt,
    this.color,
    this.isBurned = false,
    this.isShared = false,
  }) : updatedAt = updatedAt ?? createdAt;

  factory Post.fromPhotoJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] ?? json['ID']) as int,
      type: PostType.photo,
      imageUrl: _firstNonEmptyString([
        json['cover_url'],
        json['coverUrl'],
        json['cover_image_url'],
        json['coverImageUrl'],
        json['url'],
        json['image_url'],
        json['imageUrl'],
      ]),
      content: _firstNonEmptyString([
        json['title'],
        json['name'],
        json['description'],
        json['caption'],
      ]),
      isShared: _parseSharedValue(json),
      ownerNickname: _parseOwnerNickname(json),
      ownerAvatarUrl: _parseOwnerAvatarUrl(json),
      createdAt: _parseDateTime(
            json['createdAt'] ?? json['CreatedAt'] ?? json['created_at'],
          ) ??
          DateTime.now(),
      updatedAt: _parseDateTime(
            json['updatedAt'] ??
                json['UpdatedAt'] ??
                json['updated_at'] ??
                json['createdAt'] ??
                json['CreatedAt'] ??
                json['created_at'],
          ) ??
          DateTime.now(),
    );
  }

  factory Post.fromAlbumActivity(Album album) {
    return Post(
      id: album.id,
      type: PostType.photo,
      content: album.title,
      imageUrl: album.coverImageUrl,
      ownerNickname: album.ownerNickname,
      ownerAvatarUrl: album.ownerAvatarUrl,
      createdAt: album.createdAt,
      updatedAt: album.updatedAt,
      isShared: album.isShared,
    );
  }

  factory Post.fromNoteJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] ?? json['ID']) as int,
      type: PostType.note,
      content: json['content'] as String?,
      color: json['color'] as String?,
      isBurned: json['is_burned'] as bool? ?? false,
      isShared: _parseSharedValue(json),
      createdAt: _parseDateTime(
            json['createdAt'] ?? json['created_at'] ?? json['CreatedAt'],
          ) ??
          DateTime.now(),
      updatedAt: _parseDateTime(
            json['updatedAt'] ??
                json['updated_at'] ??
                json['UpdatedAt'] ??
                json['createdAt'] ??
                json['created_at'] ??
                json['CreatedAt'],
          ) ??
          DateTime.now(),
    );
  }

  Post copyWith({
    int? id,
    PostType? type,
    String? content,
    String? imageUrl,
    String? ownerNickname,
    String? ownerAvatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? color,
    bool? isBurned,
    bool? isShared,
  }) {
    return Post(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerNickname: ownerNickname ?? this.ownerNickname,
      ownerAvatarUrl: ownerAvatarUrl ?? this.ownerAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      isBurned: isBurned ?? this.isBurned,
      isShared: isShared ?? this.isShared,
    );
  }
}
