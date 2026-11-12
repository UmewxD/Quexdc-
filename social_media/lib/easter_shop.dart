import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

enum EasterEggPlacement { boards, companion, region }

class EasterEgg {
  const EasterEgg({
    required this.id,
    required this.title,
    required this.clue,
    required this.placement,
    required this.videoUrl,
    this.skipPoints = 2,
    this.watchPoints = 10,
  });

  final String id;
  final String title;
  final String clue;
  final EasterEggPlacement placement;
  final String? videoUrl;
  final int skipPoints;
  final int watchPoints;
}

const easterEggs = [
  EasterEgg(
    id: 'boards_first_pin',
    title: 'The Pin That Plays',
    clue: 'A moving idea is tucked among the inspiration boards.',
    placement: EasterEggPlacement.boards,
    videoUrl: null,
  ),
  EasterEgg(
    id: 'companion_side_quest',
    title: 'Companion Side Quest',
    clue: 'One of the Cloud Bar companions has something to show you.',
    placement: EasterEggPlacement.companion,
    videoUrl: null,
  ),
  EasterEgg(
    id: 'region_signal',
    title: 'A Signal Between Regions',
    clue: 'Look around the region selector for a hidden transmission.',
    placement: EasterEggPlacement.region,
    videoUrl: null,
  ),
];

String easterEggPlacementLabel(EasterEggPlacement placement) =>
    switch (placement) {
      EasterEggPlacement.boards => 'Inspiration Boards',
      EasterEggPlacement.companion => 'Cloud Bar',
      EasterEggPlacement.region => 'Region selector',
    };

class EasterEconomySnapshot {
  const EasterEconomySnapshot({
    this.points = 0,
    this.hasProgress = false,
    this.completedQuestIds = const {},
    this.claimedQuestIds = const {},
    this.discoveredEggIds = const {},
    this.ownedItemIds = const {},
    this.spentActionIds = const {},
  });

  final int points;
  final bool hasProgress;
  final Set<String> completedQuestIds;
  final Set<String> claimedQuestIds;
  final Set<String> discoveredEggIds;
  final Set<String> ownedItemIds;
  final Set<String> spentActionIds;

  Map<String, dynamic> toJson() => {
    'points': points,
    'hasProgress': hasProgress,
    'completedQuestIds': completedQuestIds.toList(),
    'claimedQuestIds': claimedQuestIds.toList(),
    'discoveredEggIds': discoveredEggIds.toList(),
    'ownedItemIds': ownedItemIds.toList(),
    'spentActionIds': spentActionIds.toList(),
  };

  factory EasterEconomySnapshot.fromJson(Map<String, dynamic> json) {
    final points = json['points'];
    final hasProgress = json['hasProgress'] ?? true;
    final completed = json['completedQuestIds'];
    final claimed = json['claimedQuestIds'] ?? completed;
    final eggs = json['discoveredEggIds'] ?? const [];
    final owned = json['ownedItemIds'];
    final spentActions = json['spentActionIds'] ?? const [];
    if (points is! int ||
        points < 0 ||
        hasProgress is! bool ||
        completed is! List ||
        claimed is! List ||
        eggs is! List ||
        owned is! List ||
        spentActions is! List ||
        completed.any((item) => item is! String) ||
        claimed.any((item) => item is! String) ||
        eggs.any((item) => item is! String) ||
        owned.any((item) => item is! String)) {
      throw const FormatException('Saved Easter Shop data is invalid.');
    }
    if (spentActions.any((item) => item is! String)) {
      throw const FormatException(
        'Saved Easter Shop spending data is invalid.',
      );
    }
    return EasterEconomySnapshot(
      points: points,
      hasProgress: hasProgress,
      completedQuestIds: completed.cast<String>().toSet(),
      claimedQuestIds: claimed.cast<String>().toSet(),
      discoveredEggIds: eggs.cast<String>().toSet(),
      ownedItemIds: owned.cast<String>().toSet(),
      spentActionIds: spentActions.cast<String>().toSet(),
    );
  }
}

class EasterEconomyStore {
  static const _storageKey = 'easter_economy_v1';

  Future<EasterEconomySnapshot> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) return const EasterEconomySnapshot();
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Saved Easter Shop data must be an object.');
    }
    return EasterEconomySnapshot.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<EasterEconomySnapshot> completeQuest(
    String questId, {
    required int points,
  }) async {
    if (questId.trim().isEmpty || points <= 0) {
      throw ArgumentError('A quest ID and positive point reward are required.');
    }
    final current = await load();
    if (current.completedQuestIds.contains(questId)) return current;
    final alreadyClaimed = current.claimedQuestIds.contains(questId);
    return _save(
      EasterEconomySnapshot(
        points: current.points + (alreadyClaimed ? 0 : points),
        hasProgress: true,
        completedQuestIds: {...current.completedQuestIds, questId},
        claimedQuestIds: {...current.claimedQuestIds, questId},
        discoveredEggIds: current.discoveredEggIds,
        ownedItemIds: current.ownedItemIds,
        spentActionIds: current.spentActionIds,
      ),
    );
  }

  Future<EasterEconomySnapshot> uncompleteQuest(String questId) async {
    final current = await load();
    if (!current.completedQuestIds.contains(questId)) return current;
    return _save(
      EasterEconomySnapshot(
        points: current.points,
        hasProgress: true,
        completedQuestIds: {...current.completedQuestIds}..remove(questId),
        claimedQuestIds: current.claimedQuestIds,
        discoveredEggIds: current.discoveredEggIds,
        ownedItemIds: current.ownedItemIds,
        spentActionIds: current.spentActionIds,
      ),
    );
  }

  Future<EasterEconomySnapshot> claimEgg({
    required String eggId,
    required int points,
  }) async {
    if (eggId.trim().isEmpty || points <= 0) {
      throw ArgumentError('An egg ID and positive point reward are required.');
    }
    final current = await load();
    if (current.discoveredEggIds.contains(eggId)) {
      throw StateError('This Easter Egg has already been claimed.');
    }
    return _save(
      EasterEconomySnapshot(
        points: current.points + points,
        hasProgress: true,
        completedQuestIds: current.completedQuestIds,
        claimedQuestIds: current.claimedQuestIds,
        discoveredEggIds: {...current.discoveredEggIds, eggId},
        ownedItemIds: current.ownedItemIds,
        spentActionIds: current.spentActionIds,
      ),
    );
  }

  Future<EasterEconomySnapshot> purchase({
    required String itemId,
    required int cost,
  }) async {
    if (itemId.trim().isEmpty || cost <= 0) {
      throw ArgumentError('A shop item ID and positive cost are required.');
    }
    final current = await load();
    if (current.ownedItemIds.contains(itemId)) {
      throw StateError('This Easter Shop item is already owned.');
    }
    if (current.points < cost) {
      throw StateError('You do not have enough Easter Points yet.');
    }
    return _save(
      EasterEconomySnapshot(
        points: current.points - cost,
        hasProgress: true,
        completedQuestIds: current.completedQuestIds,
        claimedQuestIds: current.claimedQuestIds,
        discoveredEggIds: current.discoveredEggIds,
        ownedItemIds: {...current.ownedItemIds, itemId},
        spentActionIds: current.spentActionIds,
      ),
    );
  }

  Future<EasterEconomySnapshot> spendPointsOnce({
    required String actionId,
    required int cost,
  }) async {
    if (actionId.trim().isEmpty || cost <= 0) {
      throw ArgumentError(
        'A spending action ID and positive cost are required.',
      );
    }
    final current = await load();
    if (current.spentActionIds.contains(actionId)) return current;
    if (current.points < cost) {
      throw StateError('You do not have enough Easter Points yet.');
    }
    return _save(
      EasterEconomySnapshot(
        points: current.points - cost,
        hasProgress: true,
        completedQuestIds: current.completedQuestIds,
        claimedQuestIds: current.claimedQuestIds,
        discoveredEggIds: current.discoveredEggIds,
        ownedItemIds: current.ownedItemIds,
        spentActionIds: {...current.spentActionIds, actionId},
      ),
    );
  }

  Future<EasterEconomySnapshot> _save(EasterEconomySnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(snapshot.toJson()),
    );
    if (!saved) throw StateError('The device declined to save Easter Points.');
    return snapshot;
  }
}

enum EasterShopItemType { theme, badge, sound }

class EasterShopItem {
  const EasterShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.type,
    this.color,
    this.badgeLabel,
    this.soundId,
  });

  final String id;
  final String name;
  final String description;
  final int cost;
  final EasterShopItemType type;
  final Color? color;
  final String? badgeLabel;
  final String? soundId;
}

class EasterEggHuntScreen extends StatelessWidget {
  const EasterEggHuntScreen({super.key, required this.store, this.placement});

  final EasterEconomyStore store;
  final EasterEggPlacement? placement;

  @override
  Widget build(BuildContext context) {
    final eggs = placement == null
        ? easterEggs
        : easterEggs.where((egg) => egg.placement == placement).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          placement == null
              ? 'Beginner’s Video List'
              : '${easterEggPlacementLabel(placement!)} Hunt',
        ),
      ),
      body: eggs.isEmpty
          ? const Center(child: Text('No Easter Eggs are hidden here yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (placement == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'New to the hunt? Start with these beginner clues. '
                        'Eggs stay in the collection once added; new videos '
                        'bring new clues rather than replacing old finds.',
                      ),
                    ),
                  ),
                for (final egg in eggs)
                  _EasterEggCard(
                    egg: egg,
                    store: store,
                    showPlacement: placement == null,
                  ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Only use videos you created or have permission to share. '
                    'Egg rewards are local to this device and can’t be redeemed for money.',
                  ),
                ),
              ],
            ),
    );
  }
}

class _EasterEggCard extends StatefulWidget {
  const _EasterEggCard({
    required this.egg,
    required this.store,
    this.showPlacement = false,
  });

  final EasterEgg egg;
  final EasterEconomyStore store;
  final bool showPlacement;

  @override
  State<_EasterEggCard> createState() => _EasterEggCardState();
}

class _EasterEggCardState extends State<_EasterEggCard> {
  VideoPlayerController? _controller;
  EasterEconomySnapshot _snapshot = const EasterEconomySnapshot();
  Duration _watched = Duration.zero;
  Duration? _lastPosition;
  bool _isLoading = true;
  bool _isClaiming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    VideoPlayerController? controller;
    try {
      final snapshot = await widget.store.load();
      final url = widget.egg.videoUrl;
      if (url != null && url.trim().isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri == null ||
            uri.scheme != 'https' ||
            !uri.hasAuthority ||
            uri.host.isEmpty) {
          throw const FormatException('Easter Egg video URLs must use HTTPS.');
        }
        controller = VideoPlayerController.networkUrl(uri);
        await controller.initialize();
        controller.addListener(_trackPlayback);
      }
      if (!mounted) {
        await controller?.dispose();
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _controller = controller;
        _isLoading = false;
      });
    } catch (error) {
      await controller?.dispose();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load this Easter Egg video: $error';
      });
    }
  }

  void _trackPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    final current = controller.value.position;
    final previous = _lastPosition;
    _lastPosition = current;
    if (previous == null) return;
    final delta = current - previous;
    if (delta > Duration.zero && delta <= const Duration(milliseconds: 500)) {
      setState(() => _watched += delta);
    }
  }

  bool get _watchedToEnd {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return false;
    final duration = controller.value.duration;
    final allowedUnwatched = duration < const Duration(seconds: 10)
        ? const Duration(milliseconds: 500)
        : const Duration(seconds: 2);
    return _watched >= duration - allowedUnwatched;
  }

  Future<void> _claim({required bool watched}) async {
    if (_isClaiming || _snapshot.discoveredEggIds.contains(widget.egg.id)) {
      return;
    }
    if (watched && !_watchedToEnd) return;
    setState(() => _isClaiming = true);
    try {
      final updated = await widget.store.claimEgg(
        eggId: widget.egg.id,
        points: watched ? widget.egg.watchPoints : widget.egg.skipPoints,
      );
      if (!mounted) return;
      setState(() => _snapshot = updated);
      await _controller?.pause();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            watched
                ? 'Easter Egg found! +${widget.egg.watchPoints} points!'
                : 'Egg found! +${widget.egg.skipPoints} points for skipping.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not claim this egg: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_trackPlayback);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alreadyFound = _snapshot.discoveredEggIds.contains(widget.egg.id);
    final controller = _controller;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.egg.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.showPlacement) ...[
              const SizedBox(height: 3),
              Text(
                'Look in ${easterEggPlacementLabel(widget.egg.placement)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
            const SizedBox(height: 4),
            Text(widget.egg.clue),
            const SizedBox(height: 10),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (widget.egg.videoUrl == null)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.hide_image_outlined),
                title: Text('Video slot ready'),
                subtitle: Text(
                  'Add your video URL to this egg in easter_shop.dart when your clip is ready.',
                ),
              )
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (controller != null && controller.value.isInitialized) ...[
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: controller.value.isPlaying ? 'Pause' : 'Play',
                    onPressed: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: controller.value.duration.inMilliseconds == 0
                          ? 0
                          : (_watched.inMilliseconds /
                                    controller.value.duration.inMilliseconds)
                                .clamp(0, 1)
                                .toDouble(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_watchedToEnd ? 'Watched!' : 'Watch to earn more'),
                ],
              ),
            ],
            if (alreadyFound)
              const Chip(
                avatar: Icon(Icons.check_circle_outline),
                label: Text('Already found on this device'),
              )
            else if (!_isLoading &&
                widget.egg.videoUrl != null &&
                _error == null)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isClaiming
                        ? null
                        : () => _claim(watched: false),
                    icon: const Icon(Icons.skip_next),
                    label: Text('Skip · +${widget.egg.skipPoints}'),
                  ),
                  FilledButton.icon(
                    onPressed: _isClaiming || !_watchedToEnd
                        ? null
                        : () => _claim(watched: true),
                    icon: const Icon(Icons.stars),
                    label: Text('Watched · +${widget.egg.watchPoints}'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

const easterShopItems = [
  EasterShopItem(
    id: 'easter_theme_nebula',
    name: 'Nebula Glow',
    description: 'A cosmic violet accent for your Quexdc stage.',
    cost: 30,
    type: EasterShopItemType.theme,
    color: Color(0xFF8A65F2),
  ),
  EasterShopItem(
    id: 'easter_theme_comet',
    name: 'Comet Trail',
    description: 'A bright cyan accent with a little stardust energy.',
    cost: 50,
    type: EasterShopItemType.theme,
    color: Color(0xFF00AFC1),
  ),
  EasterShopItem(
    id: 'easter_theme_afterglow',
    name: 'Afterglow',
    description: 'A warm pink accent for late-night explorers.',
    cost: 75,
    type: EasterShopItemType.theme,
    color: Color(0xFFE2549A),
  ),
  EasterShopItem(
    id: 'easter_badge_stardust',
    name: 'Stardust Seeker',
    description: 'A cosmic badge flair for your profile.',
    cost: 35,
    type: EasterShopItemType.badge,
    badgeLabel: '✨ Stardust Seeker',
  ),
  EasterShopItem(
    id: 'easter_badge_egg_hunter',
    name: 'Egg Hunter',
    description: 'Show off your Easter Egg discoveries.',
    cost: 60,
    type: EasterShopItemType.badge,
    badgeLabel: '🥚 Egg Hunter',
  ),
  EasterShopItem(
    id: 'easter_sound_glitch',
    name: 'Glitch Portal Sound',
    description: 'Assign an original glitch synth tone to your portal.',
    cost: 40,
    type: EasterShopItemType.sound,
    soundId: 'tone:glitch',
  ),
  EasterShopItem(
    id: 'easter_sound_bubble',
    name: 'Bubble Portal Sound',
    description: 'Assign an original bubble synth tone to your portal.',
    cost: 40,
    type: EasterShopItemType.sound,
    soundId: 'tone:bubble',
  ),
];

class EasterShopScreen extends StatefulWidget {
  const EasterShopScreen({
    super.key,
    required this.store,
    required this.onItemApplied,
  });

  final EasterEconomyStore store;
  final Future<void> Function(EasterShopItem) onItemApplied;

  @override
  State<EasterShopScreen> createState() => _EasterShopScreenState();
}

class _EasterShopScreenState extends State<EasterShopScreen> {
  EasterEconomySnapshot _snapshot = const EasterEconomySnapshot();
  bool _isLoading = true;
  String? _error;
  String? _processingItemId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.store.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load the Easter Shop: $error';
      });
    }
  }

  Future<void> _buyOrApply(EasterShopItem item) async {
    final alreadyOwned = _snapshot.ownedItemIds.contains(item.id);
    if (!alreadyOwned) {
      setState(() => _processingItemId = item.id);
      try {
        final updated = await widget.store.purchase(
          itemId: item.id,
          cost: item.cost,
        );
        if (!mounted) return;
        setState(() => _snapshot = updated);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get this item: $error')),
        );
        return;
      } finally {
        if (mounted) setState(() => _processingItemId = null);
      }
    }
    try {
      await widget.onItemApplied(item);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not apply this item: $error')),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyOwned ? '${item.name} applied.' : '${item.name} unlocked!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Easter Shop 🥚')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.stars),
                  title: Text(
                    '${_snapshot.points} Easter Points',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: const Text(
                    'Explore the growing collection. Skip a video for base '
                    'points or watch through for the full reward.',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.explore_outlined),
                  title: const Text('Beginner’s Video List'),
                  subtitle: const Text(
                    'Browse permanent starter clues and find each egg’s home.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EasterEggHuntScreen(store: widget.store),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unlocks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final item in easterShopItems)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          item.color ?? Theme.of(context).colorScheme.primary,
                      child: Icon(switch (item.type) {
                        EasterShopItemType.theme => Icons.palette_outlined,
                        EasterShopItemType.badge => Icons.verified_outlined,
                        EasterShopItemType.sound => Icons.graphic_eq,
                      }, color: Colors.white),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.description}\n'
                      '${_snapshot.ownedItemIds.contains(item.id) ? 'Owned' : '${item.cost} Easter Points'}',
                    ),
                    isThreeLine: true,
                    trailing: _processingItemId == item.id
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _snapshot.ownedItemIds.contains(item.id)
                                ? Icons.check_circle_outline
                                : Icons.shopping_bag_outlined,
                          ),
                    onTap:
                        _processingItemId == null &&
                            (_snapshot.ownedItemIds.contains(item.id) ||
                                _snapshot.points >= item.cost)
                        ? () => _buyOrApply(item)
                        : null,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Easter Points are saved on this device. They are not money, '
                'marketplace credit, or a shared leaderboard score. Items are '
                'cosmetic unlocks for this device.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
  );
}
