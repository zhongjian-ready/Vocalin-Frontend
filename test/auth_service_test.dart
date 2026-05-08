import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocalin/src/models/album.dart';
import 'package:vocalin/src/models/post.dart';
import 'package:vocalin/src/services/api_service.dart';
import 'package:vocalin/src/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService response parsing', () {
    test('unwraps group and records payloads from Swagger APIResponse',
        () async {
      final dio = Dio(
        BaseOptions(baseUrl: 'http://localhost:8080/api'),
      );
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) {
        final requestPath = options.uri.path;

        if (requestPath.endsWith('/groups/current')) {
          return _jsonResponse(
            options,
            200,
            {
              'code': 'OK',
              'message': 'success',
              'data': {
                'id': 1,
                'name': 'Warm Home',
                'invite_code': 'ABCD',
                'members': const [],
              },
            },
          );
        }

        if (requestPath.endsWith('/records/albums')) {
          return _jsonResponse(
            options,
            200,
            {
              'code': 'OK',
              'message': 'success',
              'data': [
                {
                  'id': 11,
                  'title': 'Weekend Walk',
                  'description': 'Along the river',
                  'visibility': 'public',
                  'photos': [
                    {
                      'id': 101,
                      'url': 'https://example.com/photo.jpg',
                      'description': 'Cover shot',
                      'source': 'camera',
                      'createdAt': '2026-04-30T10:00:00Z',
                      'updatedAt': '2026-04-30T10:05:00Z',
                    },
                    {
                      'id': 102,
                      'url': 'https://example.com/photo-2.jpg',
                      'source': 'library',
                      'createdAt': '2026-04-30T10:06:00Z',
                      'updatedAt': '2026-04-30T10:06:00Z',
                    },
                    {
                      'id': 103,
                      'url': 'https://example.com/photo-3.jpg',
                      'source': 'library',
                      'createdAt': '2026-04-30T10:07:00Z',
                      'updatedAt': '2026-04-30T10:07:00Z',
                    },
                  ],
                  'createdAt': '2026-04-30T10:00:00Z',
                  'updatedAt': '2026-04-30T10:05:00Z',
                },
              ],
            },
          );
        }

        if (requestPath.endsWith('/records/notes')) {
          return _jsonResponse(
            options,
            200,
            {
              'code': 'OK',
              'message': 'success',
              'data': [
                {
                  'id': 12,
                  'content': 'note',
                  'color': 'yellow',
                  'createdAt': '2026-04-29T10:00:00Z',
                },
              ],
            },
          );
        }

        if (requestPath.endsWith('/records/wishlist')) {
          return _jsonResponse(
            options,
            200,
            {
              'code': 'OK',
              'message': 'success',
              'data': [
                {
                  'id': 13,
                  'content': 'wish',
                  'is_completed': true,
                  'group_id': 1,
                },
              ],
            },
          );
        }

        throw StateError(
            'Unexpected request: ${options.method} ${options.uri}');
      });

      final apiService = ApiService.test(dio: dio);

      final group = await apiService.getGroup();
      final albums = await apiService.getAlbums();
      final notes = await apiService.getNotes();
      final wishes = await apiService.getWishlist();

      expect(group.name, 'Warm Home');
      expect(albums.single.coverImageUrl, 'https://example.com/photo.jpg');
      expect(albums.single.totalPhotos, 3);
      expect(notes.single.type, PostType.note);
      expect(notes.single.createdAt.toUtc(),
          DateTime.parse('2026-04-29T10:00:00Z'));
      expect(wishes.single.isCompleted, isTrue);
    });

    test('createAlbum sends album payload matching Swagger contract', () async {
      late Map<String, dynamic> capturedBody;

      final dio = Dio(
        BaseOptions(baseUrl: 'http://localhost:8080/api'),
      );
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) {
        if (options.uri.path.endsWith('/records/albums') &&
            options.method == 'POST') {
          capturedBody = Map<String, dynamic>.from(options.data as Map);
          return _jsonResponse(
            options,
            200,
            {
              'code': 'OK',
              'message': 'success',
              'data': {
                'id': 11,
                'title': 'Weekend Walk',
                'photos': const [],
              },
            },
          );
        }

        throw StateError(
          'Unexpected request: ${options.method} ${options.uri}',
        );
      });

      final apiService = ApiService.test(dio: dio);

      await apiService.createAlbum(
        title: 'Weekend Walk',
        description: 'Along the river',
        photos: const [
          AlbumPhotoDraft(
            url: 'https://example.com/photo.jpg',
            description: 'Cover shot',
            source: AlbumPhotoSource.camera,
          ),
        ],
        isShared: true,
      );

      expect(capturedBody['title'], 'Weekend Walk');
      expect(capturedBody['description'], 'Along the river');
      expect(capturedBody['visibility'], 'public');
      expect(capturedBody['photos'], [
        {
          'url': 'https://example.com/photo.jpg',
          'description': 'Cover shot',
          'source': 'camera',
        },
      ]);
    });
  });

  group('Auth refresh flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('retries unauthorized requests after refreshing access token',
        () async {
      var groupRequests = 0;
      var refreshRequests = 0;
      final dio = Dio(
        BaseOptions(baseUrl: 'http://localhost:8080/api'),
      );
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) {
        final requestPath = options.uri.path;

        if (requestPath.endsWith('/auth/refresh')) {
          refreshRequests += 1;
          return _jsonResponse(
            options,
            200,
            {
              'access_token': 'fresh-access',
              'refresh_token': 'refresh-456',
            },
          );
        }

        if (requestPath.endsWith('/groups/current')) {
          groupRequests += 1;

          if (groupRequests == 1) {
            return _jsonResponse(
              options,
              401,
              {'message': 'expired'},
            );
          }

          if (groupRequests == 2) {
            return _jsonResponse(
              options,
              200,
              {
                'code': 'OK',
                'message': 'success',
                'data': {
                  'id': 1,
                  'name': 'Warm Home',
                  'invite_code': 'ABCD',
                  'members': const [],
                },
              },
            );
          }

          throw StateError(
            'Unexpected /groups/current call count: $groupRequests',
          );
        }

        throw StateError(
            'Unexpected request: ${options.method} ${options.uri}');
      });
      final apiService = ApiService.test(dio: dio)
        ..setAccessToken('expired-access')
        ..setRefreshToken('refresh-123')
        ..setUserId('7');

      final group = await apiService.getGroup();

      expect(group.name, 'Warm Home');
      expect(groupRequests, 2);
      expect(refreshRequests, 1);
    });

    test('persists refreshed tokens through AuthService callbacks', () async {
      SharedPreferences.setMockInitialValues({
        'auth.user': '{"id":7,"nickname":"WarmUser"}',
        'auth.access_token': 'expired-access',
        'auth.refresh_token': 'refresh-123',
      });

      var groupRequests = 0;
      var refreshRequests = 0;

      final dio = Dio(
        BaseOptions(baseUrl: 'http://localhost:8080/api'),
      );
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) {
        final requestPath = options.uri.path;

        if (requestPath.endsWith('/auth/refresh')) {
          refreshRequests += 1;
          return _jsonResponse(
            options,
            200,
            {
              'access_token': 'fresh-access',
              'refresh_token': 'refresh-456',
            },
          );
        }

        if (requestPath.endsWith('/groups/current')) {
          groupRequests += 1;

          if (groupRequests == 1) {
            return _jsonResponse(
              options,
              401,
              {'message': 'expired'},
            );
          }

          if (groupRequests == 2) {
            return _jsonResponse(
              options,
              200,
              {
                'code': 'OK',
                'message': 'success',
                'data': {
                  'id': 1,
                  'name': 'Warm Home',
                  'invite_code': 'ABCD',
                  'members': const [],
                },
              },
            );
          }

          throw StateError(
            'Unexpected /groups/current call count: $groupRequests',
          );
        }

        throw StateError(
            'Unexpected request: ${options.method} ${options.uri}');
      });
      final apiService = ApiService.test(dio: dio);

      final authService = AuthService(apiService: apiService);
      await _waitForSessionRestore(authService);

      await apiService.getGroup();

      final preferences = await SharedPreferences.getInstance();
      expect(authService.isAuthenticated, isTrue);
      expect(groupRequests, 2);
      expect(refreshRequests, 1);
      expect(preferences.getString('auth.access_token'), 'fresh-access');
      expect(preferences.getString('auth.refresh_token'), 'refresh-456');
    });
  });
}

Future<void> _waitForSessionRestore(AuthService authService) async {
  while (authService.isRestoringSession) {
    await Future<void>.delayed(Duration.zero);
  }
}

ResponseBody _jsonResponse(
  RequestOptions options,
  int statusCode,
  Map<String, dynamic> payload,
) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
    statusMessage: statusCode == 200 ? 'OK' : 'Unauthorized',
  );
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
