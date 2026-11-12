import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_media/beta_ideas_settings.dart';

void main() {
  testWidgets(
    'beta ideas page describes concepts without implying they are live',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: BetaIdeasSettingsScreen()),
      );

      expect(find.text('Ideas & beta'), findsOneWidget);
      expect(find.textContaining('not a finished MVP'), findsOneWidget);
      expect(
        find.text('Inventors, innovators & collaboration'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Community care & second chances'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Community care & second chances'), findsOneWidget);
      expect(find.textContaining('ban anyone'), findsOneWidget);
      expect(find.textContaining('self-reflection quizzes'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Quexdc direction'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Quexdc direction'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
