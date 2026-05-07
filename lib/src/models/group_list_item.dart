class GroupListItem {
  final int id;
  final String name;
  final String inviteCode;
  final int memberCount;
  final int creatorId;
  final String? role;
  final String? membershipStatus;
  final int? pendingRequestId;
  final String? pendingRequestType;
  final int? targetUserId;
  final bool isCurrent;

  const GroupListItem({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberCount,
    required this.creatorId,
    required this.isCurrent,
    this.role,
    this.membershipStatus,
    this.pendingRequestId,
    this.pendingRequestType,
    this.targetUserId,
  });

  factory GroupListItem.fromJson(Map<String, dynamic> json) {
    return GroupListItem(
      id: (json['id'] ?? json['ID']) as int,
      name: json['name'] as String? ?? 'My Group',
      inviteCode: json['invite_code'] as String? ?? '',
      memberCount: (json['member_count'] ?? 0) as int,
      creatorId: (json['creator_id'] ?? 0) as int,
      role: json['role'] as String?,
      membershipStatus: (json['membership_status'] ??
          json['join_status'] ??
          json['status']) as String?,
      pendingRequestId: json['pending_request_id'] as int?,
      pendingRequestType: json['pending_request_type'] as String?,
      targetUserId: json['target_user_id'] as int?,
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }

  factory GroupListItem.fromPendingRequestJson(Map<String, dynamic> json) {
    return GroupListItem(
      id: (json['group_id'] ?? 0) as int,
      name: json['group_name'] as String? ?? 'Pending Group',
      inviteCode: json['invite_code'] as String? ?? '',
      memberCount: 0,
      creatorId: 0,
      isCurrent: false,
      membershipStatus: json['status'] as String? ?? 'pending',
      pendingRequestId: json['id'] as int?,
      pendingRequestType: json['type'] as String?,
      targetUserId: json['target_user_id'] as int?,
    );
  }

  bool get isPendingApproval {
    final status = membershipStatus?.toLowerCase();
    return status == 'pending' ||
        status == 'pending_approval' ||
        status == 'applying' ||
        status == 'awaiting_approval';
  }
}

class GroupListData {
  final int? currentGroupId;
  final List<GroupListItem> groups;
  final List<GroupListItem> pendingRequests;

  const GroupListData({
    required this.currentGroupId,
    required this.groups,
    required this.pendingRequests,
  });

  factory GroupListData.fromJson(Map<String, dynamic> json) {
    return GroupListData(
      currentGroupId: json['current_group_id'] as int?,
      groups: (json['groups'] as List<dynamic>?)
              ?.map((item) =>
                  GroupListItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      pendingRequests: (json['pending_requests'] as List<dynamic>?)
              ?.map((item) => GroupListItem.fromPendingRequestJson(
                    item as Map<String, dynamic>,
                  ))
              .toList() ??
          const [],
    );
  }
}
