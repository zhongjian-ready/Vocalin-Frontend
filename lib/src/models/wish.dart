enum WishPriority {
  low,
  medium,
  high;

  static WishPriority? fromJsonValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      switch (value) {
        case 1:
          return low;
        case 2:
          return medium;
        case 3:
          return high;
      }
    }

    final normalized = value.toString().trim().toLowerCase();
    switch (normalized) {
      case '1':
      case 'low':
        return low;
      case '2':
      case 'medium':
        return medium;
      case '3':
      case 'high':
        return high;
      default:
        return null;
    }
  }

  String get apiValue {
    switch (this) {
      case WishPriority.low:
        return 'low';
      case WishPriority.medium:
        return 'medium';
      case WishPriority.high:
        return 'high';
    }
  }

  String get label {
    switch (this) {
      case WishPriority.low:
        return 'Low';
      case WishPriority.medium:
        return 'Medium';
      case WishPriority.high:
        return 'High';
    }
  }
}

bool _parseWishSharedValue(Map<String, dynamic> json) {
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

class Wish {
  final int id;
  final String content;
  final bool isCompleted;
  final int? groupId;
  final WishPriority? priority;
  final bool isShared;

  Wish({
    required this.id,
    required this.content,
    this.isCompleted = false,
    this.groupId,
    this.priority,
    this.isShared = false,
  });

  factory Wish.fromJson(Map<String, dynamic> json) {
    return Wish(
      id: (json['id'] ?? json['ID']) as int,
      content: json['content'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      groupId: (json['group_id'] ?? json['GroupId']) as int?,
      priority: WishPriority.fromJsonValue(
        json['priority'] ?? json['Priority'],
      ),
      isShared: _parseWishSharedValue(json),
    );
  }

  Wish copyWith({
    int? id,
    String? content,
    bool? isCompleted,
    int? groupId,
    WishPriority? priority,
    bool? isShared,
  }) {
    return Wish(
      id: id ?? this.id,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      groupId: groupId ?? this.groupId,
      priority: priority ?? this.priority,
      isShared: isShared ?? this.isShared,
    );
  }

  // Helper for UI compatibility
  String get title => content;
}
