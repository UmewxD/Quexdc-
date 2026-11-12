import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_media/easter_shop.dart';
import 'package:social_media/marketplace_hub.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('curated creator themes include the requested aesthetics', () {
    expect(
      aestheticPacks.map((pack) => pack.name),
      containsAll(['Frutiger Aero', 'Weirdcore', 'Mysticule']),
    );
    expect(
      aestheticPacks
          .where((pack) => pack.category == 'Creator gift')
          .every((pack) => pack.cost == 0),
      isTrue,
    );
  });

  testWidgets('a free creator theme applies without spending points', (
    tester,
  ) async {
    final store = EasterEconomyStore();
    Color? applied;
    await tester.pumpWidget(
      MaterialApp(
        home: AestheticMarketplaceScreen(
          store: store,
          onApplyAccent: (color) => applied = color,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply').first);
    await tester.pumpAndSettle();

    expect(applied, const Color(0xFF00A8B5));
    expect((await store.load()).points, 0);
    expect(tester.takeException(), isNull);
  });

  test(
    'seasonal theme unlock persists through the existing points store',
    () async {
      final store = EasterEconomyStore();
      await store.completeQuest('theme-test-points', points: 50);
      final theme = aestheticPacks.firstWhere(
        (pack) => pack.id == 'sakura_spring',
      );
      final snapshot = await store.purchase(
        itemId: 'aesthetic_${theme.id}',
        cost: theme.cost,
      );

      expect(snapshot.points, 10);
      expect(snapshot.ownedItemIds, contains('aesthetic_sakura_spring'));
    },
  );

  testWidgets('marketplace exposes the aesthetic catalog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceHubScreen(
          onApplyFont: (_) async {},
          onOpenEasterShop: () {},
          onApplyAccent: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Themes'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Mysticule'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Mysticule'), findsOneWidget);
  });
}
