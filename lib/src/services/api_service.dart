import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/group.dart';
import '../models/group_action_result.dart';
import '../models/group_list_item.dart';
import '../models/post.dart';
import '../models/space_inbox_item.dart';
import '../models/user.dart';
import '../models/wish.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  static const _skipAuthRefreshKey = 'skipAuthRefresh';
  static const _didRetryAuthRefreshKey = 'didRetryAuthRefresh';

  static const String _configuredBaseUrlFromBuild = String.fromEnvironment(
    'VOCALIN_API_BASE_URL',
  );

  late Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  Future<String?>? _refreshAccessTokenFuture;
  Future<void> Function(String accessToken, String? refreshToken)?
      _onAuthTokensUpdated;
  Future<void> Function()? _onUnauthorized;

  ApiService._internal() {
    _dio = Dio(_buildBaseOptions());
    _configureDio(_dio);
  }

  ApiService.test({Dio? dio}) {
    _dio = dio ?? Dio(_buildBaseOptions());
    _configureDio(_dio);
  }

  static BaseOptions _buildBaseOptions() {
    return BaseOptions(
      baseUrl: _resolveBaseUrl(),
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    );
  }

  void _configureDio(Dio dio) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('🌐 [API Request] ${options.method} ${options.uri}');
        print('   Headers: ${options.headers}');
        print('   Data: ${options.data}');
        if (_accessToken != null && _accessToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
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
        _handleError(e, handler);
      },
    ));
  }

  Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldAttemptTokenRefresh(error)) {
      handler.next(error);
      return;
    }

    try {
      final accessToken = await _refreshAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        await _notifyUnauthorized();
        handler.next(error);
        return;
      }

      final response = await _retryRequest(error.requestOptions);
      handler.resolve(response);
      return;
    } catch (refreshError) {
      print('❌ [API Refresh Error] $refreshError');
      await _notifyUnauthorized();
      handler.next(error);
    }
  }

  bool _shouldAttemptTokenRefresh(DioException error) {
    final statusCode = error.response?.statusCode;
    final extra = error.requestOptions.extra;

    return statusCode == 401 &&
        extra[_skipAuthRefreshKey] != true &&
        extra[_didRetryAuthRefreshKey] != true;
  }

  Future<void> _notifyUnauthorized() async {
    if (_onUnauthorized == null) {
      return;
    }

    await _onUnauthorized!.call();
  }

  Future<String?> _refreshAccessToken() async {
    final inFlightRefresh = _refreshAccessTokenFuture;
    if (inFlightRefresh != null) {
      return inFlightRefresh;
    }

    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final future = _refreshAccessTokenInternal(refreshToken);
    _refreshAccessTokenFuture = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshAccessTokenFuture, future)) {
        _refreshAccessTokenFuture = null;
      }
    }
  }

  Future<String?> _refreshAccessTokenInternal(String refreshToken) async {
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(extra: const {_skipAuthRefreshKey: true}),
    );

    final tokens = _parseAuthTokens(response.data);
    final accessToken = tokens.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException(
        'Refresh response does not contain an access token.',
      );
    }

    _accessToken = accessToken;
    if (tokens.refreshToken != null && tokens.refreshToken!.isNotEmpty) {
      _refreshToken = tokens.refreshToken;
    }

    if (_onAuthTokensUpdated != null) {
      await _onAuthTokensUpdated!.call(_accessToken!, _refreshToken);
    }

    return _accessToken;
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions) {
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    headers.remove('Authorization');

    final extra = Map<String, dynamic>.from(requestOptions.extra);
    extra[_didRetryAuthRefreshKey] = true;

    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      onReceiveProgress: requestOptions.onReceiveProgress,
      onSendProgress: requestOptions.onSendProgress,
      options: Options(
        method: requestOptions.method,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        extra: extra,
        headers: headers,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        followRedirects: requestOptions.followRedirects,
        maxRedirects: requestOptions.maxRedirects,
        persistentConnection: requestOptions.persistentConnection,
        requestEncoder: requestOptions.requestEncoder,
        responseDecoder: requestOptions.responseDecoder,
        listFormat: requestOptions.listFormat,
      ),
    );
  }

  static String _resolveBaseUrl() {
    final configuredBaseUrlFromEnvFile = dotenv.env['VOCALIN_API_BASE_URL'];

    if (configuredBaseUrlFromEnvFile != null &&
        configuredBaseUrlFromEnvFile.isNotEmpty) {
      return configuredBaseUrlFromEnvFile;
    }

    if (_configuredBaseUrlFromBuild.isNotEmpty) {
      return _configuredBaseUrlFromBuild;
    }

    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080/api';
      default:
        return 'http://127.0.0.1:8080/api';
    }
  }

  void setUserId(String? userId) {
    _userId = userId;
  }

  void setAccessToken(String? accessToken) {
    _accessToken = accessToken;
  }

  void setRefreshToken(String? refreshToken) {
    _refreshToken = refreshToken;
  }

  void registerAuthStateHandlers({
    Future<void> Function(String accessToken, String? refreshToken)?
        onAuthTokensUpdated,
    Future<void> Function()? onUnauthorized,
  }) {
    _onAuthTokensUpdated = onAuthTokensUpdated;
    _onUnauthorized = onUnauthorized;
  }

  // Auth
  Future<AuthResult> loginWithNickname({
    required String nickname,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'nickname': nickname,
      'password': password,
    });

    return _parseAuthResult(response.data);
  }

  Future<AuthResult> register({
    required String nickname,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'nickname': nickname,
      'phone': phone,
      'password': password,
      'confirm_password': confirmPassword,
    });

    return _parseAuthResult(response.data);
  }

  Future<void> logout({required String refreshToken}) async {
    await _dio.post(
      '/auth/logout',
      data: {
        'refresh_token': refreshToken,
      },
      options: Options(extra: const {_skipAuthRefreshKey: true}),
    );
  }

  AuthResult _parseAuthResult(dynamic payload) {
    final rootMap = _asMap(payload);
    final dataMap = _asMap(rootMap['data']);
    final source = dataMap.isNotEmpty ? dataMap : rootMap;

    final userMap = _extractUserMap(source, rootMap);
    if (userMap.isEmpty) {
      throw const FormatException('Auth response does not contain user data.');
    }

    final accessToken = _firstNonEmptyString([
      source['access_token'],
      source['accessToken'],
      source['token'],
      rootMap['access_token'],
      rootMap['accessToken'],
      rootMap['token'],
    ]);

    final refreshToken = _firstNonEmptyString([
      source['refresh_token'],
      source['refreshToken'],
      rootMap['refresh_token'],
      rootMap['refreshToken'],
    ]);

    return AuthResult(
      user: User.fromJson(userMap),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  AuthTokens _parseAuthTokens(dynamic payload) {
    final rootMap = _asMap(payload);
    final dataMap = _asMap(rootMap['data']);
    final source = dataMap.isNotEmpty ? dataMap : rootMap;

    final accessToken = _firstNonEmptyString([
      source['access_token'],
      source['accessToken'],
      source['token'],
      rootMap['access_token'],
      rootMap['accessToken'],
      rootMap['token'],
    ]);

    final refreshToken = _firstNonEmptyString([
      source['refresh_token'],
      source['refreshToken'],
      rootMap['refresh_token'],
      rootMap['refreshToken'],
    ]);

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Map<String, dynamic> _extractUserMap(
    Map<String, dynamic> source,
    Map<String, dynamic> rootMap,
  ) {
    final nestedUser = _asMap(source['user']);
    if (nestedUser.isNotEmpty) {
      return nestedUser;
    }

    final rootUser = _asMap(rootMap['user']);
    if (rootUser.isNotEmpty) {
      return rootUser;
    }

    if (source['nickname'] != null && source['id'] != null) {
      return source;
    }

    if (rootMap['nickname'] != null && rootMap['id'] != null) {
      return rootMap;
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _asMap(dynamic value) {
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

  String? _firstNonEmptyString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.isNotEmpty) {
        return candidate;
      }
    }

    return null;
  }

  Map<String, dynamic> _extractResponseDataMap(dynamic payload) {
    final rootMap = _asMap(payload);
    final dataMap = _asMap(rootMap['data']);
    return dataMap.isNotEmpty ? dataMap : rootMap;
  }

  List<dynamic> _extractResponseDataList(dynamic payload) {
    if (payload is List) {
      return payload;
    }

    final rootMap = _asMap(payload);
    final data = rootMap['data'];
    if (data is List) {
      return data;
    }

    return const [];
  }

  // Group
  Future<GroupListData> getMyGroups() async {
    final response = await _dio.get('/groups');
    return GroupListData.fromJson(_extractResponseDataMap(response.data));
  }

  Future<Group> getGroup() async {
    final response = await _dio.get('/groups/current');
    return Group.fromJson(_extractResponseDataMap(response.data));
  }

  Future<Group> createGroup(String name) async {
    final response = await _dio.post('/groups/create', data: {'name': name});
    return Group.fromJson(_extractResponseDataMap(response.data));
  }

  Future<GroupActionResult> joinGroup(String inviteCode) async {
    final response =
        await _dio.post('/groups/join', data: {'invite_code': inviteCode});
    return GroupActionResult.fromResponse(response.data);
  }

  Future<void> switchCurrentGroup(int groupId) async {
    await _dio.put('/groups/current', data: {'group_id': groupId});
  }

  Future<void> leaveGroup(int groupId) async {
    await _dio.delete('/groups/$groupId/members/me');
  }

  Future<void> removeGroupMember({
    required int groupId,
    required int targetUserId,
  }) async {
    await _dio.delete('/groups/$groupId/members/$targetUserId');
  }

  Future<GroupActionResult> transferGroupOwnership({
    required int groupId,
    required int targetUserId,
  }) async {
    final response = await _dio.put(
      '/groups/$groupId/owner',
      data: {'target_user_id': targetUserId},
    );
    return GroupActionResult.fromResponse(response.data);
  }

  Future<void> dissolveGroup(int groupId) async {
    await _dio.delete('/groups/$groupId');
  }

  // Home
  Future<void> updateStatus(String status) async {
    await _dio.put('/home/status', data: {'status': status});
  }

  Future<void> updatePinnedMessage(String content) async {
    await _dio.put('/home/pinned', data: {'content': content});
  }

  Future<List<SpaceInboxItem>> getHomeMessages() async {
    final response = await _dio.get('/home/messages');
    return _extractResponseDataList(response.data)
        .map((item) => SpaceInboxItem.fromJson(_asMap(item)))
        .toList();
  }

  Future<void> reviewGroupJoinRequest({
    required int groupId,
    required int requestId,
    required String action,
  }) async {
    await _dio.post(
      '/groups/$groupId/join-requests/$requestId/review',
      data: {'action': action},
    );
  }

  Future<void> reviewOwnershipTransfer({
    required int groupId,
    required String action,
  }) async {
    await _dio.post(
      '/groups/$groupId/owner/review',
      data: {'action': action},
    );
  }

  // Records
  Future<List<Post>> getPhotos() async {
    final response = await _dio.get('/records/photos');
    return _extractResponseDataList(response.data)
        .map((item) => Post.fromPhotoJson(_asMap(item)))
        .toList();
  }

  Future<void> uploadPhoto(String url, String description) async {
    await _dio.post('/records/photos', data: {
      'url': url,
      'description': description,
    });
  }

  Future<List<Post>> getNotes() async {
    final response = await _dio.get('/records/notes');
    return _extractResponseDataList(response.data)
        .map((item) => Post.fromNoteJson(_asMap(item)))
        .toList();
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
    return _extractResponseDataList(response.data)
        .map((item) => Wish.fromJson(_asMap(item)))
        .toList();
  }

  Future<void> addWish(String content, {String? priority}) async {
    await _dio.post('/records/wishlist', data: {
      'content': content,
      if (priority != null) 'priority': priority,
    });
  }

  Future<void> completeWish(int id) async {
    await _dio.put('/records/wishlist/$id/complete');
  }

  Future<void> uncompleteWish(int id) async {
    await _dio.put('/records/wishlist/$id/incomplete');
  }

  Future<void> updateWishPriority(int id, String priority) async {
    await _dio.put('/records/wishlist/$id/priority', data: {
      'priority': priority,
    });
  }
}

class AuthResult {
  const AuthResult({
    required this.user,
    this.accessToken,
    this.refreshToken,
  });

  final User user;
  final String? accessToken;
  final String? refreshToken;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String? accessToken;
  final String? refreshToken;
}
