import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_media/welcome_montage.dart';

void main() {
  testWidgets('empty montage slot proceeds directly to its outro', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeMontageScreen(
          videoUrl: null,
          onExplore: (_) {},
          onLookAround: () {},
        ),
      ),
    );

    expect(find.text('Play welcome montage'), findsOneWidget);
    await tester.tap(find.text('Play welcome montage'));
    await tester.pumpAndSettle();

    expect(find.text('So / Aye . . . What now , wanderer ?'), findsOneWidget);
    expect(find.text('Explore the Feed'), findsOneWidget);
    expect(find.text('Open the Boards'), findsOneWidget);
    expect(find.text('Visit Community Spaces'), findsOneWidget);
    expect(find.text('Just look around'), findsOneWidget);
  });

  testWidgets('outro choices route and can return to the feed', (tester) async {
    WelcomeDestination? destination;
    var lookedAround = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeMontageScreen(
          videoUrl: null,
          onExplore: (value) => destination = value,
          onLookAround: () => lookedAround = true,
        ),
      ),
    );
    await tester.tap(find.text('Play welcome montage'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open the Boards'));
    expect(destination, WelcomeDestination.boards);

    await tester.tap(find.text('Just look around'));
    expect(lookedAround, isTrue);
  });
}
