class GroupListItem {
  final int id;
  final String name;
  final String inviteCode;
  final int memberCount;
  final int creatorId;
  final String? role;
  final bool isCurrent;

  const GroupListItem({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberCount,
    required this.creatorId,
    required this.isCurrent,
    this.role,
  });

  factory GroupListItem.fromJson(Map<String, dynamic> json) {
    return GroupListItem(
      id: (json['id'] ?? json['ID']) as int,
      name: json['name'] as String? ?? 'My Group',
      inviteCode: json['invite_code'] as String? ?? '',
      memberCount: (json['member_count'] ?? 0) as int,
      creatorId: (json['creator_id'] ?? 0) as int,
      role: json['role'] as String?,
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }
}

class GroupListData {
  final int? currentGroupId;
  final List<GroupListItem> groups;

  const GroupListData({
    required this.currentGroupId,
    required this.groups,
  });

  factory GroupListData.fromJson(Map<String, dynamic> json) {
    return GroupListData(
      currentGroupId: json['current_group_id'] as int?,
      groups: (json['groups'] as List<dynamic>?)
              ?.map((item) =>
                  GroupListItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
