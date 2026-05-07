class User {
  final int id;
  final String nickname;
  final String? avatarUrl;
  final String? currentStatus;
  final int? groupId;
  final String? role;

  User({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.currentStatus,
    this.groupId,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['ID']) as int,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatar_url'] as String?,
      currentStatus: json['current_status'] as String?,
      groupId: (json['group_id'] ?? json['current_group_id'] ?? json['GroupId'])
          as int?,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'current_status': currentStatus,
      'group_id': groupId,
      'role': role,
    };
  }

  // Helper for UI compatibility
  String get name => nickname;
  bool get canManageMembers => role == 'owner' || role == 'admin';
}
