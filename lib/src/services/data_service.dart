import 'package:flutter/foundation.dart';

import '../models/group.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../models/wish.dart';
import 'api_service.dart';

class DataService extends ChangeNotifier {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;

  final ApiService _api = ApiService();

  DataService._internal() {
    print('🚀 DataService initialized');
    _initData();
  }

  User? _currentUser;
  Group? _currentGroup;
  List<Post> _posts = [];
  List<Wish> _wishes = [];
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  Group? get currentGroup => _currentGroup;
  List<Post> get posts => _posts;
  List<Wish> get wishes => _wishes;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> _initData() async {
    print('🔄 _initData started');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Auto-login for demo purposes
      // In a real app, you'd check for a stored token or show a login screen
      print('🔑 Attempting login...');
      _currentUser = await _api.login('wx_user_001', nickname: 'Alice');
      print('✅ Login successful: ${_currentUser?.nickname}');

      await _refreshGroupData();
    } catch (e) {
      print('❌ Error initializing data: $e');
      debugPrint('Error initializing data: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshGroupData() async {
    try {
      _currentGroup = await _api.getGroup();

      final photos = await _api.getPhotos();
      final notes = await _api.getNotes();
      _posts = [...photos, ...notes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _wishes = await _api.getWishlist();
    } catch (e) {
      debugPrint('Error refreshing group data: $e');
      // If 404 or similar, it might mean user has no group
      _currentGroup = null;
    }
  }

  Future<void> updateStatus(String status) async {
    try {
      await _api.updateStatus(status);
      if (_currentUser != null) {
        // Optimistic update
        _currentUser = User(
          id: _currentUser!.id,
          nickname: _currentUser!.nickname,
          avatarUrl: _currentUser!.avatarUrl,
          currentStatus: status,
          groupId: _currentUser!.groupId,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Future<void> addPost(Post post) async {
    // This method signature is a bit weird now since we have separate APIs
    // But for compatibility with existing UI calling code:
    try {
      if (post.type == PostType.note && post.content != null) {
        await _api.createNote(post.content!);
      } else if (post.type == PostType.photo && post.imageUrl != null) {
        await _api.uploadPhoto(post.imageUrl!, post.content ?? '');
      }
      await _refreshGroupData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding post: $e');
    }
  }

  Future<void> toggleWish(int wishId) async {
    try {
      await _api.completeWish(wishId);
      // Refresh to get updated state
      _wishes = await _api.getWishlist();
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling wish: $e');
    }
  }

  Future<void> addWish(String title) async {
    try {
      await _api.addWish(title);
      _wishes = await _api.getWishlist();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding wish: $e');
    }
  }

  Future<void> updateTopMessage(String message) async {
    try {
      await _api.updatePinnedMessage(message);
      _currentGroup = await _api.getGroup();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating top message: $e');
    }
  }
}
