import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StoryAudience { everyone, friends, closeFriends }

extension StoryAudienceLabel on StoryAudience {
  String get label => switch (this) {
    StoryAudience.everyone => 'Everyone',
    StoryAudience.friends => 'Friends',
    StoryAudience.closeFriends => 'Close Friends',
  };

  IconData get icon => switch (this) {
    StoryAudience.everyone => Icons.public,
    StoryAudience.friends => Icons.people_outline,
    StoryAudience.closeFriends => Icons.favorite_outline,
  };
}

class SocialStory {
  const SocialStory({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.audience,
  });

  static const lifetime = Duration(hours: 24);

  final String id;
  final String author;
  final String text;
  final DateTime createdAt;
  final StoryAudience audience;

  DateTime get expiresAt => createdAt.add(lifetime);

  bool isExpiredAt(DateTime time) => !expiresAt.isAfter(time);

  Map<String, Object?> toJson() => {
    'id': id,
    'author': author,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'audience': audience.name,
  };

  factory SocialStory.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final audienceName = json['audience'] as String?;
    final audience = StoryAudience.values
        .where((item) => item.name == audienceName)
        .firstOrNull;
    if (createdAt == null || audience == null) {
      throw const FormatException('Saved story has invalid date or audience.');
    }
    return SocialStory(
      id: json['id'] as String,
      author: json['author'] as String,
      text: json['text'] as String,
      createdAt: createdAt,
      audience: audience,
    );
  }
}

class SocialPreferences {
  const SocialPreferences({
    this.personalizedFeed = false,
    this.interests = const ['Tech', 'Design'],
  });

  final bool personalizedFeed;
  final List<String> interests;

  SocialPreferences copyWith({
    bool? personalizedFeed,
    List<String>? interests,
  }) => SocialPreferences(
    personalizedFeed: personalizedFeed ?? this.personalizedFeed,
    interests: interests ?? this.interests,
  );

  Map<String, Object?> toJson() => {
    'personalizedFeed': personalizedFeed,
    'interests': interests,
  };

  factory SocialPreferences.fromJson(Map<String, dynamic> json) {
    final interests = json['interests'];
    return SocialPreferences(
      personalizedFeed: json['personalizedFeed'] as bool? ?? false,
      interests: interests is List
          ? interests.whereType<String>().toList()
          : const ['Tech', 'Design'],
    );
  }
}

class SocialExperienceStore {
  static const storiesKey = 'social_stories_v1';
  static const preferencesKey = 'social_preferences_v1';

  static Future<List<SocialStory>> loadStories({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storiesKey);
    if (raw == null) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved stories must be a list.');
    }
    final stories = decoded
        .map(
          (item) =>
              SocialStory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final currentTime = now ?? DateTime.now();
    final activeStories = stories
        .where((story) => !story.isExpiredAt(currentTime))
        .toList();
    if (activeStories.length != stories.length) {
      await _saveStories(prefs, activeStories);
    }
    return activeStories;
  }

  static Future<void> addStory(SocialStory story) async {
    final prefs = await SharedPreferences.getInstance();
    final activeStories = await loadStories();
    activeStories.add(story);
    await _saveStories(prefs, activeStories);
  }

  static Future<SocialPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(preferencesKey);
    if (raw == null) return const SocialPreferences();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException(
        'Saved social preferences must be an object.',
      );
    }
    return SocialPreferences.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<void> savePreferences(SocialPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      preferencesKey,
      jsonEncode(preferences.toJson()),
    );
    if (!saved) {
      throw StateError('The device declined to save social preferences.');
    }
  }

  static Future<void> _saveStories(
    SharedPreferences prefs,
    List<SocialStory> stories,
  ) async {
    final saved = await prefs.setString(
      storiesKey,
      jsonEncode(stories.map((story) => story.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('The device declined to save stories.');
    }
  }
}

List<Map<String, dynamic>> rankPostsForYou(
  List<Map<String, dynamic>> posts,
  List<String> interests,
) {
  final normalizedInterests = interests
      .map((item) => item.toLowerCase())
      .toSet();
  final now = DateTime.now().millisecondsSinceEpoch;
  final indexedPosts = posts.indexed.toList();
  indexedPosts.sort((a, b) {
    final scoreDifference = _postScore(
      b.$2,
      normalizedInterests,
      now,
    ).compareTo(_postScore(a.$2, normalizedInterests, now));
    return scoreDifference == 0 ? a.$1.compareTo(b.$1) : scoreDifference;
  });
  return indexedPosts.map((entry) => entry.$2).toList();
}

double _postScore(Map<String, dynamic> post, Set<String> interests, int now) {
  final category = post['category']?.toString().toLowerCase();
  final interestScore = category != null && interests.contains(category)
      ? 100.0
      : 0.0;
  final pinnedScore = post['isPinned'] == true ? 20.0 : 0.0;
  final likes = post['likeCount'] is num
      ? (post['likeCount'] as num).clamp(0, 100).toDouble()
      : 0.0;
  final timestamp = post['timestamp'] is num
      ? (post['timestamp'] as num).toInt()
      : now;
  final ageHours = ((now - timestamp) / Duration.millisecondsPerHour)
      .clamp(0, 168)
      .toDouble();
  final recencyScore = 48.0 * (1 - ageHours / 168);
  return interestScore + pinnedScore + likes * 0.2 + recencyScore;
}

class SocialStoriesStrip extends StatefulWidget {
  const SocialStoriesStrip({super.key, required this.username});

  final String username;

  @override
  State<SocialStoriesStrip> createState() => _SocialStoriesStripState();
}

class _SocialStoriesStripState extends State<SocialStoriesStrip> {
  List<SocialStory> _stories = const [];
  Object? _loadError;
  bool _isLoading = true;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final stories = await SocialExperienceStore.loadStories();
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _loadError = null;
        _isLoading = false;
      });
      _scheduleExpiry(stories);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  void _scheduleExpiry(List<SocialStory> stories) {
    _expiryTimer?.cancel();
    if (stories.isEmpty) return;
    final nextExpiry = stories
        .map((story) => story.expiresAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = nextExpiry.difference(DateTime.now());
    _expiryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      _loadStories,
    );
  }

  Future<void> _createStory() async {
    final textController = TextEditingController();
    var audience = StoryAudience.friends;
    final created = await showDialog<SocialStory>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add a 24-hour story'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                maxLength: 180,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Your story',
                  hintText: 'Share a quick moment...',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<StoryAudience>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: StoryAudience.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => audience = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Stories are stored on this device in this prototype. '
                'Audience labels are not server-enforced privacy controls.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isEmpty) return;
                final now = DateTime.now();
                Navigator.pop(
                  context,
                  SocialStory(
                    id: now.microsecondsSinceEpoch.toString(),
                    author: widget.username,
                    text: text,
                    createdAt: now,
                    audience: audience,
                  ),
                );
              },
              child: const Text('Share story'),
            ),
          ],
        ),
      ),
    );
    textController.dispose();
    if (created == null) return;
    try {
      await SocialExperienceStore.addStory(created);
      if (!mounted) return;
      final stories = [..._stories, created];
      setState(() => _stories = stories);
      _scheduleExpiry(stories);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your story: $error')),
      );
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _viewStory(SocialStory story) {
    final remaining = story.expiresAt.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(story.author),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(story.text),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(story.audience.icon, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${story.audience.label} · expires in ${hours}h ${minutes}m',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 94,
    child: _loadError != null
        ? Row(
            children: [
              const Expanded(child: Text('Could not load stories.')),
              IconButton(
                onPressed: _loadStories,
                icon: const Icon(Icons.refresh),
                tooltip: 'Retry loading stories',
              ),
            ],
          )
        : ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _StoryAvatar(
                label: 'Your story',
                icon: _isLoading ? Icons.hourglass_empty : Icons.add,
                onTap: _isLoading ? null : _createStory,
              ),
              ..._stories.map(
                (story) => _StoryAvatar(
                  label: story.author,
                  icon: story.audience.icon,
                  onTap: () => _viewStory(story),
                ),
              ),
            ],
          ),
  );
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(child: Icon(icon, size: 20)),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class SocialPreferencesScreen extends StatefulWidget {
  const SocialPreferencesScreen({super.key});

  @override
  State<SocialPreferencesScreen> createState() =>
      _SocialPreferencesScreenState();
}

class _SocialPreferencesScreenState extends State<SocialPreferencesScreen> {
  static const _availableInterests = ['Tech', 'Design', 'Memes', 'Hacks'];
  SocialPreferences _preferences = const SocialPreferences();
  Object? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SocialExperienceStore.loadPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _save(SocialPreferences updated) async {
    setState(() => _preferences = updated);
    try {
      await SocialExperienceStore.savePreferences(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save preferences: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Feed & privacy controls')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your preferences.'),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Interest-based “For You” feed'),
                subtitle: const Text(
                  'Uses your selected topics and post activity on this device; '
                  'this is a simple local ranking, not AI.',
                ),
                value: _preferences.personalizedFeed,
                onChanged: (value) =>
                    _save(_preferences.copyWith(personalizedFeed: value)),
              ),
              const SizedBox(height: 12),
              Text(
                'Topics you like',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _availableInterests.map((interest) {
                  final selected = _preferences.interests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: selected,
                    onSelected: (value) {
                      final interests = [..._preferences.interests];
                      if (value) {
                        interests.add(interest);
                      } else {
                        interests.remove(interest);
                      }
                      _save(_preferences.copyWith(interests: interests));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Privacy note: profiles, posts, stories, and message data '
                    'are currently local prototypes. Story audience choices '
                    'are labels only and are not enforced for other users. '
                    'Do not share sensitive information here.',
                  ),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Friends, Close Friends, Family, Work'),
                subtitle: Text(
                  'Audience tiers need signed-in accounts and server-side '
                  'access rules before they can protect shared posts.',
                ),
              ),
            ],
          ),
  );
}
