import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_media/social_experience.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SocialStory', () {
    test('expires exactly 24 hours after creation', () {
      final createdAt = DateTime.utc(2026, 11, 11);
      final story = SocialStory(
        id: 'story-1',
        author: '@alex',
        text: 'Hello',
        createdAt: createdAt,
        audience: StoryAudience.closeFriends,
      );

      expect(story.expiresAt, createdAt.add(const Duration(hours: 24)));
      expect(
        story.isExpiredAt(createdAt.add(const Duration(hours: 23))),
        isFalse,
      );
      expect(story.isExpiredAt(story.expiresAt), isTrue);
      expect(
        SocialStory.fromJson(story.toJson()).audience,
        StoryAudience.closeFriends,
      );
    });

    test(
      'loading stories removes expired items and keeps active items',
      () async {
        final now = DateTime.utc(2026, 11, 11);
        final oldStory = SocialStory(
          id: 'old',
          author: '@alex',
          text: 'Old story',
          createdAt: now.subtract(const Duration(hours: 25)),
          audience: StoryAudience.friends,
        );
        final currentStory = SocialStory(
          id: 'current',
          author: '@alex',
          text: 'Current story',
          createdAt: now,
          audience: StoryAudience.everyone,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          SocialExperienceStore.storiesKey,
          jsonEncode([oldStory.toJson(), currentStory.toJson()]),
        );

        final loaded = await SocialExperienceStore.loadStories(now: now);
        final persisted = jsonDecode(
          prefs.getString(SocialExperienceStore.storiesKey)!,
        ) as List;

        expect(loaded.map((story) => story.id), ['current']);
        expect(persisted, hasLength(1));
      },
    );
  });

  test('social preferences persist selected interests and feed mode', () async {
    const preferences = SocialPreferences(
      personalizedFeed: true,
      interests: ['Design', 'Hacks'],
    );

    await SocialExperienceStore.savePreferences(preferences);

    final restored = await SocialExperienceStore.loadPreferences();
    expect(restored.personalizedFeed, isTrue);
    expect(restored.interests, ['Design', 'Hacks']);
  });

  test('For You ranks matching interests above unrelated posts', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final techPost = {
      'id': 'tech',
      'category': 'Tech',
      'timestamp': now,
      'likeCount': 0,
    };
    final designPost = {
      'id': 'design',
      'category': 'Design',
      'timestamp': now,
      'likeCount': 0,
    };

    final ranked = rankPostsForYou([designPost, techPost], ['Tech']);

    expect(ranked.first['id'], 'tech');
    expect(ranked.last['id'], 'design');
  });
}
