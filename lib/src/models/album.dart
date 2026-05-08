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

Map<String, dynamic> _extractOwner(Map<String, dynamic> json) {
  for (final key in const ['user', 'owner', 'author', 'creator', 'editor']) {
    final candidate = json[key];
    if (candidate is Map<String, dynamic> && candidate.isNotEmpty) {
      return candidate;
    }
  }

  return const {};
}

String? _parseOwnerNickname(Map<String, dynamic> json) {
  final owner = _extractOwner(json);
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
  final owner = _extractOwner(json);
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

int? _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }

  return null;
}

enum AlbumPhotoSource { library, camera }

AlbumPhotoSource _parseAlbumPhotoSource(dynamic value) {
  if (value is String && value.trim().toLowerCase() == 'camera') {
    return AlbumPhotoSource.camera;
  }

  return AlbumPhotoSource.library;
}

class AlbumPhotoDraft {
  const AlbumPhotoDraft({
    required this.url,
    this.description,
    this.source = AlbumPhotoSource.library,
  });

  final String url;
  final String? description;
  final AlbumPhotoSource source;

  Map<String, dynamic> toJson() {
    final normalizedDescription = description?.trim();

    return {
      'url': url.trim(),
      if (normalizedDescription != null && normalizedDescription.isNotEmpty)
        'description': normalizedDescription,
      'source': source.name,
    };
  }
}

class AlbumPhoto {
  const AlbumPhoto({
    required this.id,
    required this.imageUrl,
    this.description,
    this.source = AlbumPhotoSource.library,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String imageUrl;
  final String? description;
  final AlbumPhotoSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AlbumPhoto.fromJson(Map<String, dynamic> json) {
    final createdAt = _parseDateTime(
            json['createdAt'] ?? json['CreatedAt'] ?? json['created_at']) ??
        DateTime.now();
    final updatedAt = _parseDateTime(
          json['updatedAt'] ??
              json['UpdatedAt'] ??
              json['updated_at'] ??
              json['createdAt'] ??
              json['CreatedAt'] ??
              json['created_at'],
        ) ??
        createdAt;

    return AlbumPhoto(
      id: _parseInt(json['id'] ?? json['ID']) ?? 0,
      imageUrl: _firstNonEmptyString([
            json['url'],
            json['image_url'],
            json['imageUrl'],
            json['photo_url'],
            json['photoUrl'],
          ]) ??
          '',
      description: _firstNonEmptyString([
        json['description'],
        json['caption'],
        json['content'],
        json['title'],
      ]),
      source: _parseAlbumPhotoSource(json['source']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class Album {
  const Album({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
    this.ownerNickname,
    this.ownerAvatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isShared = false,
    this.photos = const [],
    this.photoCount,
  });

  final int id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String? ownerNickname;
  final String? ownerAvatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isShared;
  final List<AlbumPhoto> photos;
  final int? photoCount;

  int get totalPhotos => photoCount ?? photos.length;

  factory Album.fromJson(Map<String, dynamic> json) {
    final createdAt = _parseDateTime(
            json['createdAt'] ?? json['CreatedAt'] ?? json['created_at']) ??
        DateTime.now();
    final updatedAt = _parseDateTime(
          json['updatedAt'] ??
              json['UpdatedAt'] ??
              json['updated_at'] ??
              json['createdAt'] ??
              json['CreatedAt'] ??
              json['created_at'],
        ) ??
        createdAt;

    final rawPhotos =
        json['photos'] ?? json['photo_list'] ?? json['items'] ?? json['media'];
    final photos = rawPhotos is List
        ? rawPhotos
            .whereType<Map>()
            .map((item) => AlbumPhoto.fromJson(Map<String, dynamic>.from(item)))
            .where((photo) => photo.imageUrl.trim().isNotEmpty)
            .toList()
        : <AlbumPhoto>[];

    final fallbackCoverUrl = _firstNonEmptyString([
      json['cover_url'],
      json['coverUrl'],
      json['cover_image_url'],
      json['coverImageUrl'],
      json['thumbnail_url'],
      json['thumbnailUrl'],
      json['url'],
      json['image_url'],
      json['imageUrl'],
      if (photos.isNotEmpty) photos.first.imageUrl,
    ]);

    final normalizedPhotos = photos.isNotEmpty || fallbackCoverUrl == null
        ? photos
        : [
            AlbumPhoto(
              id: _parseInt(
                    json['cover_id'] ??
                        json['photo_id'] ??
                        json['id'] ??
                        json['ID'],
                  ) ??
                  0,
              imageUrl: fallbackCoverUrl,
              description: _firstNonEmptyString([
                json['cover_description'],
                json['description'],
                json['caption'],
              ]),
              source: _parseAlbumPhotoSource(json['source']),
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          ];

    return Album(
      id: _parseInt(json['id'] ?? json['ID']) ?? 0,
      title: _firstNonEmptyString([
            json['title'],
            json['name'],
            json['album_name'],
            json['albumName'],
            json['description'],
          ]) ??
          'Untitled Album',
      description: _firstNonEmptyString([
        json['description'],
        json['summary'],
        json['intro'],
      ]),
      coverImageUrl: fallbackCoverUrl,
      ownerNickname: _parseOwnerNickname(json),
      ownerAvatarUrl: _parseOwnerAvatarUrl(json),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isShared: _parseSharedValue(json),
      photos: normalizedPhotos,
      photoCount: _parseInt(json['photo_count'] ?? json['photoCount']) ??
          normalizedPhotos.length,
    );
  }
}
