enum SpaceInboxItemType {
  joinRequest,
  ownershipTransfer,
  unknown,
}

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value.trim());
}

class SpaceInboxItem {
  const SpaceInboxItem({
    required this.id,
    required this.type,
    required this.groupId,
    required this.groupName,
    required this.status,
    this.requesterUserId,
    this.requesterNickname,
    this.targetUserId,
    this.targetNickname,
    this.createdAt,
  });

  final int id;
  final SpaceInboxItemType type;
  final int groupId;
  final String groupName;
  final String status;
  final int? requesterUserId;
  final String? requesterNickname;
  final int? targetUserId;
  final String? targetNickname;
  final DateTime? createdAt;

  factory SpaceInboxItem.fromJson(Map<String, dynamic> json) {
    final typeValue = (json['type'] as String? ?? '').toLowerCase();
    return SpaceInboxItem(
      id: (json['id'] ?? 0) as int,
      type: _parseType(typeValue),
      groupId: (json['group_id'] ?? 0) as int,
      groupName: json['group_name'] as String? ?? 'Space',
      status: json['status'] as String? ?? 'pending',
      requesterUserId: json['requester_user_id'] as int?,
      requesterNickname: json['requester_nickname'] as String?,
      targetUserId: json['target_user_id'] as int?,
      targetNickname: json['target_nickname'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  bool get isPending {
    final normalized = status.toLowerCase();
    return normalized == 'pending' ||
        normalized == 'pending_approval' ||
        normalized == 'awaiting_approval' ||
        normalized == 'transferring';
  }

  bool get isJoinRequest => type == SpaceInboxItemType.joinRequest;
  bool get isOwnershipTransfer => type == SpaceInboxItemType.ownershipTransfer;

  String get title {
    switch (type) {
      case SpaceInboxItemType.joinRequest:
        return '${requesterNickname ?? 'A member'} wants to join $groupName';
      case SpaceInboxItemType.ownershipTransfer:
        return 'Ownership transfer request';
      case SpaceInboxItemType.unknown:
        return 'Pending message';
    }
  }

  String get description {
    switch (type) {
      case SpaceInboxItemType.joinRequest:
        return 'Open Space Management to approve the join request.';
      case SpaceInboxItemType.ownershipTransfer:
        return '${requesterNickname ?? 'The current owner'} wants to transfer $groupName to ${targetNickname ?? 'you'}.';
      case SpaceInboxItemType.unknown:
        return 'Open Space Management to handle this message.';
    }
  }

  static SpaceInboxItemType _parseType(String value) {
    if (value.contains('join')) {
      return SpaceInboxItemType.joinRequest;
    }
    if (value.contains('owner') || value.contains('transfer')) {
      return SpaceInboxItemType.ownershipTransfer;
    }
    return SpaceInboxItemType.unknown;
  }
}
