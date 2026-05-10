import 'dart:convert';

import 'album.dart';

enum PostType { photo, note }

const _richNoteContentMarker = 'vocalin_note_rich_text_v1';

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

Map<String, dynamic>? _tryParseRichNoteContent(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  try {
    final normalized = value.trim();
    if (!normalized.startsWith('{')) {
      return null;
    }

    final dynamic decoded = jsonDecode(normalized);
    if (decoded is! Map) {
      return null;
    }

    final typed = decoded.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
    if (typed['format'] != _richNoteContentMarker) {
      return null;
    }

    return typed;
  } catch (_) {
    return null;
  }
}

String _stripRichTextMarkers(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'!\[(.*?)\]\((.*?)\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\[(.*?)\]\((.*?)\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\*\*(.*?)\*\*'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'_(.*?)_'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '')
      .replaceAll(RegExp(r'^#\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*([-*+]|\d+\.)\s+', multiLine: true), '')
      .replaceAll(RegExp(r'(```|`|~~)'), '')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

String? _parseNoteTitle(Map<String, dynamic> json) {
  final richContent = _tryParseRichNoteContent(json['content'] as String?);
  final richTitle = richContent?['title'];
  if (richTitle is String && richTitle.trim().isNotEmpty) {
    return richTitle.trim();
  }

  return _firstNonEmptyString([
    json['title'],
    json['name'],
    json['subject'],
  ]);
}

String? _parseNoteContent(Map<String, dynamic> json) {
  final rawContent = json['content'] as String?;
  final richContent = _tryParseRichNoteContent(rawContent);
  if (richContent != null) {
    final summary = richContent['summary'];
    if (summary is String && summary.trim().isNotEmpty) {
      return summary.trim();
    }

    final body = richContent['body'];
    final plainText = body is String ? _stripRichTextMarkers(body) : '';
    return plainText.isEmpty ? null : plainText;
  }

  final normalized = rawContent?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _parseRichNoteBody(Map<String, dynamic> json) {
  final richContent = _tryParseRichNoteContent(json['content'] as String?);
  final body = richContent?['body'];
  if (body is! String || body.trim().isEmpty) {
    return null;
  }

  return body;
}

int? _parseRichNoteGroupId(Map<String, dynamic> json) {
  final richContent = _tryParseRichNoteContent(json['content'] as String?);
  final groupId = richContent?['groupId'];
  if (groupId is int) {
    return groupId;
  }
  if (groupId is num) {
    return groupId.toInt();
  }

  return null;
}

String encodeRichNoteContent({
  required String title,
  required String body,
  String? summary,
  int? groupId,
}) {
  return jsonEncode({
    'format': _richNoteContentMarker,
    'title': title.trim(),
    'body': body,
    if (summary != null && summary.trim().isNotEmpty) 'summary': summary.trim(),
    if (groupId != null) 'groupId': groupId,
  });
}

class Post {
  final int id;
  final PostType type;
  final String? title;
  final String? content;
  final String? formattedContent;
  final String? imageUrl;
  final String? ownerNickname;
  final String? ownerAvatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? color; // For notes
  final bool isBurned; // For notes
  final bool isShared; // For notes
  final int? groupId;
  final int? folderId;
  final String? folderName;
  final String? folderType;

  Post({
    required this.id,
    required this.type,
    this.title,
    this.content,
    this.formattedContent,
    this.imageUrl,
    this.ownerNickname,
    this.ownerAvatarUrl,
    required this.createdAt,
    DateTime? updatedAt,
    this.color,
    this.isBurned = false,
    this.isShared = false,
    this.groupId,
    this.folderId,
    this.folderName,
    this.folderType,
  }) : updatedAt = updatedAt ?? createdAt;

  factory Post.fromPhotoJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] ?? json['ID']) as int,
      type: PostType.photo,
      title: _firstNonEmptyString([
        json['title'],
        json['name'],
      ]),
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
      title: album.title,
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
      title: _parseNoteTitle(json),
      content: _parseNoteContent(json),
      formattedContent: _parseRichNoteBody(json),
      ownerNickname: _parseOwnerNickname(json),
      ownerAvatarUrl: _parseOwnerAvatarUrl(json),
      color: json['color'] as String?,
      isBurned: json['is_burned'] as bool? ?? false,
      isShared: _parseSharedValue(json),
      groupId:
          (json['group_id'] ?? json['groupId'] ?? json['GroupId']) as int? ??
              _parseRichNoteGroupId(json),
      folderId:
          (json['folder_id'] ?? json['folderId'] ?? json['FolderId']) as int?,
      folderName: _firstNonEmptyString([
        json['folder_name'],
        json['folderName'],
      ]),
      folderType: _firstNonEmptyString([
        json['folder_type'],
        json['folderType'],
      ]),
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
    String? title,
    String? content,
    String? formattedContent,
    String? imageUrl,
    String? ownerNickname,
    String? ownerAvatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? color,
    bool? isBurned,
    bool? isShared,
    int? groupId,
    int? folderId,
    String? folderName,
    String? folderType,
  }) {
    return Post(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      formattedContent: formattedContent ?? this.formattedContent,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerNickname: ownerNickname ?? this.ownerNickname,
      ownerAvatarUrl: ownerAvatarUrl ?? this.ownerAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      isBurned: isBurned ?? this.isBurned,
      isShared: isShared ?? this.isShared,
      groupId: groupId ?? this.groupId,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      folderType: folderType ?? this.folderType,
    );
  }
}
