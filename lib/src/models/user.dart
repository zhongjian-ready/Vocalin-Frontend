class User {
  final int id;
  final String nickname;
  final String? avatarUrl;
  final String? currentStatus;
  final int? groupId;

  User({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.currentStatus,
    this.groupId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['ID']) as int,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatar_url'] as String?,
      currentStatus: json['current_status'] as String?,
      groupId: (json['group_id'] ?? json['GroupId']) as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'current_status': currentStatus,
      'group_id': groupId,
    };
  }
  
  // Helper for UI compatibility
  String get name => nickname;
}
