class User {
  final int id;
  final String nickname;
  final String? avatarUrl;
  final String? currentStatus;
  final int? groupId;
  final String? role;
  final String? membershipStatus;
  final String? ownershipTransferStatus;

  User({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.currentStatus,
    this.groupId,
    this.role,
    this.membershipStatus,
    this.ownershipTransferStatus,
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
      membershipStatus: (json['membership_status'] ??
          json['join_status'] ??
          json['status']) as String?,
      ownershipTransferStatus: (json['ownership_transfer_status'] ??
          json['transfer_status']) as String?,
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
      'membership_status': membershipStatus,
      'ownership_transfer_status': ownershipTransferStatus,
    };
  }

  // Helper for UI compatibility
  String get name => nickname;
  bool get canManageMembers => role == 'owner' || role == 'admin';
  bool get isPendingJoinApproval {
    final status = membershipStatus?.toLowerCase();
    return status == 'pending' ||
        status == 'pending_approval' ||
        status == 'applying' ||
        status == 'awaiting_approval';
  }

  bool get isPendingOwnershipTransfer {
    final status = ownershipTransferStatus?.toLowerCase();
    return status == 'pending' ||
        status == 'pending_approval' ||
        status == 'transferring' ||
        status == 'awaiting_approval';
  }
}
