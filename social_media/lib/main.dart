import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import 'font_marketplace.dart';
import 'marketplace_hub.dart';
import 'escape_dimensions.dart';
import 'easter_shop.dart';
import 'status_mood_manager.dart';
import 'sound_studio.dart';
import 'visual_boards.dart';
import 'voice_assistant.dart';
import 'social_experience.dart';
import 'welcome_montage.dart';
import 'quest_streaks.dart';
import 'beta_ideas_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FontMarketplaceService.initialize();
  runApp(const Quexdc());
}

class Quexdc extends StatefulWidget {
  const Quexdc({super.key});

  @override
  State<Quexdc> createState() => _QuexdcState();

  static _QuexdcState? of(BuildContext context) =>
      context.findAncestorStateOfType<_QuexdcState>();
}

class _QuexdcState extends State<Quexdc> {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = const Color(0xFF6366F1);
  Color _baseAccentColor = const Color(0xFF6366F1);
  String? _communityFontFamily;
  final Set<String> _loadedCommunityFonts = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isDark = prefs.getBool('is_dark_mode') ?? true;
    final int colorVal =
        prefs.getInt('accent_color') ?? const Color(0xFF6366F1).value;
    final selectedFontId = prefs.getString('community_font_id');
    if (!mounted) return;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _accentColor = Color(colorVal);
      _baseAccentColor = Color(colorVal);
    });
    if (selectedFontId != null && FontMarketplaceService.isReady) {
      try {
        final font = await FontMarketplaceService.getFont(selectedFontId);
        if (font != null) await applyCommunityFont(font, persist: false);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not restore your selected font: $error'),
            ),
          );
        }
      }
    }
  }

  Future<void> applyCommunityFont(
    FontListing listing, {
    bool persist = true,
  }) async {
    if (!_loadedCommunityFonts.contains(listing.id)) {
      final bytes = await FontMarketplaceService.downloadFont(listing);
      final loader = FontLoader(listing.family)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedCommunityFonts.add(listing.id);
    }
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('community_font_id', listing.id);
    }
    if (mounted) setState(() => _communityFontFamily = listing.family);
  }

  Future<void> resetCommunityFont() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('community_font_id');
    if (mounted) setState(() => _communityFontFamily = null);
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
    prefs.setBool('is_dark_mode', _themeMode == ThemeMode.dark);
  }

  void changeAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _baseAccentColor = color;
      _accentColor = color;
    });
    prefs.setInt('accent_color', color.value);
  }

  void setDimensionAccent(Color? color) {
    setState(() => _accentColor = color ?? _baseAccentColor);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quexdc',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: _communityFontFamily,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accentColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: _communityFontFamily,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accentColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// --- STARTUP SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigator(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      const Color(0xFF9333EA),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary
                          .withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Quexdc',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Global Builder Network',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _moodStatusExpiryTimer;
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> notifications = [];
  Map<String, List<Map<String, dynamic>>> directMessages = {};
  bool isLoading = true;
  int unreadNotificationsCount = 2;
  bool isBetaTester = false;
  MoodStatus? moodStatus;
  List<PhotoBoard> photoBoards = [];
  final SoundStudioController _soundStudio = SoundStudioController();
  final EasterEconomyStore _easterStore = EasterEconomyStore();
  late final VoiceAssistantController _voiceAssistant;

  String myUsername = '@alex';
  String myBio = 'Building apps, breaking bugs, shipping code. 🚀';
  String myBadge = '⚡ Founder';
  int followerCount = 142;
  int followingCount = 89;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceAssistant = VoiceAssistantController(onCommand: _handleVoiceCommand);
    _loadData();
    unawaited(_recordAppStreak());
  }

  Future<void> _recordAppStreak() async {
    try {
      await QuestStreakStore.recordActivity(QuestStreakStore.appKey);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update your app streak: $error')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_voiceAssistant.handleLifecycle(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _moodStatusExpiryTimer?.cancel();
    _voiceAssistant.dispose();
    unawaited(_soundStudio.dispose());
    super.dispose();
  }

  void _scheduleMoodStatusExpiry(MoodStatus? status) {
    _moodStatusExpiryTimer?.cancel();
    if (status == null) return;
    final expiresAt = status.expiresAt;
    if (expiresAt == null) return;
    final delay = expiresAt.difference(DateTime.now());
    _moodStatusExpiryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => _expireMoodStatus(status),
    );
  }

  Future<void> _expireMoodStatus(MoodStatus status) async {
    if (!mounted || moodStatus?.updatedAt != status.updatedAt) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mood_status');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not clear your expired status: $error'),
          ),
        );
      }
      return;
    }
    if (!mounted || moodStatus?.updatedAt != status.updatedAt) return;
    setState(() => moodStatus = null);
  }

  List<Map<String, dynamic>> _parsePostsSafely(dynamic decoded) {
    if (decoded is! List) return _defaultPosts();
    List<Map<String, dynamic>> parsedList = [];
    for (var item in decoded) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        List<String> commentsList = [];
        if (map['comments'] is List) {
          commentsList = (map['comments'] as List)
              .map((c) => c.toString())
              .toList();
        }

        Map<String, dynamic>? pollData;
        if (map['poll'] is Map) {
          final pMap = Map<String, dynamic>.from(map['poll'] as Map);
          pollData = {
            'optionA': pMap['optionA']?.toString() ?? 'Option A',
            'votesA': pMap['votesA'] is int ? pMap['votesA'] : 0,
            'optionB': pMap['optionB']?.toString() ?? 'Option B',
            'votesB': pMap['votesB'] is int ? pMap['votesB'] : 0,
            'userVoted': pMap['userVoted']?.toString(),
          };
        }

        parsedList.add({
          'id':
              map['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          'username': map['username']?.toString() ?? '@alex',
          'badge': map['badge']?.toString() ?? '⚡ Founder',
          'region': map['region']?.toString() ?? 'Global',
          'category': map['category']?.toString() ?? 'Tech',
          'isPinned': map['isPinned'] == true,
          'repostedBy': map['repostedBy']?.toString(),
          'content': map['content']?.toString() ?? '',
          'translatedContent': map['translatedContent']?.toString(),
          'imagePath': map['imagePath']?.toString(),
          'webUrl': map['webUrl']?.toString(),
          'hasAudio': map['hasAudio'] == true,
          'audioTitle': map['audioTitle']?.toString() ?? 'Voice Note',
          'timestamp': map['timestamp'] is int
              ? map['timestamp']
              : DateTime.now().millisecondsSinceEpoch,
          'comments': commentsList,
          'isLiked': map['isLiked'] == true,
          'likeCount': map['likeCount'] is int
              ? map['likeCount']
              : int.tryParse(map['likeCount']?.toString() ?? '0') ?? 0,
          'isBookmarked': map['isBookmarked'] == true,
          'poll': pollData,
        });
      }
    }
    return parsedList.isEmpty ? _defaultPosts() : parsedList;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _soundStudio.load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restore sound settings: $error')),
        );
      }
    }
    isBetaTester = prefs.getBool('is_beta_tester') ?? false;
    var loadedPhotoBoards = <PhotoBoard>[];
    final storedPhotoBoards = prefs.getString('photo_boards');
    if (storedPhotoBoards != null) {
      try {
        final decoded = jsonDecode(storedPhotoBoards);
        if (decoded is! List) {
          throw const FormatException('Stored photo boards are not a list.');
        }
        loadedPhotoBoards = decoded
            .map(
              (board) =>
                  PhotoBoard.fromJson(Map<String, dynamic>.from(board as Map)),
            )
            .toList();
      } on FormatException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not restore photo boards: $error')),
          );
        }
      } on TypeError catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not restore photo boards: $error')),
          );
        }
      }
    }
    MoodStatus? loadedMoodStatus;
    final storedMoodStatus = prefs.getString('mood_status');
    if (storedMoodStatus != null) {
      try {
        final decoded = jsonDecode(storedMoodStatus);
        if (decoded is! Map) {
          throw const FormatException('Stored mood status is not an object.');
        }
        loadedMoodStatus = MoodStatus.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        if (loadedMoodStatus.isExpired) {
          loadedMoodStatus = null;
          await prefs.remove('mood_status');
        }
      } on FormatException catch (error) {
        await prefs.remove('mood_status');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not restore your status: $error')),
          );
        }
      } on TypeError catch (error) {
        await prefs.remove('mood_status');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not restore your status: $error')),
          );
        }
      }
    }
    final String? storedData = prefs.getString('saved_posts');

    if (storedData != null) {
      try {
        final decoded = jsonDecode(storedData);
        posts = _parsePostsSafely(decoded);
      } catch (e) {
        posts = _defaultPosts();
      }
    } else {
      posts = _defaultPosts();
      _savePosts();
    }

    notifications = [
      {
        'user': '@sarah',
        'action': 'liked your post in Tokyo',
        'time': '2m ago',
      },
      {
        'user': '@dev_guru',
        'action': 'commented: "Awesome UI design!"',
        'time': '15m ago',
      },
    ];

    directMessages = {
      '@sarah': [
        {
          'sender': '@sarah',
          'text': 'Hey Alex! The global feed ticker looks awesome!',
        },
        {'sender': '@alex', 'text': 'Thanks! Global reach is live now.'},
      ],
    };

    setState(() {
      myUsername = prefs.getString('my_username') ?? '@alex';
      myBio =
          prefs.getString('my_bio') ??
          'Building apps, breaking bugs, shipping code. 🚀';
      myBadge = prefs.getString('my_badge') ?? '⚡ Founder';
      followerCount = prefs.getInt('my_followers') ?? 142;
      followingCount = prefs.getInt('my_following') ?? 89;
      moodStatus = loadedMoodStatus;
      photoBoards = loadedPhotoBoards;
      isLoading = false;
    });
    _scheduleMoodStatusExpiry(loadedMoodStatus);
  }

  List<Map<String, dynamic>> _defaultPosts() {
    return [
      {
        'id': '1',
        'username': '@alex',
        'badge': '⚡ Founder',
        'region': 'Global',
        'category': 'Tech',
        'isPinned': true,
        'repostedBy': null,
        'content': 'Welcome to #Quexdc Global! Switch regions, translate posts, and check out the leaderboards!',
        'translatedContent':
            'Quexdc グローバルへようこそ！リージョンを切り替えて投稿を翻訳し、リーダーボードをチェックしよう！',
        'imagePath': null,
        'webUrl': 'https://flutter.dev',
        'hasAudio': true,
        'audioTitle': 'Quexdc Voice Note #1',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'comments': ['The global ticker is super slick!'],
        'isLiked': false,
        'likeCount': 94,
        'isBookmarked': false,
        'poll': {
          'optionA': 'Tokyo Hub 🎌',
          'votesA': 62,
          'optionB': 'Silicon Valley 🚀',
          'votesB': 41,
          'userVoted': null,
        },
      },
    ];
  }

  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(posts);
    await prefs.setString('saved_posts', encodedData);
  }

  Future<void> _updateProfile(
    String newUsername,
    String newBio,
    String newBadge,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myUsername = newUsername.startsWith('@') ? newUsername : '@$newUsername';
      myBio = newBio;
      myBadge = newBadge;
    });
    await prefs.setString('my_username', myUsername);
    await prefs.setString('my_bio', myBio);
    await prefs.setString('my_badge', myBadge);
  }

  Future<void> _updateMoodStatus(MoodStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mood_status', jsonEncode(status.toJson()));
    if (!mounted) return;
    setState(() => moodStatus = status);
    _scheduleMoodStatusExpiry(status);
  }

  Future<void> _savePhotoBoards(List<PhotoBoard> updatedBoards) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      'photo_boards',
      jsonEncode(updatedBoards.map((board) => board.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('The device declined to save the photo boards.');
    }
    if (!mounted) return;
    setState(() => photoBoards = updatedBoards);
  }

  Future<void> _playLikeSound() async {
    try {
      await _soundStudio.playTrigger(SoundTrigger.like);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play the like sound: $error')),
        );
      }
    }
  }

  void _openDimensionPortal(String trigger) {
    setState(() => _currentIndex = 8);
    Quexdc.of(context)?.setDimensionAccent(const Color(0xFF8A65F2));
    unawaited(_playPortalSound());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${SoundTrigger.label(trigger)} opened a portal.'),
      ),
    );
  }

  void _openEasterEggHunt(EasterEggPlacement placement) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EasterEggHuntScreen(store: _easterStore, placement: placement),
      ),
    );
  }

  void _openWelcomeMontage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WelcomeMontageScreen(
          onExplore: (destination) {
            setState(() {
              _currentIndex = switch (destination) {
                WelcomeDestination.feed => 0,
                WelcomeDestination.boards => 1,
                WelcomeDestination.spaces => 8,
              };
            });
            Navigator.of(context).pop();
          },
          onLookAround: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _openEasterShop() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EasterShopScreen(
          store: _easterStore,
          onItemApplied: _applyEasterShopItem,
        ),
      ),
    );
  }

  Future<void> _applyEasterShopItem(EasterShopItem item) async {
    switch (item.type) {
      case EasterShopItemType.theme:
        final color = item.color;
        if (color == null) {
          throw StateError('This theme does not have a color configured.');
        }
        Quexdc.of(context)?.changeAccentColor(color);
      case EasterShopItemType.badge:
        final badge = item.badgeLabel;
        if (badge == null) {
          throw StateError('This badge does not have a label configured.');
        }
        await _updateProfile(myUsername, myBio, badge);
      case EasterShopItemType.sound:
        final soundId = item.soundId;
        if (soundId == null) {
          throw StateError('This sound does not have a sound configured.');
        }
        await _soundStudio.assignSound(SoundTrigger.portal, soundId);
    }
  }

  Future<void> _playPortalSound() async {
    try {
      await _soundStudio.playTrigger(SoundTrigger.portal);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play the portal sound: $error')),
        );
      }
    }
  }

  Future<String> _handleVoiceCommand(VoiceCommand command) async {
    const destinations = {
      'feed': (0, 'Feed'),
      'boards': (1, 'Inspiration Boards'),
      'sound': (2, 'Sound Studio'),
      'search': (3, 'Search'),
      'ranking': (4, 'Ranking'),
      'notifications': (5, 'Notifications'),
      'profile': (6, 'Profile'),
      'dimension': (8, 'Community Spaces'),
    };
    switch (command.type) {
      case VoiceCommandType.navigate:
        final destination = destinations[command.target];
        if (destination == null) {
          return 'I couldn’t find that section.';
        }
        setState(() {
          _currentIndex = destination.$1;
          if (_currentIndex == 5) unreadNotificationsCount = 0;
        });
        return 'Opening ${destination.$2}.';
      case VoiceCommandType.previewSound:
        await _soundStudio.playSound(command.target);
        final sound = _soundStudio.settings.availableSounds
            .where((item) => item.id == command.target)
            .firstOrNull;
        return sound == null ? 'Playing sound.' : 'Playing ${sound.name}.';
      case VoiceCommandType.openSoundSettings:
        setState(() => _currentIndex = 2);
        return command.target == 'motion'
            ? 'Sound Studio is open. Tap the Motion Snap switch to enable it.'
            : 'Sound Studio is open. Tap the microphone switch to enable listening.';
      case VoiceCommandType.enableWakePhrase:
      case VoiceCommandType.disableWakePhrase:
      case VoiceCommandType.help:
      case VoiceCommandType.unknown:
        return 'I can’t do that yet.';
    }
  }

  Future<void> toggleBetaStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isBetaTester = !isBetaTester;
    });
    await prefs.setBool('is_beta_tester', isBetaTester);
  }

  void _addNotification(String action) {
    setState(() {
      notifications.insert(0, {
        'user': myUsername,
        'action': action,
        'time': 'Just now',
      });
      unreadNotificationsCount++;
    });
  }

  void _triggerLocalPushAlert() {
    setState(() {
      notifications.insert(0, {
        'user': '🛡️ [Quest Reminder]',
        'action': 'Time to defeat your real-life dragon today!',
        'time': 'Just now',
      });
      unreadNotificationsCount++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔔 Simulated Push Alert sent to Notifications tab!'),
      ),
    );
  }

  void _sendDirectMessage(
    String handle,
    String text, {
    String memoStyle = 'plain',
  }) {
    setState(() {
      if (!directMessages.containsKey(handle)) {
        directMessages[handle] = [];
      }
      directMessages[handle]!.add({
        'sender': myUsername,
        'text': text,
        'memoStyle': memoStyle,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      FeedTab(
        posts: posts,
        myUsername: myUsername,
        myBadge: myBadge,
        isLoading: isLoading,
        onOpenWelcomeMontage: _openWelcomeMontage,
        onOpenEasterEggs: _openEasterEggHunt,
        onOpenEasterShop: _openEasterShop,
        onPostsUpdated: (updatedPosts) {
          setState(() {
            posts = updatedPosts;
          });
          _savePosts();
        },
        onActionTriggered: _addNotification,
        onOpenDM: (handle) => _showDMSheet(context, handle),
        onLikeSound: _playLikeSound,
      ),
      VisualBoardsScreen(
        boards: photoBoards,
        onBoardsChanged: _savePhotoBoards,
        onFindEasterEgg: () => _openEasterEggHunt(EasterEggPlacement.boards),
      ),
      SoundStudioScreen(
        controller: _soundStudio,
        onPortalTrigger: _openDimensionPortal,
      ),
      GlobalSearchTab(
        posts: posts,
        onHashtagSelected: (tag) {
          setState(() {
            _currentIndex = 0;
          });
        },
        onUserSelected: (handle) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                username: handle,
                allPosts: posts,
                onOpenDM: (h) => _showDMSheet(context, h),
              ),
            ),
          );
        },
      ),
      isBetaTester
          ? QuestLogTab(onOpenEasterShop: _openEasterShop)
          : const GlobalLeaderboardTab(),
      NotificationsTab(
        notifications: notifications,
        onOpened: () {
          setState(() {
            unreadNotificationsCount = 0;
          });
        },
      ),
      ProfileTab(
        username: myUsername,
        bio: myBio,
        badge: myBadge,
        followerCount: followerCount,
        followingCount: followingCount,
        allPosts: posts,
        isBetaTester: isBetaTester,
        onToggleBeta: toggleBetaStatus,
        onProfileUpdated: _updateProfile,
        onTestAlert: _triggerLocalPushAlert,
        moodStatus: moodStatus,
        onMoodStatusUpdated: _updateMoodStatus,
      ),
      VoiceAssistantScreen(controller: _voiceAssistant),
      EscapeDimensionsScreen(
        soundStudio: _soundStudio,
        onExit: () {
          setState(() => _currentIndex = 0);
          Quexdc.of(context)?.setDimensionAccent(null);
        },
        onThemeChanged: (color) =>
            Quexdc.of(context)?.setDimensionAccent(color),
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 5) unreadNotificationsCount = 0;
          });
          if (index != 8) Quexdc.of(context)?.setDimensionAccent(null);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Boards',
          ),
          const NavigationDestination(
            icon: Icon(Icons.graphic_eq),
            selectedIcon: Icon(Icons.music_note),
            label: 'Sound',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(
              isBetaTester
                  ? Icons.military_tech_outlined
                  : Icons.leaderboard_outlined,
            ),
            selectedIcon: Icon(
              isBetaTester ? Icons.military_tech : Icons.leaderboard,
            ),
            label: isBetaTester ? 'Quests' : 'Ranking',
          ),
          NavigationDestination(
            icon: unreadNotificationsCount > 0
                ? Badge(
                    label: Text('$unreadNotificationsCount'),
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          const NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Qué',
          ),
          const NavigationDestination(
            icon: Icon(Icons.blur_on_outlined),
            selectedIcon: Icon(Icons.blur_on),
            label: 'Spaces',
          ),
        ],
      ),
    );
  }

  void _showDMSheet(BuildContext context, String recipientHandle) {
    final TextEditingController msgController = TextEditingController();
    var selectedMemoStyle = 'plain';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            List<Map<String, dynamic>> chatHistory =
                directMessages[recipientHandle] ?? [];

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: 450,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary,
                          child: Text(
                            recipientHandle
                                .replaceAll('@', '')[0]
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Chat with $recipientHandle',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text(
                      'Local prototype · memos are not encrypted or shared.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Expanded(
                      child: chatHistory.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet. Send a DM!',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: chatHistory.length,
                              itemBuilder: (context, idx) {
                                final msg = chatHistory[idx];
                                bool isMe = msg['sender'] == myUsername;
                                final memoStyle =
                                    msg['memoStyle']?.toString() ?? 'plain';
                                final isMysticule = memoStyle == 'mysticule';
                                final backgroundColor = switch (memoStyle) {
                                  'aero' => const Color(
                                    0xFF35C9C1,
                                  ).withValues(alpha: 0.24),
                                  'weirdcore' => const Color(
                                    0xFF8A65F2,
                                  ).withValues(alpha: 0.26),
                                  'mysticule' => const Color(0xFF30205C),
                                  _ =>
                                    isMe
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.withValues(alpha: 0.2),
                                };
                                return Align(
                                  alignment: isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      gradient: isMysticule
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF30205C),
                                                Color(0xFF16445C),
                                              ],
                                            )
                                          : null,
                                      border: memoStyle == 'weirdcore'
                                          ? Border.all(
                                              color: const Color(0xFFDB8BDD),
                                              width: 1.5,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      msg['text']!,
                                      style: TextStyle(
                                        color: isMysticule
                                            ? Colors.white
                                            : Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Choose memo style',
                          icon: const Icon(Icons.sticky_note_2_outlined),
                          onSelected: (style) {
                            setSheetState(() => selectedMemoStyle = style);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'plain',
                              child: Text('Plain message'),
                            ),
                            PopupMenuItem(
                              value: 'aero',
                              child: Text('Frutiger Aero memo'),
                            ),
                            PopupMenuItem(
                              value: 'weirdcore',
                              child: Text('Weirdcore memo'),
                            ),
                            PopupMenuItem(
                              value: 'mysticule',
                              child: Text('Mysticule memo'),
                            ),
                          ],
                        ),
                        Expanded(
                          child: TextField(
                            controller: msgController,
                            decoration: const InputDecoration(
                              hintText: 'Write a memo...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.send,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () {
                            if (msgController.text.trim().isNotEmpty) {
                              _sendDirectMessage(
                                recipientHandle,
                                msgController.text.trim(),
                                memoStyle: selectedMemoStyle,
                              );
                              msgController.clear();
                              setSheetState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- CLOUD BAR WITH COMPANIONS (YoYo, ZoZo & XoXo) ---
class CloudBarCompanionsHeader extends StatelessWidget {
  const CloudBarCompanionsHeader({
    super.key,
    required this.onOpenEasterEggs,
    required this.onOpenEasterShop,
  });

  final ValueChanged<EasterEggPlacement> onOpenEasterEggs;
  final VoidCallback onOpenEasterShop;

  void _openMarketplace(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MarketplaceHubScreen(
          onOpenEasterShop: onOpenEasterShop,
          onApplyAccent: (color) {
            Quexdc.of(context)?.changeAccentColor(color);
          },
          onApplyFont: (font) async {
            final app = Quexdc.of(context);
            if (app == null) {
              throw StateError('The app font settings are unavailable.');
            }
            await app.applyCommunityFont(font);
          },
        ),
      ),
    );
  }

  void _showMarketplaceGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('XoXo Marketplace Guide'),
        content: const Text(
          'XoXo can help you explore creator-made fonts, themes, and badges. '
          'Open the Marketplace to browse what is available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openMarketplace(context);
            },
            child: const Text('Explore Marketplace'),
          ),
        ],
      ),
    );
  }

  void _openCompanionStudio(BuildContext context, String name, Color color) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Text(
                  name[0],
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Text('$name Companion Studio'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: Active in Cloud Bar',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Configure custom companion status badge or toggle automated reactions for this meta bot.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onOpenEasterEggs(EasterEggPlacement.companion);
                },
                icon: const Icon(Icons.egg_outlined),
                label: const Text('Find a hidden video'),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Custom Status Message',
                  hintText: 'e.g., Idle in Shibuya',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name settings updated successfully!'),
                  ),
                );
              },
              child: const Text('Save Mod'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
      child: Row(
        children: [
          const Icon(Icons.cloud_queue, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          const Text(
            'Cloud Bar:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () =>
                _openCompanionStudio(context, 'YoYo', Colors.blueAccent),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '🤖 YoYo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _openCompanionStudio(context, 'ZoZo', Colors.green),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '👾 ZoZo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _showMarketplaceGuide(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '✨ XoXo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.purpleAccent,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _openMarketplace(context),
            tooltip: 'Open Marketplace',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.storefront_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

// --- LIVE GLOBAL TICKER BANNER ---
class LiveGlobalTicker extends StatefulWidget {
  const LiveGlobalTicker({super.key});

  @override
  State<LiveGlobalTicker> createState() => _LiveGlobalTickerState();
}

class _LiveGlobalTickerState extends State<LiveGlobalTicker> {
  final List<String> tickerItems = [
    '🌏 @kenji just joined from Tokyo',
    '🚀 @elena published a hack in Berlin',
    '⚡ @alex pinned a new global roadmap',
    '🔥 @sarah achieved Pioneer Rank #2 in Silicon Valley',
  ];
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), _rotateTicker);
  }

  void _rotateTicker() {
    if (mounted) {
      setState(() {
        currentIndex = (currentIndex + 1) % tickerItems.length;
      });
      Future.delayed(const Duration(seconds: 4), _rotateTicker);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Text(
          tickerItems[currentIndex],
          key: ValueKey<int>(currentIndex),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// --- GLOBAL LEADERBOARD TAB ---
class GlobalLeaderboardTab extends StatelessWidget {
  const GlobalLeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> topCreators = [
      {
        'rank': 1,
        'name': '@alex',
        'title': '⚡ Founder',
        'xp': '12,450 XP',
        'followers': '142',
        'badge': '🥇',
      },
      {
        'rank': 2,
        'name': '@sarah',
        'title': '✨ Pioneer',
        'xp': '9,820 XP',
        'followers': '1.2k',
        'badge': '🥈',
      },
      {
        'rank': 3,
        'name': '@kenji',
        'title': '🗾 Tokyo Dev',
        'xp': '8,100 XP',
        'followers': '890',
        'badge': '🥉',
      },
      {
        'rank': 4,
        'name': '@elena',
        'title': '💻 Hacker',
        'xp': '6,400 XP',
        'followers': '540',
        'badge': '⭐',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Global Pioneer Ranking 🌍',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  const Color(0xFF9333EA),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Creator Standings',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Rankings update live based on XP & engagement',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...topCreators.map(
            (creator) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary
                      .withOpacity(0.2),
                  child: Text(
                    creator['badge'],
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      creator['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      creator['title'],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                subtitle: Text('${creator['followers']} followers'),
                trailing: Text(
                  creator['xp'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsTab extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final VoidCallback onOpened;

  const NotificationsTab({
    super.key,
    required this.notifications,
    required this.onOpened,
  });

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOpened();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: widget.notifications.isEmpty
          ? const Center(
              child: Text(
                'No new notifications.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: widget.notifications.length,
              itemBuilder: (context, index) {
                final item = widget.notifications[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      children: [
                        TextSpan(
                          text: '${item['user']} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: item['action']),
                      ],
                    ),
                  ),
                  subtitle: Text(
                    item['time'],
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}

class QuestLogTab extends StatefulWidget {
  const QuestLogTab({super.key, required this.onOpenEasterShop});

  final VoidCallback onOpenEasterShop;

  @override
  State<QuestLogTab> createState() => _QuestLogTabState();
}

class _QuestLogTabState extends State<QuestLogTab> {
  final EasterEconomyStore _easterStore = EasterEconomyStore();
  EasterEconomySnapshot _easterSnapshot = const EasterEconomySnapshot();
  bool _isLoadingEasterProgress = true;
  int _questStreakRevision = 0;

  final List<Map<String, dynamic>> quests = [
    {
      'id': 'real_life_dragon',
      'title': 'Defeat a Dragon in Real Life',
      'xp': 1000,
      'eggPoints': 20,
      'completed': false,
      'desc': 'Conquer your biggest daily task or project milestone.',
    },
    {
      'id': 'micro_browser',
      'title': 'Explore the Micro-Browser',
      'xp': 150,
      'eggPoints': 10,
      'completed': true,
      'desc': 'Open an external URL inside Quexdc.',
    },
    {
      'id': 'first_code_snippet',
      'title': 'Publish First Code Snippet',
      'xp': 300,
      'eggPoints': 15,
      'completed': false,
      'desc': 'Share a technical update with the community.',
    },
    {
      'id': 'night_owl_session',
      'title': 'Night Owl Coding Session',
      'xp': 500,
      'eggPoints': 15,
      'completed': false,
      'desc': 'Commit code past midnight.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadEasterProgress();
  }

  Future<void> _loadEasterProgress() async {
    try {
      var snapshot = await _easterStore.load();
      if (!snapshot.hasProgress) {
        for (final quest in quests.where(
          (quest) => quest['completed'] == true,
        )) {
          snapshot = await _easterStore.completeQuest(
            quest['id'] as String,
            points: quest['eggPoints'] as int,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _easterSnapshot = snapshot;
        for (final quest in quests) {
          quest['completed'] = snapshot.completedQuestIds.contains(quest['id']);
        }
        _isLoadingEasterProgress = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingEasterProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load Easter Points: $error')),
      );
    }
  }

  Future<void> _setQuestCompleted(int index, bool completed) async {
    final quest = quests[index];
    try {
      final snapshot = completed
          ? await _easterStore.completeQuest(
              quest['id'] as String,
              points: quest['eggPoints'] as int,
            )
          : await _easterStore.uncompleteQuest(quest['id'] as String);
      Object? streakError;
      if (completed) {
        try {
          await QuestStreakStore.recordActivity(QuestStreakStore.questKey);
        } catch (error) {
          streakError = error;
        }
      }
      if (!mounted) return;
      setState(() {
        quest['completed'] = completed;
        _easterSnapshot = snapshot;
        if (completed) _questStreakRevision++;
      });
      if (streakError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Quest completed, but its streak was not updated: $streakError',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update this quest: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalXp = quests
        .where((q) => q['completed'] == true)
        .fold(0, (sum, item) => sum + (item['xp'] as int));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Beta Quest Log 🛡️',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Open Easter Shop',
            onPressed: _isLoadingEasterProgress
                ? null
                : widget.onOpenEasterShop,
            icon: const Icon(Icons.storefront_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  const Color(0xFF9333EA),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pioneer Level 2',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Beta Quest Master',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Text(
                    '$totalXp XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.egg_alt_outlined),
              title: Text(
                _isLoadingEasterProgress
                    ? 'Loading Easter Points...'
                    : '${_easterSnapshot.points} Easter Points',
              ),
              subtitle: const Text(
                'Earn points from quests and spend them on stage accents.',
              ),
              trailing: TextButton(
                onPressed: _isLoadingEasterProgress
                    ? null
                    : widget.onOpenEasterShop,
                child: const Text('Easter Shop'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          StreakDashboard(
            key: ValueKey(_questStreakRevision),
            economy: _easterStore,
          ),
          const SponsorQuestDemoCard(),
          const SizedBox(height: 12),
          const Text(
            'Active Real-World Quests',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          ...quests.asMap().entries.map((entry) {
            int index = entry.key;
            var quest = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.indigo.withOpacity(0.15)),
              ),
              child: CheckboxListTile(
                title: Text(
                  quest['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: quest['completed']
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  '${quest['desc']}\nReward: +${quest['xp']} XP · '
                  '+${quest['eggPoints']} Easter Points',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
                value: quest['completed'],
                onChanged: _isLoadingEasterProgress
                    ? null
                    : (val) => _setQuestCompleted(index, val ?? false),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class FeedTab extends StatefulWidget {
  const FeedTab({
    super.key,
    required this.posts,
    required this.myUsername,
    required this.myBadge,
    required this.isLoading,
    required this.onOpenWelcomeMontage,
    required this.onOpenEasterEggs,
    required this.onOpenEasterShop,
    required this.onPostsUpdated,
    required this.onActionTriggered,
    required this.onOpenDM,
    required this.onLikeSound,
  });

  final List<Map<String, dynamic>> posts;
  final String myUsername;
  final String myBadge;
  final bool isLoading;
  final VoidCallback onOpenWelcomeMontage;
  final ValueChanged<EasterEggPlacement> onOpenEasterEggs;
  final VoidCallback onOpenEasterShop;
  final Function(List<Map<String, dynamic>>) onPostsUpdated;
  final Function(String) onActionTriggered;
  final Function(String) onOpenDM;
  final Future<void> Function() onLikeSound;

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  String selectedCategory = 'All';
  String selectedRegion = 'Global';
  SocialPreferences _socialPreferences = const SocialPreferences();
  bool _showForYou = false;

  // Real-time active user counts per region
  final Map<String, int> regionOnlineCounts = {
    'Global': 1420,
    'Silicon Valley': 632,
    'Tokyo': 415,
    'London': 210,
    'Berlin': 163,
  };

  @override
  void initState() {
    super.initState();
    _loadSocialPreferences();
  }

  Future<void> _loadSocialPreferences() async {
    try {
      final preferences = await SocialExperienceStore.loadPreferences();
      if (!mounted) return;
      setState(() {
        _socialPreferences = preferences;
        _showForYou = preferences.personalizedFeed;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load feed preferences: $error')),
      );
    }
  }

  Future<void> _openSocialPreferences() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SocialPreferencesScreen()),
    );
    await _loadSocialPreferences();
  }

  Future<String?> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    return image?.path;
  }

  void _openPollAnalyticsHistory(BuildContext context) {
    final pollsList = widget.posts.where((p) => p['poll'] != null).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: Colors.indigoAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Poll Analytics History 📊',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Track voting engagement across all global community polls.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Divider(height: 24),
              Expanded(
                child: pollsList.isEmpty
                    ? const Center(
                        child: Text(
                          'No active or historical polls found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: pollsList.length,
                        itemBuilder: (context, idx) {
                          final post = pollsList[idx];
                          final poll = post['poll'] as Map<String, dynamic>;
                          int vA = poll['votesA'] ?? 0;
                          int vB = poll['votesB'] ?? 0;
                          int total = vA + vB;
                          double pctA = total == 0 ? 0 : vA / total;
                          double pctB = total == 0 ? 0 : vB / total;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        post['username'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$total total votes',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${poll['optionA']} ($vA votes)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: pctA,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${poll['optionB']} ($vB votes)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: pctB,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addPost() async {
    final prefs = await SharedPreferences.getInstance();
    final String savedDraft = prefs.getString('post_draft') ?? '';

    final TextEditingController userController = TextEditingController(
      text: widget.myUsername,
    );
    final TextEditingController contentController = TextEditingController(
      text: savedDraft,
    );
    final TextEditingController urlController = TextEditingController();
    final TextEditingController optAController = TextEditingController();
    final TextEditingController optBController = TextEditingController();

    String chosenCategory = 'Tech';
    String chosenRegion = selectedRegion == 'Global'
        ? 'Silicon Valley'
        : selectedRegion;
    String? pickedImagePath;
    bool includePoll = false;
    bool includeAudio = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: userController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: '@yourhandle',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: chosenCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: ['Tech', 'Design', 'Memes', 'Hacks'].map((
                              cat,
                            ) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null)
                                setDialogState(() => chosenCategory = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: chosenRegion,
                            decoration: const InputDecoration(
                              labelText: 'Region',
                            ),
                            items:
                                [
                                  'Silicon Valley',
                                  'Tokyo',
                                  'London',
                                  'Berlin',
                                ].map((reg) {
                                  return DropdownMenuItem(
                                    value: reg,
                                    child: Text(reg),
                                  );
                                }).toList(),
                            onChanged: (val) {
                              if (val != null)
                                setDialogState(() => chosenRegion = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      onChanged: (val) => prefs.setString('post_draft', val),
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        hintText: 'What\'s on your mind? Use #tags!',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'Attach Web Link',
                        hintText: 'https://example.com',
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text(
                        'Attach Audio Note 🎵',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: includeAudio,
                      onChanged: (val) =>
                          setDialogState(() => includeAudio = val == true),
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Add Interactive Poll',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: includePoll,
                      onChanged: (val) =>
                          setDialogState(() => includePoll = val),
                    ),
                    if (includePoll) ...[
                      TextField(
                        controller: optAController,
                        decoration: const InputDecoration(
                          labelText: 'Poll Option A',
                          hintText: 'Option 1',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: optBController,
                        decoration: const InputDecoration(
                          labelText: 'Poll Option B',
                          hintText: 'Option 2',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (pickedImagePath != null)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: kIsWeb
                                    ? NetworkImage(pickedImagePath!)
                                          as ImageProvider
                                    : FileImage(File(pickedImagePath!)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () =>
                                setDialogState(() => pickedImagePath = null),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () async {
                          String? path = await _pickImage();
                          if (path != null)
                            setDialogState(() => pickedImagePath = path);
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Add Photo from Gallery'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (contentController.text.trim().isNotEmpty ||
                        pickedImagePath != null ||
                        urlController.text.isNotEmpty) {
                      List<Map<String, dynamic>> updated = List.from(
                        widget.posts,
                      );

                      Map<String, dynamic>? pollData;
                      if (includePoll &&
                          optAController.text.isNotEmpty &&
                          optBController.text.isNotEmpty) {
                        pollData = {
                          'optionA': optAController.text.trim(),
                          'votesA': 0,
                          'optionB': optBController.text.trim(),
                          'votesB': 0,
                          'userVoted': null,
                        };
                      }

                      updated.insert(0, {
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'username': userController.text.trim().startsWith('@')
                            ? userController.text.trim()
                            : '@${userController.text.trim()}',
                        'badge': widget.myBadge,
                        'region': chosenRegion,
                        'category': chosenCategory,
                        'isPinned': false,
                        'repostedBy': null,
                        'content': contentController.text.trim(),
                        'translatedContent':
                            'Quexdc Global Trans: ${contentController.text.trim()}',
                        'imagePath': pickedImagePath,
                        'webUrl': urlController.text.trim().isNotEmpty
                            ? urlController.text.trim()
                            : null,
                        'hasAudio': includeAudio,
                        'audioTitle': includeAudio ? 'Quexdc Audio Note' : null,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                        'comments': <String>[],
                        'isLiked': false,
                        'likeCount': 0,
                        'isBookmarked': false,
                        'poll': pollData,
                      });

                      prefs.remove('post_draft');
                      widget.onPostsUpdated(updated);
                      widget.onActionTriggered(
                        'created a post in $chosenRegion',
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _repost(Map<String, dynamic> originalPost, int originalIndex) {
    List<Map<String, dynamic>> updated = List.from(widget.posts);
    updated.insert(0, {
      ...originalPost,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'repostedBy': widget.myUsername,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    widget.onPostsUpdated(updated);
    widget.onActionTriggered('reposted a post');
  }

  void _showThemeSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Theme Accent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF6366F1)),
                title: const Text('Indigo Classic'),
                onTap: () {
                  Quexdc.of(context)
                      ?.changeAccentColor(const Color(0xFF6366F1));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF9333EA)),
                title: const Text('Cyberpunk Neon'),
                onTap: () {
                  Quexdc.of(context)
                      ?.changeAccentColor(const Color(0xFF9333EA));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF059669)),
                title: const Text('Emerald Green'),
                onTap: () {
                  Quexdc.of(context)
                      ?.changeAccentColor(const Color(0xFF059669));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Use default font'),
                onTap: () async {
                  await Quexdc.of(context)?.resetCommunityFont();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final regionCategoryPosts = widget.posts.where((p) {
      bool catMatch =
          selectedCategory == 'All' || p['category'] == selectedCategory;
      bool regMatch =
          selectedRegion == 'Global' || p['region'] == selectedRegion;
      return catMatch && regMatch;
    }).toList();
    final filteredPosts = _showForYou && _socialPreferences.personalizedFeed
        ? rankPostsForYou(regionCategoryPosts, _socialPreferences.interests)
        : regionCategoryPosts;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quexdc',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Welcome to Quexdc',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: widget.onOpenWelcomeMontage,
          ),
          IconButton(
            tooltip: 'Find a hidden video',
            icon: const Icon(Icons.egg_outlined),
            onPressed: () => widget.onOpenEasterEggs(EasterEggPlacement.region),
          ),
          IconButton(
            tooltip: 'Feed and privacy controls',
            icon: const Icon(Icons.tune),
            onPressed: _openSocialPreferences,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => _openPollAnalyticsHistory(context),
            tooltip: 'Poll Analytics History',
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => _showThemeSettingsDialog(context),
            tooltip: 'Change Theme Accent',
          ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => Quexdc.of(context)?.toggleTheme(),
            tooltip: 'Toggle Theme Mode',
          ),
        ],
      ),
      body: widget.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const LiveGlobalTicker(),
                SocialStoriesStrip(username: widget.myUsername),
                CloudBarCompanionsHeader(
                  onOpenEasterEggs: widget.onOpenEasterEggs,
                  onOpenEasterShop: widget.onOpenEasterShop,
                ),
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _socialPreferences.personalizedFeed
                          ? SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Latest'),
                                  icon: Icon(Icons.schedule),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('For You'),
                                  icon: Icon(Icons.auto_awesome),
                                ),
                              ],
                              selected: {_showForYou},
                              onSelectionChanged: (selection) {
                                setState(() => _showForYou = selection.first);
                              },
                            )
                          : TextButton.icon(
                              onPressed: _openSocialPreferences,
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('Set up For You'),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    children:
                        [
                          'Global',
                          'Silicon Valley',
                          'Tokyo',
                          'London',
                          'Berlin',
                        ].map((reg) {
                          bool isSelected = selectedRegion == reg;
                          int onlineCount = regionOnlineCounts[reg] ?? 100;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              avatar: Icon(
                                reg == 'Global'
                                    ? Icons.public
                                    : Icons.location_on,
                                size: 14,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                              label: Text(
                                '$reg ($onlineCount)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  selectedRegion = reg;
                                });
                              },
                            ),
                          );
                        }).toList(),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    children: ['All', 'Tech', 'Design', 'Memes', 'Hacks'].map((
                      cat,
                    ) {
                      bool isSelected = selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selectedCategory = cat;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: filteredPosts.isEmpty
                      ? const Center(
                          child: Text(
                            'No posts found in this region.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredPosts.length,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) {
                            final originalIndex = widget.posts.indexOf(
                              filteredPosts[index],
                            );
                            return PostCard(
                              post: filteredPosts[index],
                              onUsernameTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                      username:
                                          filteredPosts[index]['username'],
                                      allPosts: widget.posts,
                                      onOpenDM: widget.onOpenDM,
                                    ),
                                  ),
                                );
                              },
                              onEdit: () {},
                              onDelete: () {
                                List<Map<String, dynamic>> updated = List.from(
                                  widget.posts,
                                );
                                updated.removeAt(originalIndex);
                                widget.onPostsUpdated(updated);
                              },
                              onPinToggle: () {
                                List<Map<String, dynamic>> updated = List.from(
                                  widget.posts,
                                );
                                updated[originalIndex]['isPinned'] =
                                    !(updated[originalIndex]['isPinned'] ==
                                        true);
                                widget.onPostsUpdated(updated);
                              },
                              onLikeToggle: (newIsLiked, newCount) {
                                List<Map<String, dynamic>> updated = List.from(
                                  widget.posts,
                                );
                                updated[originalIndex]['isLiked'] = newIsLiked;
                                updated[originalIndex]['likeCount'] = newCount;
                                widget.onPostsUpdated(updated);
                                if (newIsLiked) {
                                  widget.onActionTriggered('liked a post');
                                  unawaited(widget.onLikeSound());
                                }
                              },
                              onBookmarkToggle: (newIsBookmarked) {
                                List<Map<String, dynamic>> updated = List.from(
                                  widget.posts,
                                );
                                updated[originalIndex]['isBookmarked'] =
                                    newIsBookmarked;
                                widget.onPostsUpdated(updated);
                              },
                              onHashtagTap: (tag) {},
                              onRepostTap: () =>
                                  _repost(filteredPosts[index], originalIndex),
                              onPollVote: (option) {
                                List<Map<String, dynamic>> updated = List.from(
                                  widget.posts,
                                );
                                final poll = Map<String, dynamic>.from(
                                  updated[originalIndex]['poll'],
                                );
                                if (poll['userVoted'] == null) {
                                  poll['userVoted'] = option;
                                  if (option == 'A')
                                    poll['votesA'] = (poll['votesA'] ?? 0) + 1;
                                  if (option == 'B')
                                    poll['votesB'] = (poll['votesB'] ?? 0) + 1;
                                  updated[originalIndex]['poll'] = poll;
                                  widget.onPostsUpdated(updated);
                                }
                              },
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailScreen(
                                      post: filteredPosts[index],
                                      onCommentAdded: (updatedComments) {
                                        List<Map<String, dynamic>> updated =
                                            List.from(widget.posts);
                                        updated[originalIndex]['comments'] =
                                            updatedComments;
                                        widget.onPostsUpdated(updated);
                                        widget.onActionTriggered(
                                          'commented on a post',
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPost,
        icon: const Icon(Icons.add),
        label: const Text('New Post'),
      ),
    );
  }
}

class GlobalSearchTab extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final Function(String) onHashtagSelected;
  final Function(String) onUserSelected;

  const GlobalSearchTab({
    super.key,
    required this.posts,
    required this.onHashtagSelected,
    required this.onUserSelected,
  });

  @override
  State<GlobalSearchTab> createState() => _GlobalSearchTabState();
}

class _GlobalSearchTabState extends State<GlobalSearchTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        query = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchingPosts = widget.posts
        .where((p) => p['content'].toString().toLowerCase().contains(query))
        .toList();
    final matchingUsers = widget.posts
        .map((p) => p['username'].toString())
        .toSet()
        .where((u) => u.toLowerCase().contains(query))
        .toList();
    final trendingTags = [
      '#Quexdc',
      '#Flutter',
      '#1517Fund',
      '#Hackathon',
      '#TokyoDev',
    ].where((t) => t.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search Posts, Users, or Tags...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            border: InputBorder.none,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Users'),
            Tab(text: 'Hashtags'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ListView.builder(
            itemCount: matchingPosts.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(matchingPosts[index]['content']),
                subtitle: Text('By ${matchingPosts[index]['username']}'),
              );
            },
          ),
          ListView.builder(
            itemCount: matchingUsers.length,
            itemBuilder: (context, index) {
              final user = matchingUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(user.replaceAll('@', '')[0].toUpperCase()),
                ),
                title: Text(user),
                onTap: () => widget.onUserSelected(user),
              );
            },
          ),
          ListView.builder(
            itemCount: trendingTags.length,
            itemBuilder: (context, index) {
              final tag = trendingTags[index];
              return ListTile(
                leading: Icon(
                  Icons.tag,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(tag),
                onTap: () => widget.onHashtagSelected(tag),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final Function(bool, int) onLikeToggle;

  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onLikeToggle,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton> {
  bool _isScaled = false;

  void _handleTap() {
    setState(() => _isScaled = true);
    bool newLikedState = !widget.isLiked;
    int newCount = widget.likeCount + (newLikedState ? 1 : -1);
    widget.onLikeToggle(newLikedState, newCount);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _isScaled = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            AnimatedScale(
              scale: _isScaled ? 1.4 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: Icon(
                widget.isLiked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: widget.isLiked ? Colors.redAccent : Colors.grey,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.likeCount}',
              style: TextStyle(
                color: widget.isLiked ? Colors.redAccent : Colors.grey,
                fontSize: 13,
                fontWeight: widget.isLiked
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  final VoidCallback onUsernameTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPinToggle;
  final Function(bool, int) onLikeToggle;
  final Function(bool) onBookmarkToggle;
  final Function(String) onHashtagTap;
  final VoidCallback onRepostTap;
  final Function(String) onPollVote;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onUsernameTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPinToggle,
    required this.onLikeToggle,
    required this.onBookmarkToggle,
    required this.onHashtagTap,
    required this.onRepostTap,
    required this.onPollVote,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool showTranslation = false;

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    int? timeVal = timestamp is int
        ? timestamp
        : int.tryParse(timestamp.toString());
    if (timeVal == null) return 'Recently';

    final now = DateTime.now();
    final postTime = DateTime.fromMillisecondsSinceEpoch(timeVal);
    final diff = now.difference(postTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showShareModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Post',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  Icons.copy,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Copy Post Link'),
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: 'https://quexdc.app/post/${widget.post['id']}',
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post link copied to clipboard!'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.share,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Share Text Content'),
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.post['content']),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post text copied!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPollStatsModal(BuildContext context, Map<String, dynamic> poll) {
    int vA = poll['votesA'] ?? 0;
    int vB = poll['votesB'] ?? 0;
    int total = vA + vB;
    double pctA = total == 0 ? 0 : vA / total;
    double pctB = total == 0 ? 0 : vB / total;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Poll Analytics Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Votes: $total',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                '${poll['optionA']}: $vA votes (${(pctA * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: pctA,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              Text(
                '${poll['optionB']}: $vB votes (${(pctB * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: pctB,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List comments = widget.post['comments'] is List
        ? widget.post['comments']
        : [];
    String? imagePath = widget.post['imagePath'];
    String? webUrl = widget.post['webUrl'];
    bool hasAudio = widget.post['hasAudio'] == true;
    String? repostedBy = widget.post['repostedBy'];
    bool isLiked = widget.post['isLiked'] ?? false;
    int likeCount = widget.post['likeCount'] ?? 0;
    bool isBookmarked = widget.post['isBookmarked'] ?? false;
    bool isPinned = widget.post['isPinned'] == true;
    String timeAgo = _getTimeAgo(widget.post['timestamp']);
    Map<String, dynamic>? poll = widget.post['poll'];
    String category = widget.post['category'] ?? 'Tech';
    String region = widget.post['region'] ?? 'Global';
    String badge = widget.post['badge'] ?? '⚡ Founder';
    String displayContent =
        showTranslation && widget.post['translatedContent'] != null
        ? widget.post['translatedContent']
        : widget.post['content'];

    return InkWell(
      onTap: widget.onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isPinned
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : Colors.indigo.withOpacity(0.12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPinned) ...[
                Row(
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pinned Post',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (repostedBy != null) ...[
                Row(
                  children: [
                    const Icon(Icons.repeat, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$repostedBy reposted',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  InkWell(
                    onTap: widget.onUsernameTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary,
                          child: Text(
                            widget.post['username']
                                .replaceAll('@', '')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.post['username'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badge,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$timeAgo • $region',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (displayContent.isNotEmpty) ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildRichContent(
                    context,
                    displayContent,
                    widget.onHashtagTap,
                    key: ValueKey(showTranslation),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      showTranslation = !showTranslation;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      showTranslation ? 'Show Original' : '🌐 Translate Post',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (webUrl != null) ...[
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MicroBrowserScreen(url: webUrl),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary
                            .withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.language,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            webUrl,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (hasAudio) ...[
                const SimulatedAudioPlayerCard(),
                const SizedBox(height: 12),
              ],
              if (poll != null) ...[
                GestureDetector(
                  onTap: () => _showPollStatsModal(context, poll),
                  child: _buildPollWidget(poll),
                ),
                const SizedBox(height: 12),
              ],
              if (imagePath != null) ...[
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FullScreenImageViewer(imagePath: imagePath),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kLoadImage(
                      imagePath,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  AnimatedLikeButton(
                    isLiked: isLiked,
                    likeCount: likeCount,
                    onLikeToggle: widget.onLikeToggle,
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comments.length}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(
                      Icons.repeat,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: widget.onRepostTap,
                    tooltip: 'Repost',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.share_outlined,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: () => _showShareModal(context),
                    tooltip: 'Share',
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                      color: isPinned
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    onPressed: widget.onPinToggle,
                    tooltip: 'Pin/Unpin Post',
                  ),
                  IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: isBookmarked
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    onPressed: () => widget.onBookmarkToggle(!isBookmarked),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollWidget(Map<String, dynamic> poll) {
    int vA = poll['votesA'] ?? 0;
    int vB = poll['votesB'] ?? 0;
    int total = vA + vB;
    double pctA = total == 0 ? 0 : vA / total;
    double pctB = total == 0 ? 0 : vB / total;
    String? userVoted = poll['userVoted'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => widget.onPollVote('A'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: userVoted == 'A'
                    ? Colors.indigo.withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      poll['optionA'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (userVoted != null)
                    Text('${(pctA * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => widget.onPollVote('B'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: userVoted == 'B'
                    ? Colors.indigo.withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      poll['optionB'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (userVoted != null)
                    Text('${(pctB * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichContent(
    BuildContext context,
    String text,
    Function(String) onHashtagTap, {
    Key? key,
  }) {
    List<String> words = text.split(' ');
    return Wrap(
      key: key,
      children: words.map((word) {
        if (word.startsWith('#')) {
          return InkWell(
            onTap: () => onHashtagTap(word),
            child: Text(
              '$word ',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        return Text('$word ');
      }).toList(),
    );
  }
}

class SimulatedAudioPlayerCard extends StatefulWidget {
  const SimulatedAudioPlayerCard({super.key});

  @override
  State<SimulatedAudioPlayerCard> createState() =>
      _SimulatedAudioPlayerCardState();
}

class _SimulatedAudioPlayerCardState extends State<SimulatedAudioPlayerCard> {
  bool isPlaying = false;
  double progress = 0.3;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: const Color(0xFF9333EA),
              size: 32,
            ),
            onPressed: () {
              setState(() {
                isPlaying = !isPlaying;
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audio Voice Attachment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Slider(
                  value: progress,
                  activeColor: const Color(0xFF9333EA),
                  onChanged: (val) {
                    setState(() {
                      progress = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const Text(
            '0:45',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class MicroBrowserScreen extends StatelessWidget {
  final String url;
  const MicroBrowserScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(url, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.language,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Quexdc Micro-Browser',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Browsing: $url', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return to App'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  final String username;
  final String bio;
  final String badge;
  final int followerCount;
  final int followingCount;
  final List<Map<String, dynamic>> allPosts;
  final bool isBetaTester;
  final VoidCallback onToggleBeta;
  final Function(String, String, String) onProfileUpdated;
  final VoidCallback onTestAlert;
  final MoodStatus? moodStatus;
  final Future<void> Function(MoodStatus) onMoodStatusUpdated;

  const ProfileTab({
    super.key,
    required this.username,
    required this.bio,
    required this.badge,
    required this.followerCount,
    required this.followingCount,
    required this.allPosts,
    required this.isBetaTester,
    required this.onToggleBeta,
    required this.onProfileUpdated,
    required this.onTestAlert,
    required this.moodStatus,
    required this.onMoodStatusUpdated,
  });

  void _showEditProfileDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController(
      text: username,
    );
    final TextEditingController bioController = TextEditingController(
      text: bio,
    );
    String selectedBadge = badge;

    final List<String> availableBadges = [
      '⚡ Founder',
      '✨ Pioneer',
      '🔥 Code Wizard',
      '🚀 Ship Master',
      '🗾 Tokyo Dev',
      '🛡️ Quest Master',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile & Badges'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Username Handle',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioController,
                      decoration: const InputDecoration(labelText: 'Bio'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Achievement Badge Flair:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: availableBadges.map((b) {
                        bool isChosen = selectedBadge == b;
                        return ChoiceChip(
                          label: Text(b, style: const TextStyle(fontSize: 12)),
                          selected: isChosen,
                          onSelected: (selected) {
                            setDialogState(() {
                              selectedBadge = b;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    onProfileUpdated(
                      nameController.text.trim(),
                      bioController.text.trim(),
                      selectedBadge,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPosts = allPosts
        .where((post) => post['username'] == username)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Ideas & beta settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BetaIdeasSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  const Color(0xFF9333EA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      username.replaceAll('@', '').isNotEmpty
                          ? username.replaceAll('@', '')[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        fontSize: 34,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$followingCount Following',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$followerCount Followers',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEditProfileDialog(context),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Profile & Badge'),
                    ),
                    FilledButton.icon(
                      onPressed: onToggleBeta,
                      icon: Icon(
                        isBetaTester ? Icons.verified : Icons.military_tech,
                        size: 16,
                      ),
                      label: Text(isBetaTester ? 'Beta Active' : 'Join Beta'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onTestAlert,
                  icon: const Icon(Icons.notifications_active, size: 16),
                  label: const Text('Test Local Push Reminder'),
                ),
              ],
            ),
          ),
          StatusMoodManager(
            currentStatus: moodStatus,
            onUpdateStatus: onMoodStatusUpdated,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'My Posts (${userPosts.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          CreatorFontsSection(
            creatorName: username,
            onApplyFont: (font) async {
              final app = Quexdc.of(context);
              if (app == null) {
                throw StateError('The app font settings are unavailable.');
              }
              await app.applyCommunityFont(font);
            },
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final String username;
  final List<Map<String, dynamic>> allPosts;
  final Function(String) onOpenDM;

  const ProfileScreen({
    super.key,
    required this.username,
    required this.allPosts,
    required this.onOpenDM,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isFollowing = false;
  int followers = 342;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      widget.username.replaceAll('@', '').isNotEmpty
                          ? widget.username.replaceAll('@', '')[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 34,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.username,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          isFollowing = !isFollowing;
                          followers += isFollowing ? 1 : -1;
                        });
                      },
                      icon: Icon(
                        isFollowing ? Icons.check : Icons.person_add,
                        size: 16,
                      ),
                      label: Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => widget.onOpenDM(widget.username),
                      icon: const Icon(Icons.mail_outline, size: 16),
                      label: const Text('Direct Message'),
                    ),
                  ],
                ),
                CreatorFontsSection(
                  creatorName: widget.username,
                  onApplyFont: (font) async {
                    final app = Quexdc.of(context);
                    if (app == null) {
                      throw StateError(
                        'The app font settings are unavailable.',
                      );
                    }
                    await app.applyCommunityFont(font);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final Function(List<dynamic>) onCommentAdded;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.onCommentAdded,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late List<dynamic> comments;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    comments = List.from(
      widget.post['comments'] is List ? widget.post['comments'] : [],
    );
  }

  void _addComment() {
    if (_commentController.text.trim().isNotEmpty) {
      setState(() {
        comments.add(_commentController.text.trim());
      });
      widget.onCommentAdded(comments);
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Details')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.post['content'],
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Text(
                  'Comments (${comments.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...comments.map(
                  (c) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(c.toString()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const FullScreenImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: kLoadImage(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

Widget kLoadImage(
  String imagePath, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
}) {
  if (kIsWeb) {
    return Image.network(
      imagePath,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  } else {
    return Image.file(File(imagePath), height: height, width: width, fit: fit);
  }
}
