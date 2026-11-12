import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_media/visual_boards.dart';

void main() {
  group('PhotoBoard', () {
    test('round-trips a board and its photo metadata', () {
      final board = PhotoBoard(
        id: 'board-1',
        name: 'Studio ideas',
        photos: [
          BoardPhoto(
            id: 'photo-1',
            imagePath: 'data:image/jpeg;base64,ZmFrZQ==',
            createdAt: DateTime.utc(2026, 11, 10),
            caption: 'Warm lighting',
          ),
        ],
      );

      final restored = PhotoBoard.fromJson(board.toJson());

      expect(restored.id, board.id);
      expect(restored.name, board.name);
      expect(restored.photos, hasLength(1));
      expect(restored.photos.single.id, board.photos.single.id);
      expect(restored.photos.single.imagePath, board.photos.single.imagePath);
      expect(restored.photos.single.caption, board.photos.single.caption);
      expect(restored.photos.single.createdAt, board.photos.single.createdAt);
    });

    test('rejects malformed photo collections', () {
      expect(
        () => PhotoBoard.fromJson({'id': 'board-1', 'name': 'Ideas'}),
        throwsFormatException,
      );
    });
  });

  test('renders original artwork as a PNG image', () async {
    final png = await renderArtworkPng(ArtworkStyle.presets.first, 42);

    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(png.length, greaterThan(1000));
  });

  testWidgets('creates a photo board from the empty state', (tester) async {
    var savedBoards = <PhotoBoard>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => VisualBoardsScreen(
            boards: savedBoards,
            onBoardsChanged: (boards) async {
              setState(() => savedBoards = boards);
            },
            onFindEasterEgg: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Create your first board'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Studio ideas');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(savedBoards, hasLength(1));
    expect(savedBoards.single.name, 'Studio ideas');
    expect(find.text('Studio ideas'), findsOneWidget);

    await tester.tap(find.text('Make free original art'));
    await tester.pumpAndSettle();
    expect(find.text('Make original art'), findsOneWidget);
    expect(find.text('Nebula'), findsOneWidget);
    expect(find.text('Lime Pop'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
