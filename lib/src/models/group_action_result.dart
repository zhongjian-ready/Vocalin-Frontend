import 'group.dart';
import 'group_list_item.dart';

enum GroupActionStatus {
  completed,
  pendingApproval,
}

class GroupActionResult {
  const GroupActionResult({
    required this.status,
    this.group,
    this.groupListItem,
    this.message,
  });

  final GroupActionStatus status;
  final Group? group;
  final GroupListItem? groupListItem;
  final String? message;

  bool get isPendingApproval => status == GroupActionStatus.pendingApproval;

  factory GroupActionResult.fromResponse(dynamic payload) {
    final rootMap = _asMap(payload);
    final dataMap = _extractDataMap(rootMap);

    final directGroup = _parseGroupCandidate(dataMap) ??
        _parseGroupCandidate(_asMap(rootMap['group'])) ??
        _parseGroupCandidate(rootMap);

    final pendingGroup = _parseGroupListItemCandidate(
          _asMap(dataMap['pending_group']),
        ) ??
        _parseGroupListItemCandidate(_asMap(rootMap['pending_group'])) ??
        _parseGroupListItemCandidate(dataMap) ??
        _parseGroupListItemCandidate(rootMap);

    final normalizedState = _normalizeState(
      _firstNonEmptyString([
        dataMap['action_status'],
        dataMap['request_status'],
        dataMap['approval_status'],
        dataMap['status'],
        rootMap['action_status'],
        rootMap['request_status'],
        rootMap['approval_status'],
        rootMap['status'],
      ]),
    );
    final message = _firstNonEmptyString([
      rootMap['message'],
      rootMap['msg'],
      dataMap['message'],
      dataMap['msg'],
    ]);

    final isPending = normalizedState == 'pending' ||
        normalizedState == 'pending_approval' ||
        normalizedState == 'awaiting_approval' ||
        normalizedState == 'applying' ||
        normalizedState == 'transferring' ||
        (message != null && _looksPendingMessage(message));

    return GroupActionResult(
      status: isPending
          ? GroupActionStatus.pendingApproval
          : GroupActionStatus.completed,
      group: isPending ? null : directGroup,
      groupListItem: pendingGroup,
      message: message,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }

    return <String, dynamic>{};
  }

  static Map<String, dynamic> _extractDataMap(Map<String, dynamic> payload) {
    final dataMap = _asMap(payload['data']);
    return dataMap.isNotEmpty ? dataMap : payload;
  }

  static Group? _parseGroupCandidate(Map<String, dynamic> candidate) {
    if (candidate.isEmpty) {
      return null;
    }

    final hasGroupShape = candidate.containsKey('members') ||
        candidate.containsKey('invite_code') ||
        candidate.containsKey('my_role');
    if (!hasGroupShape) {
      return null;
    }

    try {
      return Group.fromJson(candidate);
    } catch (_) {
      return null;
    }
  }

  static GroupListItem? _parseGroupListItemCandidate(
    Map<String, dynamic> candidate,
  ) {
    if (candidate.isEmpty) {
      return null;
    }

    final hasListShape = candidate.containsKey('invite_code') ||
        candidate.containsKey('member_count') ||
        candidate.containsKey('membership_status');
    if (!hasListShape) {
      return null;
    }

    try {
      return GroupListItem.fromJson(candidate);
    } catch (_) {
      return null;
    }
  }

  static String? _firstNonEmptyString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return null;
  }

  static String? _normalizeState(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  static bool _looksPendingMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('pending') ||
        normalized.contains('awaiting approval') ||
        normalized.contains('request sent') ||
        normalized.contains('已发起申请') ||
        normalized.contains('待审批') ||
        normalized.contains('移交中') ||
        normalized.contains('已发起移交');
  }
}
