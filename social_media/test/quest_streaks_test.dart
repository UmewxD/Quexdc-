import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_media/easter_shop.dart';
import 'package:social_media/quest_streaks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'daily streak counts once per day and advances on consecutive days',
    () async {
      final firstDay = DateTime(2026, 11, 1, 10);
      final first = await QuestStreakStore.recordActivity(
        QuestStreakStore.appKey,
        now: firstDay,
      );
      final repeated = await QuestStreakStore.recordActivity(
        QuestStreakStore.appKey,
        now: firstDay.add(const Duration(hours: 4)),
      );
      final nextDay = await QuestStreakStore.recordActivity(
        QuestStreakStore.appKey,
        now: DateTime(2026, 11, 2, 9),
      );

      expect(first.current, 1);
      expect(repeated.current, 1);
      expect(nextDay.current, 2);
      expect(nextDay.best, 2);
    },
  );

  test('a broken streak can be repaired once with earned points', () async {
    final economy = EasterEconomyStore();
    await economy.completeQuest('seed-points', points: 100);
    await QuestStreakStore.recordActivity(
      QuestStreakStore.appKey,
      now: DateTime(2026, 11, 1, 9),
    );
    await QuestStreakStore.recordActivity(
      QuestStreakStore.appKey,
      now: DateTime(2026, 11, 2, 9),
    );
    final broken = await QuestStreakStore.recordActivity(
      QuestStreakStore.appKey,
      now: DateTime(2026, 11, 4, 9),
    );
    expect(broken.canRecover(DateTime(2026, 11, 4, 10)), isTrue);

    final repaired = await QuestStreakStore.recoverWithPoints(
      QuestStreakStore.appKey,
      cost: 50,
      economy: economy,
      now: DateTime(2026, 11, 4, 10),
    );

    expect(repaired.current, 4);
    expect(repaired.best, 4);
    expect(repaired.canRecover(DateTime(2026, 11, 4, 10)), isFalse);
    expect((await economy.load()).points, 50);
    expect((await economy.load()).spentActionIds, hasLength(1));
  });

  test('streak repair fails after 48 hours without spending points', () async {
    final economy = EasterEconomyStore();
    await economy.completeQuest('seed-points', points: 100);
    await QuestStreakStore.recordActivity(
      QuestStreakStore.questKey,
      now: DateTime(2026, 11, 1),
    );
    await QuestStreakStore.recordActivity(
      QuestStreakStore.questKey,
      now: DateTime(2026, 11, 3),
    );

    await expectLater(
      QuestStreakStore.recoverWithPoints(
        QuestStreakStore.questKey,
        cost: 50,
        economy: economy,
        now: DateTime(2026, 11, 6),
      ),
      throwsA(isA<StateError>()),
    );
    expect((await economy.load()).points, 100);
  });

  test('point spending is idempotent for a retried action', () async {
    final economy = EasterEconomyStore();
    await economy.completeQuest('seed-points', points: 80);

    await economy.spendPointsOnce(actionId: 'repair-1', cost: 50);
    final retried = await economy.spendPointsOnce(
      actionId: 'repair-1',
      cost: 50,
    );

    expect(retried.points, 30);
    expect(retried.spentActionIds, contains('repair-1'));
  });

  testWidgets(
    'sponsor quest demo is explicit about no partnership or rewards',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SponsorQuestDemoCard()));
      await tester.pumpAndSettle();

      expect(find.textContaining('not affiliated'), findsOneWidget);
      expect(
        find.textContaining('no reward or payment is issued'),
        findsOneWidget,
      );
      expect(find.text('Choose photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
