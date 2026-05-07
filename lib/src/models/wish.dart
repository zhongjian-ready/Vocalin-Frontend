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

class Wish {
  final int id;
  final String content;
  final bool isCompleted;
  final int? groupId;
  final WishPriority? priority;

  Wish({
    required this.id,
    required this.content,
    this.isCompleted = false,
    this.groupId,
    this.priority,
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
    );
  }

  Wish copyWith({
    int? id,
    String? content,
    bool? isCompleted,
    int? groupId,
    WishPriority? priority,
  }) {
    return Wish(
      id: id ?? this.id,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      groupId: groupId ?? this.groupId,
      priority: priority ?? this.priority,
    );
  }

  // Helper for UI compatibility
  String get title => content;
}
