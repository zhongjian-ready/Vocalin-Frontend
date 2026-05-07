import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocalin/src/models/group.dart';
import 'package:vocalin/src/models/group_action_result.dart';
import 'package:vocalin/src/models/group_list_item.dart';
import 'package:vocalin/src/models/post.dart';
import 'package:vocalin/src/models/space_inbox_item.dart';
import 'package:vocalin/src/models/user.dart';
import 'package:vocalin/src/models/wish.dart';
import 'package:vocalin/src/services/api_service.dart';
import 'package:vocalin/src/services/data_service.dart';

void main() {
  group('DataService Tests', () {
    late DataService dataService;
    late _FakeApiService apiService;

    setUp(() {
      apiService = _FakeApiService();
      dataService = DataService(apiService: apiService, autoInitialize: false);
    });

    test('Initial data should be empty before fetch', () {
      expect(dataService.currentUser, isNull);
      expect(dataService.posts, isEmpty);
      expect(dataService.currentGroup, isNull);
    });

    test('refreshData treats no-space backend message as empty state',
        () async {
      apiService.groupError = DioException(
        requestOptions: RequestOptions(path: '/groups/current'),
        response: Response(
          requestOptions: RequestOptions(path: '/groups/current'),
          statusCode: 400,
          data: {'message': '用户尚未加入空间'},
        ),
      );

      final completed = _waitForIdle(dataService);

      dataService.syncAuthState(
        User(id: 7, nickname: 'Taylor', groupId: null),
      );

      await completed;

      expect(dataService.currentGroup, isNull);
      expect(dataService.errorMessage, isNull);
      expect(dataService.posts, isEmpty);
      expect(apiService.getGroupCalls, 1);
    });

    test('refreshData resolves current user role from group members', () async {
      apiService.createdGroup = Group(
        id: 5,
        name: 'Warm Home',
        inviteCode: 'ABCD12',
        myRole: 'owner',
        members: [
          User(
            id: 7,
            nickname: 'Taylor',
            groupId: 5,
            role: 'owner',
          ),
          User(
            id: 8,
            nickname: 'Alex',
            groupId: 5,
            role: 'member',
          ),
        ],
      );

      final completed = _waitForIdle(dataService);

      dataService.syncAuthState(
        User(id: 7, nickname: 'Taylor', groupId: 5),
      );

      await completed;

      expect(dataService.currentUser?.role, 'owner');
      expect(dataService.currentUser?.canManageMembers, isTrue);
    });

    test('createGroup stores created group locally', () async {
      final createdGroup = Group(
        id: 3,
        name: 'Warm Home',
        inviteCode: 'ABCD12',
        members: const [],
      );
      apiService.createdGroup = createdGroup;

      await dataService.createGroup('Warm Home');

      expect(dataService.currentGroup?.name, 'Warm Home');
      expect(dataService.currentGroup?.inviteCode, 'ABCD12');
      expect(apiService.lastCreatedGroupName, 'Warm Home');
      expect(dataService.errorMessage, isNull);
    });

    test('switchCurrentGroup delegates to api service', () async {
      await dataService.switchCurrentGroup(12);

      expect(apiService.lastSwitchedGroupId, 12);
      expect(dataService.errorMessage, isNull);
    });

    test('pending join request keeps current group unchanged', () async {
      apiService.createdGroup = Group(
        id: 1,
        name: 'Current Space',
        inviteCode: 'CUR123',
        members: [
          User(id: 7, nickname: 'Taylor', groupId: 1, role: 'member'),
        ],
      );
      apiService.groupListData = const GroupListData(
        currentGroupId: 1,
        groups: [
          GroupListItem(
            id: 1,
            name: 'Current Space',
            inviteCode: 'CUR123',
            memberCount: 1,
            creatorId: 7,
            isCurrent: true,
          ),
        ],
        pendingRequests: [
          GroupListItem(
            id: 9,
            name: 'Pending Space',
            inviteCode: 'WAIT99',
            memberCount: 0,
            creatorId: 0,
            isCurrent: false,
            membershipStatus: 'pending',
            pendingRequestId: 91,
            pendingRequestType: 'join_request',
            targetUserId: 7,
          ),
        ],
      );
      dataService.syncAuthState(
        User(id: 7, nickname: 'Taylor', groupId: 1, role: 'member'),
      );
      await _waitForIdle(dataService);

      apiService.joinGroupResult = const GroupActionResult(
        status: GroupActionStatus.pendingApproval,
        message: '已发起申请',
      );

      final result = await dataService.joinGroup('WAIT99');

      expect(result.isPendingApproval, isTrue);
      expect(dataService.currentGroup?.id, 1);
      expect(
          dataService.joinedGroups
              .singleWhere((item) => item.id == 9)
              .isPendingApproval,
          isTrue);
    });

    test('pending transfer request keeps owner role until accepted', () async {
      apiService.createdGroup = Group(
        id: 5,
        name: 'Warm Home',
        inviteCode: 'ABCD12',
        creatorId: 7,
        myRole: 'owner',
        pendingOwnershipTransfer: true,
        pendingOwnerId: 8,
        members: [
          User(id: 7, nickname: 'Taylor', groupId: 5, role: 'owner'),
          User(id: 8, nickname: 'Alex', groupId: 5, role: 'member'),
        ],
      );
      dataService.syncAuthState(
        User(id: 7, nickname: 'Taylor', groupId: 5, role: 'owner'),
      );
      await _waitForIdle(dataService);

      apiService.transferOwnershipResult = const GroupActionResult(
        status: GroupActionStatus.pendingApproval,
        message: '已发起移交',
      );

      final result = await dataService.transferGroupOwnership(
        groupId: 5,
        targetUserId: 8,
      );

      expect(result.isPendingApproval, isTrue);
      expect(dataService.currentGroup?.myRole, 'owner');
      expect(dataService.currentGroup?.isOwnershipTransferPending, isTrue);
    });

    test('space inbox items include join and transfer approvals', () async {
      apiService.createdGroup = Group(
        id: 5,
        name: 'Warm Home',
        inviteCode: 'ABCD12',
        creatorId: 6,
        myRole: 'admin',
        pendingOwnershipTransfer: true,
        pendingOwnerId: 7,
        members: [
          User(id: 6, nickname: 'Jamie', groupId: 5, role: 'owner'),
          User(id: 7, nickname: 'Taylor', groupId: 5, role: 'admin'),
          User(id: 8, nickname: 'Alex', groupId: 5, role: 'member'),
        ],
      );
      apiService.homeMessages = const [
        SpaceInboxItem(
          id: 31,
          type: SpaceInboxItemType.joinRequest,
          groupId: 5,
          groupName: 'Warm Home',
          status: 'pending',
          requesterUserId: 8,
          requesterNickname: 'Alex',
        ),
        SpaceInboxItem(
          id: 32,
          type: SpaceInboxItemType.ownershipTransfer,
          groupId: 5,
          groupName: 'Warm Home',
          status: 'pending',
          requesterUserId: 6,
          requesterNickname: 'Jamie',
          targetUserId: 7,
          targetNickname: 'Taylor',
        ),
      ];

      dataService.syncAuthState(
        User(id: 7, nickname: 'Taylor', groupId: 5, role: 'admin'),
      );
      await _waitForIdle(dataService);

      final items = dataService.spaceInboxItems;

      expect(items, hasLength(2));
      expect(items.first.type, SpaceInboxItemType.joinRequest);
      expect(items.last.type, SpaceInboxItemType.ownershipTransfer);
    });

    test('leave, transfer, and dissolve group delegate to api service',
        () async {
      await dataService.leaveGroup(4);
      await dataService.removeGroupMember(groupId: 4, targetUserId: 8);
      await dataService.transferGroupOwnership(groupId: 4, targetUserId: 9);
      await dataService.dissolveGroup(4);

      expect(apiService.lastLeftGroupId, 4);
      expect(apiService.lastRemovedGroupId, 4);
      expect(apiService.lastRemovedTargetUserId, 8);
      expect(apiService.lastTransferGroupId, 4);
      expect(apiService.lastTransferTargetUserId, 9);
      expect(apiService.lastDissolvedGroupId, 4);
      expect(dataService.errorMessage, isNull);
    });

    test('review endpoints delegate to api service', () async {
      await dataService.approveJoinRequest(groupId: 5, requestId: 31);
      await dataService.rejectJoinRequest(groupId: 5, requestId: 32);
      await dataService.approveOwnershipTransfer(groupId: 5);
      await dataService.rejectOwnershipTransfer(groupId: 5);

      expect(apiService.lastReviewedJoinGroupId, 5);
      expect(apiService.lastReviewedJoinRequestId, 32);
      expect(apiService.lastReviewedJoinAction, 'reject');
      expect(apiService.lastReviewedOwnerGroupId, 5);
      expect(apiService.lastReviewedOwnerAction, 'reject');
      expect(dataService.errorMessage, isNull);
    });

    test('addWish forwards selected priority to api', () async {
      await dataService.addWish(
        'Plan a weekend hike',
        priority: WishPriority.high,
      );

      expect(apiService.lastWishContent, 'Plan a weekend hike');
      expect(apiService.lastWishPriority, 'high');
      expect(dataService.errorMessage, isNull);
    });

    test('updateWishPriority forwards selected priority to api', () async {
      await dataService.updateWishPriority(42, WishPriority.low);

      expect(apiService.lastUpdatedWishId, 42);
      expect(apiService.lastUpdatedWishPriority, 'low');
      expect(dataService.errorMessage, isNull);
    });
  });
}

Future<void> _waitForIdle(DataService dataService) {
  final completer = Completer<void>();

  dataService.addListener(() {
    if (!dataService.isLoading && !completer.isCompleted) {
      completer.complete();
    }
  });

  return completer.future;
}

class _FakeApiService extends ApiService {
  _FakeApiService()
      : super.test(
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080/api')),
        );

  DioException? groupError;
  Group? createdGroup;
  GroupActionResult joinGroupResult =
      const GroupActionResult(status: GroupActionStatus.completed);
  GroupActionResult transferOwnershipResult =
      const GroupActionResult(status: GroupActionStatus.completed);
  GroupListData groupListData = const GroupListData(
      currentGroupId: null, groups: [], pendingRequests: []);
  List<SpaceInboxItem> homeMessages = const [];
  String? lastCreatedGroupName;
  String? lastInviteCode;
  String? lastWishContent;
  String? lastWishPriority;
  int? lastUpdatedWishId;
  String? lastUpdatedWishPriority;
  int? lastSwitchedGroupId;
  int? lastLeftGroupId;
  int? lastRemovedGroupId;
  int? lastRemovedTargetUserId;
  int? lastTransferGroupId;
  int? lastTransferTargetUserId;
  int? lastDissolvedGroupId;
  int? lastReviewedJoinGroupId;
  int? lastReviewedJoinRequestId;
  String? lastReviewedJoinAction;
  int? lastReviewedOwnerGroupId;
  String? lastReviewedOwnerAction;
  int getGroupCalls = 0;

  @override
  Future<GroupListData> getMyGroups() async => groupListData;

  @override
  Future<List<SpaceInboxItem>> getHomeMessages() async => homeMessages;

  @override
  Future<Group> getGroup() async {
    getGroupCalls += 1;
    if (groupError != null) {
      throw groupError!;
    }

    return createdGroup ??
        joinGroupResult.group ??
        Group(
          id: 1,
          name: 'Default Space',
          inviteCode: 'ZZZZ',
          members: const [],
        );
  }

  @override
  Future<Group> createGroup(String name) async {
    lastCreatedGroupName = name;
    return createdGroup ??
        Group(
          id: 2,
          name: name,
          inviteCode: 'NEW123',
          members: const [],
        );
  }

  @override
  Future<GroupActionResult> joinGroup(String inviteCode) async {
    lastInviteCode = inviteCode;
    if (joinGroupResult.group == null && !joinGroupResult.isPendingApproval) {
      return GroupActionResult(
        status: GroupActionStatus.completed,
        group: Group(
          id: 4,
          name: 'Joined Space',
          inviteCode: inviteCode,
          members: const [],
        ),
      );
    }

    return joinGroupResult;
  }

  @override
  Future<void> switchCurrentGroup(int groupId) async {
    lastSwitchedGroupId = groupId;
  }

  @override
  Future<void> leaveGroup(int groupId) async {
    lastLeftGroupId = groupId;
  }

  @override
  Future<void> removeGroupMember({
    required int groupId,
    required int targetUserId,
  }) async {
    lastRemovedGroupId = groupId;
    lastRemovedTargetUserId = targetUserId;
  }

  @override
  Future<GroupActionResult> transferGroupOwnership({
    required int groupId,
    required int targetUserId,
  }) async {
    lastTransferGroupId = groupId;
    lastTransferTargetUserId = targetUserId;
    return transferOwnershipResult;
  }

  @override
  Future<void> reviewGroupJoinRequest({
    required int groupId,
    required int requestId,
    required String action,
  }) async {
    lastReviewedJoinGroupId = groupId;
    lastReviewedJoinRequestId = requestId;
    lastReviewedJoinAction = action;
  }

  @override
  Future<void> reviewOwnershipTransfer({
    required int groupId,
    required String action,
  }) async {
    lastReviewedOwnerGroupId = groupId;
    lastReviewedOwnerAction = action;
  }

  @override
  Future<void> dissolveGroup(int groupId) async {
    lastDissolvedGroupId = groupId;
  }

  @override
  Future<List<Post>> getPhotos() async => const [];

  @override
  Future<List<Post>> getNotes() async => const [];

  @override
  Future<List<Wish>> getWishlist() async => const [];

  @override
  Future<void> addWish(String content, {String? priority}) async {
    lastWishContent = content;
    lastWishPriority = priority;
  }

  @override
  Future<void> updateWishPriority(int id, String priority) async {
    lastUpdatedWishId = id;
    lastUpdatedWishPriority = priority;
  }
}
