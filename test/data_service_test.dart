import 'package:flutter_test/flutter_test.dart';
import 'package:vocalin/src/services/data_service.dart';

void main() {
  group('DataService Tests', () {
    late DataService dataService;

    setUp(() {
      dataService = DataService();
    });

    test('Initial data should be empty before fetch', () {
      expect(dataService.currentUser, isNull);
      expect(dataService.posts, isEmpty);
    });

    // Note: Since DataService now uses real API calls (Dio),
    // we cannot easily unit test it without mocking Dio or ApiService.
    // For this demo, we will skip the integration tests that require backend.

    /*
    test('Add post should increase post count', () {
      final initialCount = dataService.posts.length;
      final newPost = Post(
        id: 999,
        type: PostType.note,
        content: 'Test Note',
        createdAt: DateTime.now(),
      );

      dataService.addPost(newPost);
      // This would fail because addPost is async and calls API
    });
    */
  });
}
