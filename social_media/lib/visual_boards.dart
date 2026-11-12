import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class BoardPhoto {
  const BoardPhoto({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    this.caption = '',
  });

  final String id;
  final String imagePath;
  final DateTime createdAt;
  final String caption;

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'caption': caption,
  };

  factory BoardPhoto.fromJson(Map<String, dynamic> json) => BoardPhoto(
    id: json['id'] as String,
    imagePath: json['imagePath'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    caption: json['caption'] as String? ?? '',
  );
}

class PhotoBoard {
  const PhotoBoard({
    required this.id,
    required this.name,
    required this.photos,
  });

  final String id;
  final String name;
  final List<BoardPhoto> photos;

  PhotoBoard copyWith({String? name, List<BoardPhoto>? photos}) => PhotoBoard(
    id: id,
    name: name ?? this.name,
    photos: photos ?? this.photos,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'photos': photos.map((photo) => photo.toJson()).toList(),
  };

  factory PhotoBoard.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'];
    if (rawPhotos is! List) {
      throw const FormatException('A photo board must contain a photos list.');
    }
    return PhotoBoard(
      id: json['id'] as String,
      name: json['name'] as String,
      photos: rawPhotos
          .map(
            (photo) =>
                BoardPhoto.fromJson(Map<String, dynamic>.from(photo as Map)),
          )
          .toList(),
    );
  }
}

class ArtworkStyle {
  const ArtworkStyle(this.name, this.colors);

  final String name;
  final List<Color> colors;

  static const presets = [
    ArtworkStyle('Nebula', [
      Color(0xFF100B3A),
      Color(0xFF6838C7),
      Color(0xFFEE4FA8),
      Color(0xFF53E5E0),
    ]),
    ArtworkStyle('Sunset', [
      Color(0xFF38104E),
      Color(0xFFCE347D),
      Color(0xFFFF8A55),
      Color(0xFFFFD56B),
    ]),
    ArtworkStyle('Deep Sea', [
      Color(0xFF061C3D),
      Color(0xFF087E9B),
      Color(0xFF36D6B2),
      Color(0xFFB5F5E5),
    ]),
    ArtworkStyle('Electric', [
      Color(0xFF14122E),
      Color(0xFF5146FF),
      Color(0xFFBD48FF),
      Color(0xFFFF5F8F),
    ]),
    ArtworkStyle('Lime Pop', [
      Color(0xFF10251E),
      Color(0xFF247A53),
      Color(0xFFB8F34A),
      Color(0xFFFFE76A),
    ]),
  ];
}

class GenerativeArtworkPainter extends CustomPainter {
  const GenerativeArtworkPainter({required this.style, required this.seed});

  final ArtworkStyle style;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final colors = style.colors;
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.first, colors[1], colors.first],
        stops: const [0, 0.58, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, background);

    final random = math.Random(seed);
    for (var index = 0; index < 7; index++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = size.shortestSide * (0.12 + random.nextDouble() * 0.3);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[2 + random.nextInt(2)].withValues(alpha: 0.7),
            colors[2 + random.nextInt(2)].withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, glow);
    }

    final orbitPaint = Paint()
      ..color = colors.last.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.004;
    final center = Offset(size.width * 0.52, size.height * 0.5);
    for (var index = 0; index < 6; index++) {
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * (0.38 + index * 0.16),
        height: size.height * (0.2 + index * 0.15),
      );
      canvas.drawOval(rect, orbitPaint);
    }

    final starPaint = Paint()..color = colors.last.withValues(alpha: 0.78);
    for (var index = 0; index < 64; index++) {
      final radius = size.shortestSide * (0.001 + random.nextDouble() * 0.004);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        radius,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(GenerativeArtworkPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.seed != seed;
}

Future<Uint8List> renderArtworkPng(ArtworkStyle style, int seed) async {
  const width = 480;
  const height = 600;
  final recorder = ui.PictureRecorder();
  const size = Size(480, 600);
  GenerativeArtworkPainter(
    style: style,
    seed: seed,
  ).paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const FormatException('Artwork could not be encoded.');
    }
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class VisualBoardsScreen extends StatefulWidget {
  const VisualBoardsScreen({
    super.key,
    required this.boards,
    required this.onBoardsChanged,
    required this.onFindEasterEgg,
  });

  final List<PhotoBoard> boards;
  final Future<void> Function(List<PhotoBoard>) onBoardsChanged;
  final VoidCallback onFindEasterEgg;

  @override
  State<VisualBoardsScreen> createState() => _VisualBoardsScreenState();
}

class _VisualBoardsScreenState extends State<VisualBoardsScreen> {
  String? _selectedBoardId;
  bool _isAddingPhoto = false;

  PhotoBoard? get _selectedBoard {
    for (final board in widget.boards) {
      if (board.id == _selectedBoardId) return board;
    }
    return null;
  }

  Future<bool> _saveBoards(List<PhotoBoard> boards) async {
    try {
      await widget.onBoardsChanged(boards);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save your boards: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _createBoard() async {
    var boardName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a board'),
        content: TextField(
          autofocus: true,
          maxLength: 40,
          onChanged: (value) => boardName = value,
          decoration: const InputDecoration(
            labelText: 'Board name',
            hintText: 'e.g. Cozy studio ideas',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, boardName.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !mounted) return;
    final board = PhotoBoard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmedName,
      photos: const [],
    );
    if (await _saveBoards([...widget.boards, board]) && mounted) {
      setState(() => _selectedBoardId = board.id);
    }
  }

  Future<void> _addPhoto(PhotoBoard board) async {
    if (_isAddingPhoto) return;
    setState(() => _isAddingPhoto = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (image == null || !mounted) return;

      var imagePath = image.path;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 1572864) {
          throw const FormatException(
            'For browser storage, choose an optimized image under 1.5 MB.',
          );
        }
        final mimeType = image.mimeType ?? 'image/jpeg';
        imagePath = 'data:$mimeType;base64,${base64Encode(bytes)}';
      }

      final caption = await _askForCaption();
      if (caption == null || !mounted) return;
      if (!kIsWeb) {
        final documents = await getApplicationDocumentsDirectory();
        final boardPhotos = Directory(
          '${documents.path}${Platform.pathSeparator}inspiration_boards',
        );
        await boardPhotos.create(recursive: true);
        final extension = _safeImageExtension(image.name);
        final storedFile = File(
          '${boardPhotos.path}${Platform.pathSeparator}'
          'board_${board.id}_${DateTime.now().microsecondsSinceEpoch}.$extension',
        );
        await File(image.path).copy(storedFile.path);
        imagePath = storedFile.path;
      }

      final photo = BoardPhoto(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imagePath: imagePath,
        createdAt: DateTime.now(),
        caption: caption,
      );
      final updated = widget.boards
          .map(
            (existing) => existing.id == board.id
                ? existing.copyWith(photos: [...existing.photos, photo])
                : existing,
          )
          .toList();
      if (await _saveBoards(updated)) {
        await _deleteStoredPhoto(photo.imagePath);
      } else {
        await _deleteStoredPhoto(imagePath);
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add that photo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingPhoto = false);
    }
  }

  Future<void> _createArtwork(PhotoBoard board) async {
    if (_isAddingPhoto) return;
    var selectedStyle = ArtworkStyle.presets.first;
    var seed = math.Random().nextInt(1 << 31);
    final result = await showDialog<(ArtworkStyle, int)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Make original art'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 184,
                  height: 230,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: GenerativeArtworkPainter(
                        style: selectedStyle,
                        seed: seed,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final style in ArtworkStyle.presets)
                      ChoiceChip(
                        label: Text(style.name),
                        selected: selectedStyle == style,
                        onSelected: (_) =>
                            setDialogState(() => selectedStyle = style),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  setDialogState(() => seed = math.Random().nextInt(1 << 31)),
              child: const Text('Remix'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (selectedStyle, seed)),
              child: const Text('Save to board'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _isAddingPhoto = true);
    String? storedPath;
    try {
      final bytes = await renderArtworkPng(result.$1, result.$2);
      if (kIsWeb) {
        storedPath = 'data:image/png;base64,${base64Encode(bytes)}';
      } else {
        final documents = await getApplicationDocumentsDirectory();
        final boardPhotos = Directory(
          '${documents.path}${Platform.pathSeparator}inspiration_boards',
        );
        await boardPhotos.create(recursive: true);
        final file = File(
          '${boardPhotos.path}${Platform.pathSeparator}'
          'art_${DateTime.now().microsecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(bytes, flush: true);
        storedPath = file.path;
      }

      final photo = BoardPhoto(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imagePath: storedPath,
        createdAt: DateTime.now(),
        caption: 'Original ${result.$1.name} art',
      );
      final updated = widget.boards
          .map(
            (existing) => existing.id == board.id
                ? existing.copyWith(photos: [...existing.photos, photo])
                : existing,
          )
          .toList();
      if (await _saveBoards(updated)) storedPath = null;
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save your artwork: $error')),
        );
      }
    } finally {
      if (storedPath != null) await _deleteStoredPhoto(storedPath);
      if (mounted) setState(() => _isAddingPhoto = false);
    }
  }

  Future<String?> _askForCaption() async {
    var captionText = '';
    final caption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a note (optional)'),
        content: TextField(
          autofocus: true,
          maxLength: 120,
          onChanged: (value) => captionText = value,
          decoration: const InputDecoration(hintText: 'Why did you save this?'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, captionText.trim()),
            child: const Text('Save photo'),
          ),
        ],
      ),
    );
    return caption;
  }

  Future<void> _deletePhoto(PhotoBoard board, BoardPhoto photo) async {
    final updated = widget.boards
        .map(
          (existing) => existing.id == board.id
              ? existing.copyWith(
                  photos: existing.photos
                      .where((item) => item.id != photo.id)
                      .toList(),
                )
              : existing,
        )
        .toList();
    if (await _saveBoards(updated)) {
      await _deleteStoredPhoto(photo.imagePath);
    }
  }

  Future<void> _deleteBoard(PhotoBoard board) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this board?'),
        content: Text('“${board.name}” and its saved photos will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final saved = await _saveBoards(
      widget.boards.where((item) => item.id != board.id).toList(),
    );
    if (saved) {
      for (final photo in board.photos) {
        await _deleteStoredPhoto(photo.imagePath);
      }
    }
    if (saved && mounted) setState(() => _selectedBoardId = null);
  }

  String _safeImageExtension(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return const {
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'heic',
        }.contains(extension)
        ? extension
        : 'jpg';
  }

  Future<void> _deleteStoredPhoto(String imagePath) async {
    if (kIsWeb || imagePath.startsWith('data:image/')) return;
    try {
      final documents = await getApplicationDocumentsDirectory();
      final boardPhotos = Directory(
        '${documents.path}${Platform.pathSeparator}inspiration_boards',
      );
      final file = File(imagePath);
      if (file.parent.absolute.path == boardPhotos.absolute.path &&
          await file.exists()) {
        await file.delete();
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove the stored photo: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _selectedBoard;
    return Scaffold(
      appBar: AppBar(
        leading: board == null
            ? null
            : IconButton(
                tooltip: 'All boards',
                onPressed: () => setState(() => _selectedBoardId = null),
                icon: const Icon(Icons.arrow_back),
              ),
        title: Text(board?.name ?? 'Inspiration Boards'),
        actions: [
          if (board != null)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'delete') _deleteBoard(board);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete board')),
              ],
            ),
          if (board == null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Look for a hidden video',
                  onPressed: widget.onFindEasterEgg,
                  icon: const Icon(Icons.egg_outlined),
                ),
                IconButton(
                  tooltip: 'Create a board',
                  onPressed: _createBoard,
                  icon: const Icon(Icons.add),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Make original art',
                  onPressed: _isAddingPhoto
                      ? null
                      : () => _createArtwork(board),
                  icon: const Icon(Icons.auto_awesome),
                ),
                IconButton(
                  tooltip: 'Add photo',
                  onPressed: _isAddingPhoto ? null : () => _addPhoto(board),
                  icon: _isAddingPhoto
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
              ],
            ),
        ],
      ),
      body: board == null ? _buildBoards() : _buildBoardPhotos(board),
      floatingActionButton: board == null && widget.boards.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _createBoard,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New board'),
            )
          : null,
    );
  }

  Widget _buildBoards() {
    if (widget.boards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Collect ideas in your own boards',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep visual inspiration separate from your regular posts. '
                'Create a board, then add photos from your gallery. '
                'Boards are private and saved on this device for now.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _createBoard,
                icon: const Icon(Icons.add),
                label: const Text('Create your first board'),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: widget.boards.length,
      itemBuilder: (context, index) {
        final board = widget.boards[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _selectedBoardId = board.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: board.photos.isEmpty
                      ? ColoredBox(
                          color: Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: 0.5),
                          child: const Center(
                            child: Icon(Icons.photo_outlined, size: 44),
                          ),
                        )
                      : _boardImage(
                          board.photos.last.imagePath,
                          fit: BoxFit.cover,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        board.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${board.photos.length} ${board.photos.length == 1 ? 'photo' : 'photos'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardPhotos(PhotoBoard board) {
    if (board.photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_photo_alternate_outlined, size: 56),
              const SizedBox(height: 12),
              const Text('This board is ready for inspiration.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isAddingPhoto ? null : () => _addPhoto(board),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add a photo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isAddingPhoto ? null : () => _createArtwork(board),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Make free original art'),
              ),
            ],
          ),
        ),
      );
    }

    final leftColumn = <BoardPhoto>[];
    final rightColumn = <BoardPhoto>[];
    for (var index = 0; index < board.photos.length; index++) {
      (index.isEven ? leftColumn : rightColumn).add(board.photos[index]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildPhotoColumn(board, leftColumn, 0)),
          const SizedBox(width: 10),
          Expanded(child: _buildPhotoColumn(board, rightColumn, 1)),
        ],
      ),
    );
  }

  Widget _buildPhotoColumn(
    PhotoBoard board,
    List<BoardPhoto> photos,
    int column,
  ) {
    return Column(
      children: photos.indexed.map((entry) {
        final (index, photo) = entry;
        final height = 150.0 + ((index + column) % 3) * 55;
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _BoardPhotoViewer(imagePath: photo.imagePath),
                  ),
                ),
                child: SizedBox(
                  height: height,
                  child: _boardImage(photo.imagePath, fit: BoxFit.cover),
                ),
              ),
              if (photo.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Text(photo.caption),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Remove photo',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deletePhoto(board, photo),
                  icon: const Icon(Icons.bookmark_remove_outlined),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _boardImage(String path, {required BoxFit fit}) {
    if (path.startsWith('data:image/')) {
      final separator = path.indexOf(',');
      if (separator < 0) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      }
      return Image.memory(
        base64Decode(path.substring(separator + 1)),
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    if (kIsWeb || path.startsWith('http')) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

class _BoardPhotoViewer extends StatelessWidget {
  const _BoardPhotoViewer({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: Center(
      child: InteractiveViewer(child: _BoardPhotoImage(imagePath: imagePath)),
    ),
  );
}

class _BoardPhotoImage extends StatelessWidget {
  const _BoardPhotoImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    if (imagePath.startsWith('data:image/')) {
      final separator = imagePath.indexOf(',');
      if (separator < 0) {
        return const Icon(Icons.broken_image_outlined, color: Colors.white);
      }
      return Image.memory(
        base64Decode(imagePath.substring(separator + 1)),
        fit: BoxFit.contain,
      );
    }
    if (kIsWeb || imagePath.startsWith('http')) {
      return Image.network(imagePath, fit: BoxFit.contain);
    }
    return Image.file(File(imagePath), fit: BoxFit.contain);
  }
}
