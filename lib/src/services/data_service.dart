import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/album.dart';
import '../models/group.dart';
import '../models/group_action_result.dart';
import '../models/group_list_item.dart';
import '../models/note_folder.dart';
import '../models/post.dart';
import '../models/space_inbox_item.dart';
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
  List<SpaceInboxItem> _spaceInboxItems = [];
  List<Album> _albums = [];
  List<Post> _posts = [];
  List<Wish> _wishes = [];
  List<NoteFolder> _noteFolders = [];
  bool _isLoading = false;
  bool _hasLoadedRemoteData = false;

  User? get currentUser => _currentUser;
  Group? get currentGroup => _currentGroup;
  List<GroupListItem> get joinedGroups => _joinedGroups;
  List<SpaceInboxItem> get spaceInboxItems => _spaceInboxItems;
  List<Album> get albums => _albums;
  List<Post> get posts => _posts;
  List<Wish> get wishes => _wishes;
  List<NoteFolder> get noteFolders => List.unmodifiable(_noteFolders);
  List<String> get noteFoldersForCurrentGroup => List.unmodifiable(
        _noteFolders
            .where((folder) => folder.isCustom)
            .map((folder) => folder.name)
            .toList(growable: false),
      );
  bool get isLoading => _isLoading;
  bool get hasJoinedGroup => _currentGroup != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void clearErrorMessage() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

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
      _spaceInboxItems = [];
      _albums = [];
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
      _joinedGroups = [
        ...groupListData.groups,
        ...groupListData.pendingRequests
      ];
      _spaceInboxItems = (await _api.getHomeMessages())
          .where((item) => item.isPending)
          .toList();

      final group = await _loadGroupOrNull();
      if (group == null) {
        _currentGroup = null;
        _albums = [];
        _posts = [];
        _wishes = [];
        _noteFolders = [];
        _hasLoadedRemoteData = true;
        return;
      }

      final results = await Future.wait<dynamic>([
        _api.getAlbums(),
        _api.getNotes(),
        _api.getWishlist(),
        _api.getNoteFolders(),
      ]);

      final albums = results[0] as List<Album>;
      final notes = results[1] as List<Post>;
      final wishes = results[2] as List<Wish>;
      final noteFolders = results[3] as List<NoteFolder>;

      _currentGroup = group;
      _albums = [...albums]
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      _posts = [...albums.map(Post.fromAlbumActivity), ...notes]
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      _wishes = wishes;
      _noteFolders = noteFolders;
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
        membershipStatus: _currentUser!.membershipStatus,
        ownershipTransferStatus: _currentUser!.ownershipTransferStatus,
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
          pendingOwnershipTransfer: _currentGroup!.pendingOwnershipTransfer,
          pendingOwnershipTransferRequestId:
              _currentGroup!.pendingOwnershipTransferRequestId,
          pendingOwnerId: _currentGroup!.pendingOwnerId,
        );
      }

      notifyListeners();
    });
  }

  Future<void> updateProfile({
    required String nickname,
    String? avatarUrl,
    String? status,
  }) async {
    if (_currentUser == null) {
      return;
    }

    final trimmedNickname = nickname.trim();
    final normalizedAvatarUrl = avatarUrl?.trim();
    final normalizedStatus = status?.trim();

    await _runMutation(() async {
      await _api.updateProfile(
        nickname: trimmedNickname,
        avatarUrl: normalizedAvatarUrl == null || normalizedAvatarUrl.isEmpty
            ? null
            : normalizedAvatarUrl,
        status: normalizedStatus == null || normalizedStatus.isEmpty
            ? null
            : normalizedStatus,
      );

      _currentUser = User(
        id: _currentUser!.id,
        nickname: trimmedNickname,
        avatarUrl: normalizedAvatarUrl == null || normalizedAvatarUrl.isEmpty
            ? null
            : normalizedAvatarUrl,
        currentStatus: normalizedStatus == null || normalizedStatus.isEmpty
            ? null
            : normalizedStatus,
        groupId: _currentUser!.groupId,
        role: _currentUser!.role,
        membershipStatus: _currentUser!.membershipStatus,
        ownershipTransferStatus: _currentUser!.ownershipTransferStatus,
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
          pendingOwnershipTransfer: _currentGroup!.pendingOwnershipTransfer,
          pendingOwnershipTransferRequestId:
              _currentGroup!.pendingOwnershipTransferRequestId,
          pendingOwnerId: _currentGroup!.pendingOwnerId,
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

        final title = post.content?.trim();

        await _api.createAlbum(
          title: title == null || title.isEmpty ? 'Untitled Album' : title,
          description: post.content?.trim(),
          photos: [
            AlbumPhotoDraft(
              url: imageUrl,
              description: post.content?.trim(),
            ),
          ],
          isShared: post.isShared,
        );
      } else {
        final content = post.content?.trim();
        if (content == null || content.isEmpty) {
          return;
        }

        await _api.createNote(
          content,
          title: post.title,
          isShared: post.isShared,
          groupId: post.groupId,
        );
      }

      await refreshData();
    });
  }

  Future<void> createAlbum({
    required String title,
    String? description,
    required List<AlbumPhotoDraft> photos,
    bool isShared = false,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }

    final normalizedPhotos = photos
        .map(
          (photo) => AlbumPhotoDraft(
            url: photo.url.trim(),
            description: photo.description?.trim(),
            source: photo.source,
          ),
        )
        .where((photo) => photo.url.isNotEmpty)
        .toList();

    if (normalizedPhotos.isEmpty) {
      return;
    }

    await _runMutation(() async {
      await _api.createAlbum(
        title: trimmedTitle,
        description: description?.trim(),
        photos: normalizedPhotos,
        isShared: isShared,
      );
      await refreshData();
    });
  }

  Future<void> deleteAlbum(int albumId) async {
    await _runMutation(() async {
      await _api.deleteAlbum(albumId);
      await refreshData();
    });
  }

  Future<void> updateSinglePhotoAlbum(
    int photoId, {
    required String imageUrl,
    required String description,
    required bool isShared,
  }) async {
    final trimmedTitle = description.trim();
    final trimmedImageUrl = imageUrl.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }
    if (trimmedImageUrl.isEmpty) {
      return;
    }

    await _runMutation(() async {
      await _api.updateSinglePhotoAlbum(
        photoId,
        url: trimmedImageUrl,
        description: description.trim(),
        isShared: isShared,
      );
      await refreshData();
    });
  }

  Future<void> deleteSinglePhotoAlbum(int photoId) async {
    await _runMutation(() async {
      await _api.deleteSinglePhotoAlbum(photoId);
      await refreshData();
    });
  }

  Future<void> updateNote(
    int noteId, {
    String? title,
    required String content,
    required bool isShared,
    int? groupId,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return;
    }

    await _runMutation(() async {
      await _api.updateNote(
        noteId,
        title: title,
        content: trimmedContent,
        isShared: isShared,
        groupId: groupId,
      );
      await refreshData();
    });
  }

  Future<void> deleteNote(int noteId) async {
    await _runMutation(() async {
      await _api.deleteNote(noteId);
      await refreshData();
    });
  }

  Future<void> updateNoteVisibility(int noteId,
      {required bool isShared}) async {
    await _runMutation(() async {
      await _api.updateNoteVisibility(noteId, isShared: isShared);
      await refreshData();
    });
  }

  Future<void> createNoteFolder(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final hasDuplicate = _noteFolders.any(
      (folder) =>
          folder.isCustom &&
          folder.name.toLowerCase() == normalizedName.toLowerCase(),
    );
    if (hasDuplicate) {
      return;
    }

    await _runMutation(() async {
      await _api.createNoteFolder(normalizedName);
      await refreshData();
    });
  }

  Future<void> deleteNoteFolder(int folderId) async {
    await _runMutation(() async {
      await _api.deleteNoteFolder(folderId);
      await refreshData();
    });
  }

  Future<void> moveNoteToFolder(int noteId, String? folderName) async {
    final normalizedName = folderName?.trim();
    final folderId = normalizedName == null || normalizedName.isEmpty
        ? null
        : _noteFolders
            .where(
              (folder) =>
                  folder.isCustom &&
                  folder.name.toLowerCase() == normalizedName.toLowerCase(),
            )
            .firstOrNull
            ?.id;

    await _runMutation(() async {
      await _api.moveNoteToFolder(noteId, folderId: folderId);
      await refreshData();
    });
  }

  NoteFolder? noteFolderForName(String name) {
    final normalizedName = name.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return null;
    }

    return _noteFolders
        .where((folder) => folder.name.toLowerCase() == normalizedName)
        .firstOrNull;
  }

  String? noteFolderNameFor(int noteId) {
    final note = _posts
        .where((post) => post.type == PostType.note && post.id == noteId)
        .firstOrNull;
    final folderName = note?.folderName?.trim();
    if (folderName == null || folderName.isEmpty) {
      return null;
    }

    return folderName;
  }

  bool isSharedNoteFromOtherUser(Post note) {
    if (!note.isShared) {
      return false;
    }

    final currentNickname = _currentUser?.nickname.trim().toLowerCase();
    final ownerNickname = note.ownerNickname?.trim().toLowerCase();
    if (currentNickname == null || currentNickname.isEmpty) {
      return false;
    }

    if (ownerNickname == null || ownerNickname.isEmpty) {
      return false;
    }

    return ownerNickname != currentNickname;
  }

  String noteFolderLabelFor(Post note) {
    if (isSharedNoteFromOtherUser(note)) {
      return 'Share';
    }

    final folderName = note.folderName?.trim();
    if (folderName == null || folderName.isEmpty) {
      return 'All';
    }

    return folderName;
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
    bool isShared = false,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }

    await _runMutation(() async {
      await _api.addWish(
        trimmedTitle,
        priority: priority.apiValue,
        isShared: isShared,
      );
      await _reloadWishlist();
    });
  }

  Future<void> updateWish(
    int wishId, {
    required String content,
    required WishPriority priority,
    required bool isShared,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return;
    }

    await _runMutation(() async {
      await _api.updateWish(
        wishId,
        content: trimmedContent,
        priority: priority.apiValue,
        isShared: isShared,
      );
      await _reloadWishlist();
    });
  }

  Future<void> deleteWish(int wishId) async {
    await _runMutation(() async {
      await _api.deleteWish(wishId);
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
        pendingOwnershipTransfer: _currentGroup!.pendingOwnershipTransfer,
        pendingOwnershipTransferRequestId:
            _currentGroup!.pendingOwnershipTransferRequestId,
        pendingOwnerId: _currentGroup!.pendingOwnerId,
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

  Future<GroupActionResult> joinGroup(String inviteCode) async {
    final trimmedInviteCode = inviteCode.trim();
    if (trimmedInviteCode.isEmpty) {
      return const GroupActionResult(status: GroupActionStatus.completed);
    }

    var result = const GroupActionResult(status: GroupActionStatus.completed);

    await _runMutation(() async {
      final response = await _api.joinGroup(trimmedInviteCode);
      result = response;

      if (!response.isPendingApproval && response.group != null) {
        _applyGroup(response.group!);
        _posts = [];
        _wishes = [];
        _hasLoadedRemoteData = true;
        notifyListeners();
      }

      await refreshData();

      final pendingRequest = _joinedGroups.where((item) {
        return item.isPendingApproval &&
            item.inviteCode.toUpperCase() == trimmedInviteCode.toUpperCase();
      }).firstOrNull;
      if (pendingRequest != null) {
        result = GroupActionResult(
          status: GroupActionStatus.pendingApproval,
          groupListItem: pendingRequest,
          message: response.message ?? '已发起申请',
        );
      }
    });

    return result;
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

  Future<GroupActionResult> transferGroupOwnership({
    required int groupId,
    required int targetUserId,
  }) async {
    var result = const GroupActionResult(status: GroupActionStatus.completed);

    await _runMutation(() async {
      final response = await _api.transferGroupOwnership(
        groupId: groupId,
        targetUserId: targetUserId,
      );
      await refreshData();

      if (_currentGroup?.id == groupId &&
          _currentGroup?.isOwnershipTransferPending == true) {
        result = GroupActionResult(
          status: GroupActionStatus.pendingApproval,
          message: response.message ?? '已发起移交',
        );
      } else {
        result = response;
      }
    });

    return result;
  }

  Future<void> approveJoinRequest({
    required int groupId,
    required int requestId,
  }) async {
    await _runMutation(() async {
      await _api.reviewGroupJoinRequest(
        groupId: groupId,
        requestId: requestId,
        action: 'approve',
      );
      await refreshData();
    });
  }

  Future<void> rejectJoinRequest({
    required int groupId,
    required int requestId,
  }) async {
    await _runMutation(() async {
      await _api.reviewGroupJoinRequest(
        groupId: groupId,
        requestId: requestId,
        action: 'reject',
      );
      await refreshData();
    });
  }

  Future<void> approveOwnershipTransfer({required int groupId}) async {
    await _runMutation(() async {
      await _api.reviewOwnershipTransfer(
        groupId: groupId,
        action: 'approve',
      );
      await refreshData();
    });
  }

  Future<void> rejectOwnershipTransfer({required int groupId}) async {
    await _runMutation(() async {
      await _api.reviewOwnershipTransfer(
        groupId: groupId,
        action: 'reject',
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
    _spaceInboxItems = [];
    _albums = [];
    _posts = [];
    _wishes = [];
    _noteFolders = [];
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
