import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/group.dart';
import '../models/group_list_item.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../models/wish.dart';
import 'api_service.dart';

class DataService extends ChangeNotifier {
  DataService({ApiService? apiService, bool autoInitialize = true})
      : _api = apiService ?? ApiService();

  final ApiService _api;

  User? _currentUser;
  Group? _currentGroup;
  List<GroupListItem> _joinedGroups = [];
  List<Post> _posts = [];
  List<Wish> _wishes = [];
  bool _isLoading = false;
  bool _hasLoadedRemoteData = false;

  User? get currentUser => _currentUser;
  Group? get currentGroup => _currentGroup;
  List<GroupListItem> get joinedGroups => _joinedGroups;
  List<Post> get posts => _posts;
  List<Wish> get wishes => _wishes;
  bool get isLoading => _isLoading;
  bool get hasJoinedGroup => _currentGroup != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void syncAuthState(User? user) {
    final userChanged = !_isSameUser(_currentUser, user);
    if (!userChanged && (_hasLoadedRemoteData || _isLoading)) {
      return;
    }

    _errorMessage = null;
    _currentUser = user;

    if (user == null) {
      _resetData();
      notifyListeners();
      return;
    }

    if (userChanged) {
      _currentGroup = null;
      _joinedGroups = [];
      _posts = [];
      _wishes = [];
      _hasLoadedRemoteData = false;
    }

    unawaited(refreshData());
  }

  Future<void> refreshData() async {
    if (_currentUser == null || _isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final groupListData = await _api.getMyGroups();
      _joinedGroups = groupListData.groups;

      final group = await _loadGroupOrNull();
      if (group == null) {
        _currentGroup = null;
        _posts = [];
        _wishes = [];
        _hasLoadedRemoteData = true;
        return;
      }

      final results = await Future.wait<dynamic>([
        _api.getPhotos(),
        _api.getNotes(),
        _api.getWishlist(),
      ]);

      final photos = results[0] as List<Post>;
      final notes = results[1] as List<Post>;
      final wishes = results[2] as List<Wish>;

      _currentGroup = group;
      _posts = [...photos, ...notes]
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      _wishes = wishes;
      _currentUser = _resolveCurrentUserFromGroup(group) ?? _currentUser;
      _hasLoadedRemoteData = true;
    } on DioException catch (error) {
      _errorMessage = _describeDioError(error);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String status) async {
    if (_currentUser == null) {
      return;
    }

    await _runMutation(() async {
      await _api.updateStatus(status);

      _currentUser = User(
        id: _currentUser!.id,
        nickname: _currentUser!.nickname,
        avatarUrl: _currentUser!.avatarUrl,
        currentStatus: status,
        groupId: _currentUser!.groupId,
        role: _currentUser!.role,
      );

      if (_currentGroup != null) {
        final updatedMembers = _currentGroup!.members.map((member) {
          if (member.id != _currentUser!.id) {
            return member;
          }

          return _currentUser!;
        }).toList();

        _currentGroup = Group(
          id: _currentGroup!.id,
          name: _currentGroup!.name,
          inviteCode: _currentGroup!.inviteCode,
          members: updatedMembers,
          creatorId: _currentGroup!.creatorId,
          myRole: _currentGroup!.myRole,
          pinnedMessage: _currentGroup!.pinnedMessage,
          timerStartDate: _currentGroup!.timerStartDate,
          timerTitle: _currentGroup!.timerTitle,
        );
      }

      notifyListeners();
    });
  }

  Future<void> addPost(Post post) async {
    await _runMutation(() async {
      if (post.type == PostType.photo) {
        final imageUrl = post.imageUrl?.trim();
        if (imageUrl == null || imageUrl.isEmpty) {
          return;
        }

        await _api.uploadPhoto(imageUrl, post.content?.trim() ?? '');
      } else {
        final content = post.content?.trim();
        if (content == null || content.isEmpty) {
          return;
        }

        await _api.createNote(content);
      }

      await refreshData();
    });
  }

  Future<void> toggleWish(int wishId) async {
    final wish = _wishes.where((item) => item.id == wishId).firstOrNull;
    if (wish == null) {
      return;
    }

    await _runMutation(() async {
      if (wish.isCompleted) {
        await _api.uncompleteWish(wishId);
      } else {
        await _api.completeWish(wishId);
      }
      await _reloadWishlist();
    });
  }

  Future<void> addWish(
    String title, {
    WishPriority priority = WishPriority.medium,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }

    await _runMutation(() async {
      await _api.addWish(trimmedTitle, priority: priority.apiValue);
      await _reloadWishlist();
    });
  }

  Future<void> updateWishPriority(int wishId, WishPriority priority) async {
    await _runMutation(() async {
      await _api.updateWishPriority(wishId, priority.apiValue);
      await _reloadWishlist();
    });
  }

  Future<void> updateTopMessage(String message) async {
    if (_currentGroup == null) {
      return;
    }

    await _runMutation(() async {
      await _api.updatePinnedMessage(message);

      _currentGroup = Group(
        id: _currentGroup!.id,
        name: _currentGroup!.name,
        inviteCode: _currentGroup!.inviteCode,
        members: _currentGroup!.members,
        creatorId: _currentGroup!.creatorId,
        myRole: _currentGroup!.myRole,
        pinnedMessage: message,
        timerStartDate: _currentGroup!.timerStartDate,
        timerTitle: _currentGroup!.timerTitle,
      );
      notifyListeners();
    });
  }

  Future<void> createGroup(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    await _runMutation(() async {
      final group = await _api.createGroup(trimmedName);
      _applyGroup(group);
      _posts = [];
      _wishes = [];
      _hasLoadedRemoteData = true;
      notifyListeners();
      await refreshData();
    });
  }

  Future<void> joinGroup(String inviteCode) async {
    final trimmedInviteCode = inviteCode.trim();
    if (trimmedInviteCode.isEmpty) {
      return;
    }

    await _runMutation(() async {
      final group = await _api.joinGroup(trimmedInviteCode);
      _applyGroup(group);
      _posts = [];
      _wishes = [];
      _hasLoadedRemoteData = true;
      notifyListeners();
      await refreshData();
    });
  }

  Future<void> switchCurrentGroup(int groupId) async {
    await _runMutation(() async {
      await _api.switchCurrentGroup(groupId);
      await refreshData();
    });
  }

  Future<void> leaveGroup(int groupId) async {
    await _runMutation(() async {
      await _api.leaveGroup(groupId);
      await refreshData();
    });
  }

  Future<void> removeGroupMember({
    required int groupId,
    required int targetUserId,
  }) async {
    await _runMutation(() async {
      await _api.removeGroupMember(
        groupId: groupId,
        targetUserId: targetUserId,
      );
      await refreshData();
    });
  }

  Future<void> transferGroupOwnership({
    required int groupId,
    required int targetUserId,
  }) async {
    await _runMutation(() async {
      await _api.transferGroupOwnership(
        groupId: groupId,
        targetUserId: targetUserId,
      );
      await refreshData();
    });
  }

  Future<void> dissolveGroup(int groupId) async {
    await _runMutation(() async {
      await _api.dissolveGroup(groupId);
      await refreshData();
    });
  }

  Future<Group?> _loadGroupOrNull() async {
    try {
      return await _api.getGroup();
    } on DioException catch (error) {
      if (error.response?.statusCode == 404 || _isNoGroupError(error)) {
        return null;
      }

      rethrow;
    }
  }

  Future<void> _reloadWishlist() async {
    _wishes = await _api.getWishlist();
    notifyListeners();
  }

  User? _resolveCurrentUserFromGroup(Group group) {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) {
      return _currentUser;
    }

    for (final member in group.members) {
      if (member.id == currentUserId) {
        return member;
      }
    }

    return _currentUser;
  }

  void _resetData() {
    _currentGroup = null;
    _joinedGroups = [];
    _posts = [];
    _wishes = [];
    _isLoading = false;
    _hasLoadedRemoteData = false;
  }

  void _applyGroup(Group group) {
    _currentGroup = group;
    _currentUser = _resolveCurrentUserFromGroup(group) ?? _currentUser;
  }

  String _describeDioError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    return error.message ?? 'Request failed';
  }

  bool _isNoGroupError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 404) {
      return true;
    }

    final message = _describeDioError(error).toLowerCase();
    return message.contains('用户尚未加入空间') ||
        message.contains('未加入空间') ||
        message.contains('not joined') ||
        message.contains('no group');
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    _errorMessage = null;

    try {
      await action();
    } on DioException catch (error) {
      _errorMessage = _describeDioError(error);
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  bool _isSameUser(User? previous, User? next) {
    return previous?.id == next?.id;
  }
}
