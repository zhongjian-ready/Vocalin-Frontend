import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocalin/src/models/group.dart';
import 'package:vocalin/src/models/group_list_item.dart';
import 'package:vocalin/src/models/post.dart';
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
  Group? joinedGroup;
  GroupListData groupListData =
      const GroupListData(currentGroupId: null, groups: []);
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
  int getGroupCalls = 0;

  @override
  Future<GroupListData> getMyGroups() async => groupListData;

  @override
  Future<Group> getGroup() async {
    getGroupCalls += 1;
    if (groupError != null) {
      throw groupError!;
    }

    return createdGroup ??
        joinedGroup ??
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
  Future<Group> joinGroup(String inviteCode) async {
    lastInviteCode = inviteCode;
    return joinedGroup ??
        Group(
          id: 4,
          name: 'Joined Space',
          inviteCode: inviteCode,
          members: const [],
        );
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
  Future<void> transferGroupOwnership({
    required int groupId,
    required int targetUserId,
  }) async {
    lastTransferGroupId = groupId;
    lastTransferTargetUserId = targetUserId;
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
