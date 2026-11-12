import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_media/easter_shop.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('quest rewards persist and cannot be claimed repeatedly', () async {
    final store = EasterEconomyStore();

    final first = await store.completeQuest('first-build', points: 15);
    final repeated = await store.completeQuest('first-build', points: 15);
    final restored = await EasterEconomyStore().load();

    expect(first.points, 15);
    expect(repeated.points, 15);
    expect(restored.points, 15);
    expect(restored.hasProgress, isTrue);
    expect(restored.completedQuestIds, contains('first-build'));
  });

  test('new installs start with no saved Easter economy state', () async {
    final snapshot = await EasterEconomyStore().load();

    expect(snapshot.points, 0);
    expect(snapshot.hasProgress, isFalse);
    expect(snapshot.ownedItemIds, isEmpty);
  });

  test('unchecking a quest does not let its points be farmed again', () async {
    final store = EasterEconomyStore();

    await store.completeQuest('first-build', points: 15);
    await store.uncompleteQuest('first-build');
    final completedAgain = await store.completeQuest('first-build', points: 15);

    expect(completedAgain.points, 15);
    expect(completedAgain.completedQuestIds, contains('first-build'));
  });

  test('egg rewards persist and each egg can only be claimed once', () async {
    final store = EasterEconomyStore();
    final first = await store.claimEgg(eggId: 'egg-one', points: 2);
    final restored = await EasterEconomyStore().load();

    expect(first.points, 2);
    expect(restored.discoveredEggIds, contains('egg-one'));
    await expectLater(
      store.claimEgg(eggId: 'egg-one', points: 10),
      throwsA(isA<StateError>()),
    );
    expect((await store.load()).points, 2);
  });

  test('video egg slots are placed in boards, companions, and regions', () {
    expect(
      easterEggs.map((egg) => egg.placement),
      containsAll(EasterEggPlacement.values),
    );
    expect(easterEggs.every((egg) => egg.skipPoints < egg.watchPoints), isTrue);
  });

  test('shop purchase spends points once and persists ownership', () async {
    final store = EasterEconomyStore();
    await store.completeQuest('first-build', points: 40);

    final purchased = await store.purchase(itemId: 'nebula', cost: 30);
    final restored = await EasterEconomyStore().load();

    expect(purchased.points, 10);
    expect(purchased.ownedItemIds, contains('nebula'));
    expect(restored.points, 10);
    expect(restored.ownedItemIds, contains('nebula'));
  });

  test('rejects unaffordable and duplicate shop purchases', () async {
    final store = EasterEconomyStore();

    await expectLater(
      store.purchase(itemId: 'nebula', cost: 30),
      throwsA(isA<StateError>()),
    );
    await store.completeQuest('first-build', points: 40);
    await store.purchase(itemId: 'nebula', cost: 30);
    await expectLater(
      store.purchase(itemId: 'nebula', cost: 30),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('buying a theme spends points and applies it', (tester) async {
    final store = EasterEconomyStore();
    await store.completeQuest('first-build', points: 40);
    Color? appliedColor;

    await tester.pumpWidget(
      MaterialApp(
        home: EasterShopScreen(
          store: store,
          onItemApplied: (item) async {
            appliedColor = item.color;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nebula Glow'));
    await tester.pumpAndSettle();

    expect(appliedColor, const Color(0xFF8A65F2));
    expect((await store.load()).points, 10);
    expect((await store.load()).ownedItemIds, contains('easter_theme_nebula'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unconfigured video slot does not grant points before video exists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EasterEggHuntScreen(
            store: EasterEconomyStore(),
            placement: EasterEggPlacement.boards,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Video slot ready'), findsOneWidget);
      expect(find.textContaining('Skip'), findsNothing);
      expect((await EasterEconomyStore().load()).points, 0);
    },
  );

  testWidgets('Easter Shop opens a beginner list with all starter clues', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EasterShopScreen(
          store: EasterEconomyStore(),
          onItemApplied: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beginner’s Video List'));
    await tester.pumpAndSettle();

    expect(find.text('Beginner’s Video List'), findsOneWidget);
    expect(find.text('The Pin That Plays'), findsOneWidget);
    expect(find.text('Companion Side Quest'), findsOneWidget);
    expect(find.text('A Signal Between Regions'), findsOneWidget);
    expect(find.text('Look in Inspiration Boards'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
