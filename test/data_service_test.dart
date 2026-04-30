import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocalin/src/models/group.dart';
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
        requestOptions: RequestOptions(path: '/groups/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/groups/me'),
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
  String? lastCreatedGroupName;
  String? lastInviteCode;
  int getGroupCalls = 0;

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
  Future<List<Post>> getPhotos() async => const [];

  @override
  Future<List<Post>> getNotes() async => const [];

  @override
  Future<List<Wish>> getWishlist() async => const [];
}
