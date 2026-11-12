import 'package:flutter_test/flutter_test.dart';
import 'package:social_media/escape_dimensions.dart';

void main() {
  test('local rooms round-trip without a Quexdc profile identity', () {
    final room = EscapeRoom(
      id: 'local-1',
      name: 'Builder Underground',
      vibe: 'lofi',
      codename: 'Night Owl',
      entryCode: 'ABCD2345',
      posts: [
        EscapePost(
          id: 'post-1',
          codename: 'Night Owl',
          message: 'What are you building?',
          createdAt: DateTime.utc(2026, 11, 11),
        ),
      ],
    );

    final restored = EscapeRoom.fromJson(room.toJson());

    expect(restored.isShared, isFalse);
    expect(restored.entryCode, 'ABCD2345');
    expect(restored.codename, 'Night Owl');
    expect(restored.posts.single.message, 'What are you building?');
  });

  test('shared membership token is separate from local room invite code', () {
    final room = EscapeRoom.fromJson({
      'id': 'shared-1',
      'name': 'Late Night Lounge',
      'vibe': 'cyber',
      'codename': 'Blue Comet',
      'posts': [],
      'membershipToken': 'opaque-room-membership-token',
    });

    expect(room.isShared, isTrue);
    expect(room.entryCode, isNull);
    expect(room.membershipToken, 'opaque-room-membership-token');
  });
}
