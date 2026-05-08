import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocalin/src/models/album.dart';
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

    test('updateProfile stores updated nickname avatar and status locally',
        () async {
      dataService.syncAuthState(
        User(
          id: 7,
          nickname: 'Taylor',
          avatarUrl: 'https://old.example/avatar.png',
          currentStatus: 'Old status',
          groupId: 5,
          role: 'member',
        ),
      );
      apiService.createdGroup = Group(
        id: 5,
        name: 'Warm Home',
        inviteCode: 'ABCD12',
        members: [
          User(
            id: 7,
            nickname: 'Taylor',
            avatarUrl: 'https://old.example/avatar.png',
            currentStatus: 'Old status',
            groupId: 5,
            role: 'member',
          ),
          User(id: 8, nickname: 'Alex', groupId: 5, role: 'member'),
        ],
      );
      await _waitForIdle(dataService);

      await dataService.updateProfile(
        nickname: 'Jamie',
        avatarUrl: 'https://new.example/avatar.png',
        status: 'Running late but cute',
      );

      expect(apiService.lastUpdatedProfileNickname, 'Jamie');
      expect(apiService.lastUpdatedProfileAvatarUrl,
          'https://new.example/avatar.png');
      expect(apiService.lastUpdatedProfileStatus, 'Running late but cute');
      expect(dataService.currentUser?.nickname, 'Jamie');
      expect(
          dataService.currentUser?.avatarUrl, 'https://new.example/avatar.png');
      expect(dataService.currentUser?.currentStatus, 'Running late but cute');
      expect(dataService.currentGroup?.members.first.nickname, 'Jamie');
      expect(dataService.currentGroup?.members.first.avatarUrl,
          'https://new.example/avatar.png');
      expect(dataService.currentGroup?.members.first.currentStatus,
          'Running late but cute');
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
        isShared: true,
      );

      expect(apiService.lastWishContent, 'Plan a weekend hike');
      expect(apiService.lastWishPriority, 'high');
      expect(apiService.lastWishIsShared, isTrue);
      expect(dataService.errorMessage, isNull);
    });

    test('addPost forwards note shared state to api', () async {
      await dataService.addPost(
        Post(
          id: 1,
          type: PostType.note,
          content: 'Leave the key in the planter',
          createdAt: DateTime(2026),
          isShared: true,
        ),
      );

      expect(apiService.lastCreatedNoteContent, 'Leave the key in the planter');
      expect(apiService.lastCreatedNoteIsShared, isTrue);
      expect(dataService.errorMessage, isNull);
    });

    test('createAlbum forwards photos and shared state to api', () async {
      await dataService.createAlbum(
        title: 'Sunset Walk',
        description: 'Weekend memories',
        photos: const [
          AlbumPhotoDraft(
            url: 'https://example.com/photo.jpg',
            description: 'Weekend memories',
            source: AlbumPhotoSource.camera,
          ),
        ],
        isShared: true,
      );

      expect(apiService.lastCreatedAlbumTitle, 'Sunset Walk');
      expect(apiService.lastCreatedAlbumDescription, 'Weekend memories');
      expect(apiService.lastCreatedAlbumPhotos, hasLength(1));
      expect(
        apiService.lastCreatedAlbumPhotos?.single.url,
        'https://example.com/photo.jpg',
      );
      expect(
        apiService.lastCreatedAlbumPhotos?.single.source,
        AlbumPhotoSource.camera,
      );
      expect(apiService.lastCreatedAlbumIsShared, isTrue);
      expect(dataService.errorMessage, isNull);
    });

    test('updateNote forwards content and shared state to api', () async {
      await dataService.updateNote(
        7,
        content: 'Dinner is in the fridge',
        isShared: false,
      );

      expect(apiService.lastUpdatedNoteId, 7);
      expect(apiService.lastUpdatedNoteContent, 'Dinner is in the fridge');
      expect(apiService.lastUpdatedNoteIsShared, isFalse);
      expect(dataService.errorMessage, isNull);
    });

    test('updateWish forwards content priority and shared state to api',
        () async {
      await dataService.updateWish(
        21,
        content: 'See the first snow together',
        priority: WishPriority.medium,
        isShared: true,
      );

      expect(apiService.lastUpdatedWishId, 21);
      expect(apiService.lastUpdatedWishContent, 'See the first snow together');
      expect(apiService.lastUpdatedWishPriority, 'medium');
      expect(apiService.lastUpdatedWishIsShared, isTrue);
      expect(dataService.errorMessage, isNull);
    });

    test(
        'updateSinglePhotoAlbum forwards url description and shared state to api',
        () async {
      await dataService.updateSinglePhotoAlbum(
        11,
        imageUrl: 'https://example.com/updated.jpg',
        description: 'Updated caption',
        isShared: false,
      );

      expect(apiService.lastUpdatedPhotoId, 11);
      expect(apiService.lastUpdatedPhotoUrl, 'https://example.com/updated.jpg');
      expect(apiService.lastUpdatedPhotoDescription, 'Updated caption');
      expect(apiService.lastUpdatedPhotoIsShared, isFalse);
      expect(dataService.errorMessage, isNull);
    });

    test('deleteNote forwards id to api', () async {
      await dataService.deleteNote(7);

      expect(apiService.lastDeletedNoteId, 7);
      expect(dataService.errorMessage, isNull);
    });

    test('deleteWish forwards id to api', () async {
      await dataService.deleteWish(21);

      expect(apiService.lastDeletedWishId, 21);
      expect(dataService.errorMessage, isNull);
    });

    test('deleteAlbum forwards id to api', () async {
      await dataService.deleteAlbum(11);

      expect(apiService.lastDeletedAlbumId, 11);
      expect(dataService.errorMessage, isNull);
    });

    test('deleteSinglePhotoAlbum forwards id to api album deletion helper',
        () async {
      await dataService.deleteSinglePhotoAlbum(19);

      expect(apiService.lastDeletedPhotoId, 19);
      expect(apiService.lastDeletedAlbumId, isNull);
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
  bool? lastWishIsShared;
  String? lastCreatedAlbumTitle;
  String? lastCreatedAlbumDescription;
  List<AlbumPhotoDraft>? lastCreatedAlbumPhotos;
  bool? lastCreatedAlbumIsShared;
  int? lastUpdatedPhotoId;
  String? lastUpdatedPhotoUrl;
  String? lastUpdatedPhotoDescription;
  bool? lastUpdatedPhotoIsShared;
  int? lastUpdatedWishId;
  String? lastUpdatedWishPriority;
  String? lastUpdatedWishContent;
  bool? lastUpdatedWishIsShared;
  int? lastDeletedWishId;
  int? lastUpdatedNoteId;
  String? lastUpdatedNoteContent;
  bool? lastUpdatedNoteIsShared;
  int? lastDeletedNoteId;
  int? lastDeletedPhotoId;
  String? lastCreatedNoteContent;
  bool? lastCreatedNoteIsShared;
  int? lastDeletedAlbumId;
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
  String? lastUpdatedProfileNickname;
  String? lastUpdatedProfileAvatarUrl;
  String? lastUpdatedProfileStatus;
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
  Future<void> updateProfile({
    required String nickname,
    String? avatarUrl,
    String? status,
  }) async {
    lastUpdatedProfileNickname = nickname;
    lastUpdatedProfileAvatarUrl = avatarUrl;
    lastUpdatedProfileStatus = status;
  }

  @override
  Future<List<Album>> getAlbums() async => const [];

  @override
  Future<List<Post>> getNotes() async => const [];

  @override
  Future<List<Wish>> getWishlist() async => const [];

  @override
  Future<void> createAlbum({
    required String title,
    String? description,
    required List<AlbumPhotoDraft> photos,
    bool isShared = false,
  }) async {
    lastCreatedAlbumTitle = title;
    lastCreatedAlbumDescription = description;
    lastCreatedAlbumPhotos = photos;
    lastCreatedAlbumIsShared = isShared;
  }

  @override
  Future<void> updateSinglePhotoAlbum(
    int id, {
    required String url,
    required String description,
    AlbumPhotoSource source = AlbumPhotoSource.library,
    required bool isShared,
  }) async {
    lastUpdatedPhotoId = id;
    lastUpdatedPhotoUrl = url;
    lastUpdatedPhotoDescription = description;
    lastUpdatedPhotoIsShared = isShared;
  }

  @override
  Future<void> deleteAlbum(int id) async {
    lastDeletedAlbumId = id;
  }

  @override
  Future<void> deleteSinglePhotoAlbum(int id) async {
    lastDeletedPhotoId = id;
  }

  @override
  Future<void> createNote(String content, {bool isShared = false}) async {
    lastCreatedNoteContent = content;
    lastCreatedNoteIsShared = isShared;
  }

  @override
  Future<void> updateNote(
    int id, {
    required String content,
    required bool isShared,
  }) async {
    lastUpdatedNoteId = id;
    lastUpdatedNoteContent = content;
    lastUpdatedNoteIsShared = isShared;
  }

  @override
  Future<void> deleteNote(int id) async {
    lastDeletedNoteId = id;
  }

  @override
  Future<void> addWish(
    String content, {
    String? priority,
    bool isShared = false,
  }) async {
    lastWishContent = content;
    lastWishPriority = priority;
    lastWishIsShared = isShared;
  }

  @override
  Future<void> updateWish(
    int id, {
    required String content,
    required String priority,
    required bool isShared,
  }) async {
    lastUpdatedWishId = id;
    lastUpdatedWishContent = content;
    lastUpdatedWishPriority = priority;
    lastUpdatedWishIsShared = isShared;
  }

  @override
  Future<void> deleteWish(int id) async {
    lastDeletedWishId = id;
  }
}
