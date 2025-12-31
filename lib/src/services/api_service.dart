import 'package:dio/dio.dart';

import '../models/group.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../models/wish.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _userId;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.vocalin.top/api',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));

    // Add interceptor to inject User ID and Log requests
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('🌐 [API Request] ${options.method} ${options.uri}');
        print('   Headers: ${options.headers}');
        print('   Data: ${options.data}');
        if (_userId != null) {
          options.headers['X-User-ID'] = _userId;
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print(
            '✅ [API Response] ${response.statusCode} ${response.requestOptions.uri}');
        print('   Data: ${response.data}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print('❌ [API Error] ${e.message} for ${e.requestOptions.uri}');
        if (e.response != null) {
          print('   Status: ${e.response?.statusCode}');
          print('   Data: ${e.response?.data}');
        }
        return handler.next(e);
      },
    ));
  }

  void setUserId(String userId) {
    _userId = userId;
  }

  // Auth
  Future<User> login(String wechatId,
      {String? nickname, String? avatarUrl}) async {
    final response = await _dio.post('/auth/login', data: {
      'wechat_id': wechatId,
      'nickname': nickname ?? 'User',
      'avatar_url': avatarUrl,
    });
    final user = User.fromJson(response.data);
    setUserId(user.id.toString());
    return user;
  }

  // Group
  Future<Group> getGroup() async {
    final response = await _dio.get('/groups/me');
    return Group.fromJson(response.data);
  }

  Future<Group> createGroup(String name) async {
    final response = await _dio.post('/groups/create', data: {'name': name});
    return Group.fromJson(response.data);
  }

  Future<Group> joinGroup(String inviteCode) async {
    final response =
        await _dio.post('/groups/join', data: {'invite_code': inviteCode});
    return Group.fromJson(response.data);
  }

  // Home
  Future<void> updateStatus(String status) async {
    await _dio.put('/home/status', data: {'status': status});
  }

  Future<void> updatePinnedMessage(String content) async {
    await _dio.put('/home/pinned', data: {'content': content});
  }

  // Records
  Future<List<Post>> getPhotos() async {
    final response = await _dio.get('/records/photos');
    return (response.data as List).map((e) => Post.fromPhotoJson(e)).toList();
  }

  Future<void> uploadPhoto(String url, String description) async {
    await _dio.post('/records/photos', data: {
      'url': url,
      'description': description,
    });
  }

  Future<List<Post>> getNotes() async {
    final response = await _dio.get('/records/notes');
    return (response.data as List).map((e) => Post.fromNoteJson(e)).toList();
  }

  Future<void> createNote(String content) async {
    await _dio.post('/records/notes', data: {
      'content': content,
      'type': 'normal', // Default for now
      'color': 'yellow',
    });
  }

  Future<List<Wish>> getWishlist() async {
    final response = await _dio.get('/records/wishlist');
    return (response.data as List).map((e) => Wish.fromJson(e)).toList();
  }

  Future<void> addWish(String content) async {
    await _dio.post('/records/wishlist', data: {'content': content});
  }

  Future<void> completeWish(int id) async {
    await _dio.put('/records/wishlist/$id/complete');
  }
}
