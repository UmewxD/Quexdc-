import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_media/innovation_workspace.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('innovation ideas persist as creator self-reported notes', () async {
    final idea = InnovationIdea(
      id: 'idea-1',
      title: 'Water-saving garden',
      summary: 'A prototype concept',
      stage: InnovationStage.preparing,
      fundingChoice: InnovationFundingChoice.optionalDonation,
      donationPercent: 5,
      createdAt: DateTime(2026, 11, 11),
    );

    await InnovationWorkspaceStore.save([idea]);
    final restored = await InnovationWorkspaceStore.load();

    expect(restored.single.title, idea.title);
    expect(restored.single.stage, InnovationStage.preparing);
    expect(restored.single.donationPercent, 5);
  });

  testWidgets('workspace makes privacy and service limits explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: InnovationWorkspaceScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inventor workspace'), findsOneWidget);
    expect(find.textContaining('not encrypted'), findsOneWidget);
    expect(find.textContaining('does not file'), findsOneWidget);
    expect(find.textContaining('not connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creator must acknowledge local storage before saving an idea', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: InnovationWorkspaceScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New idea note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'My concept');
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(find.text('New invention / idea note'), findsOneWidget);

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();

    expect(find.text('My concept'), findsOneWidget);
    expect(await InnovationWorkspaceStore.load(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
