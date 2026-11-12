import 'package:flutter_test/flutter_test.dart';
import 'package:social_media/status_mood_manager.dart';

void main() {
  group('MoodStatus', () {
    test('round-trips an expiring status', () {
      final status = MoodStatus(
        emoji: '🌙',
        text: 'Late night coding',
        updatedAt: DateTime.utc(2026, 11, 9),
        expiresAt: DateTime.utc(2026, 11, 10),
        anonymousVaultOnly: true,
      );

      final restored = MoodStatus.fromJson(status.toJson());

      expect(restored.emoji, status.emoji);
      expect(restored.text, status.text);
      expect(restored.updatedAt, status.updatedAt);
      expect(restored.expiresAt, status.expiresAt);
      expect(restored.anonymousVaultOnly, isTrue);
    });

    test('an until-changed status has no expiry', () {
      final status = MoodStatus(
        emoji: '⚡',
        text: 'Building Quexdc',
        updatedAt: DateTime.now(),
        expiresAt: null,
        anonymousVaultOnly: false,
      );

      expect(status.isExpired, isFalse);
      expect(MoodStatus.fromJson(status.toJson()).expiresAt, isNull);
    });
  });
}
