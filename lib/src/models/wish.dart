class Wish {
  final int id;
  final String content;
  final bool isCompleted;
  final int? groupId;

  Wish({
    required this.id,
    required this.content,
    this.isCompleted = false,
    this.groupId,
  });

  factory Wish.fromJson(Map<String, dynamic> json) {
    return Wish(
      id: (json['id'] ?? json['ID']) as int,
      content: json['content'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      groupId: (json['group_id'] ?? json['GroupId']) as int?,
    );
  }

  Wish copyWith({
    int? id,
    String? content,
    bool? isCompleted,
    int? groupId,
  }) {
    return Wish(
      id: id ?? this.id,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      groupId: groupId ?? this.groupId,
    );
  }
  
  // Helper for UI compatibility
  String get title => content;
}
