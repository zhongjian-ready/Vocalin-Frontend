import 'package:flutter_test/flutter_test.dart';
import 'package:vocalin/src/models/group.dart';
import 'package:vocalin/src/models/post.dart';
import 'package:vocalin/src/models/space_inbox_item.dart';

void main() {
  group('Model time parsing', () {
    test('Post note timestamps preserve backend wall time', () {
      const createdAtValue = '2026-05-08T14:00:07.811+08:00';
      const updatedAtValue = '2026-05-08T14:38:46.064+08:00';

      final post = Post.fromNoteJson({
        'ID': 3,
        'content': 'test',
        'CreatedAt': createdAtValue,
        'UpdatedAt': updatedAtValue,
      });

      expect(post.createdAt, DateTime(2026, 5, 8, 14, 0, 7, 811));
      expect(post.updatedAt, DateTime(2026, 5, 8, 14, 38, 46, 64));
    });

    test('Rich note payload parses title and plain-text summary', () {
      final post = Post.fromNoteJson({
        'ID': 11,
        'content': encodeRichNoteContent(
          title: 'Weekend Plan',
          body: '# Big Day\n**Brunch** with _Alex_\n- Buy flowers',
          summary: 'Big Day\nBrunch with Alex\nBuy flowers',
          groupId: 9,
        ),
      });

      expect(post.title, 'Weekend Plan');
      expect(post.formattedContent,
          '# Big Day\n**Brunch** with _Alex_\n- Buy flowers');
      expect(post.content, 'Big Day\nBrunch with Alex\nBuy flowers');
      expect(post.groupId, 9);
    });

    test('Plain note payload remains backward compatible', () {
      final post = Post.fromNoteJson({
        'ID': 12,
        'content': 'Remember to water the plants',
      });

      expect(post.title, isNull);
      expect(post.formattedContent, isNull);
      expect(post.content, 'Remember to water the plants');
    });

    test('Post note owner fields parse from nested user payload', () {
      final post = Post.fromNoteJson({
        'ID': 13,
        'content': 'Shared dinner list',
        'is_shared': true,
        'user': {
          'nickname': 'Alex',
          'avatar_url': 'https://example.com/alex.jpg',
        },
      });

      expect(post.ownerNickname, 'Alex');
      expect(post.ownerAvatarUrl, 'https://example.com/alex.jpg');
      expect(post.isShared, isTrue);
    });

    test('Post photo owner fields parse from nested user payload', () {
      final post = Post.fromPhotoJson({
        'ID': 8,
        'url': 'https://example.com/photo.jpg',
        'description': 'Stone carving',
        'CreatedAt': '2026-05-08T14:00:07.811+08:00',
        'UpdatedAt': '2026-05-08T14:38:46.064+08:00',
        'user': {
          'nickname': 'Steel Pipe',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      });

      expect(post.ownerNickname, 'Steel Pipe');
      expect(post.ownerAvatarUrl, 'https://example.com/avatar.jpg');
      expect(post.updatedAt, DateTime(2026, 5, 8, 14, 38, 46, 64));
    });

    test('Space inbox timestamps preserve backend wall time', () {
      const createdAtValue = '2026-05-08T14:38:46.064+08:00';

      final item = SpaceInboxItem.fromJson({
        'id': 31,
        'type': 'join_request',
        'group_id': 5,
        'group_name': 'Warm Home',
        'status': 'pending',
        'created_at': createdAtValue,
      });

      expect(item.createdAt, DateTime(2026, 5, 8, 14, 38, 46, 64));
    });

    test('Group timer start date preserves backend wall time', () {
      const timerStartValue = '2026-05-08T14:38:46.064+08:00';

      final group = Group.fromJson({
        'ID': 5,
        'name': 'Warm Home',
        'invite_code': 'ABCD12',
        'members': const [],
        'timer_start_date': timerStartValue,
      });

      expect(
        group.timerStartDate,
        DateTime(2026, 5, 8, 14, 38, 46, 64),
      );
    });
  });
}
