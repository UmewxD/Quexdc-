import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'font_marketplace.dart';
import 'sound_studio.dart';

enum DimensionMode { local, shared }

class EscapePost {
  const EscapePost({
    required this.id,
    required this.codename,
    required this.message,
    required this.createdAt,
    this.isReported = false,
  });

  final String id;
  final String codename;
  final String message;
  final DateTime createdAt;
  final bool isReported;

  Map<String, dynamic> toJson() => {
    'id': id,
    'codename': codename,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'isReported': isReported,
  };

  factory EscapePost.fromJson(Map<String, dynamic> json) => EscapePost(
    id: json['id'] as String,
    codename: json['codename'] as String,
    message: json['message'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isReported: json['isReported'] as bool? ?? false,
  );
}

class EscapeRoom {
  const EscapeRoom({
    required this.id,
    required this.name,
    required this.vibe,
    required this.codename,
    required this.posts,
    this.entryCode,
    this.membershipToken,
  });

  final String id;
  final String name;
  final String vibe;
  final String codename;
  final List<EscapePost> posts;
  final String? entryCode;
  final String? membershipToken;

  bool get isShared => membershipToken != null;

  EscapeRoom copyWith({
    String? name,
    String? vibe,
    String? codename,
    List<EscapePost>? posts,
    String? entryCode,
    String? membershipToken,
  }) => EscapeRoom(
    id: id,
    name: name ?? this.name,
    vibe: vibe ?? this.vibe,
    codename: codename ?? this.codename,
    posts: posts ?? this.posts,
    entryCode: entryCode ?? this.entryCode,
    membershipToken: membershipToken ?? this.membershipToken,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'vibe': vibe,
    'codename': codename,
    'posts': posts.map((post) => post.toJson()).toList(),
    'entryCode': entryCode,
    'membershipToken': membershipToken,
  };

  factory EscapeRoom.fromJson(Map<String, dynamic> json) {
    final posts = json['posts'];
    if (posts is! List) {
      throw const FormatException('Dimension room posts must be a list.');
    }
    return EscapeRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      vibe: json['vibe'] as String,
      codename: json['codename'] as String,
      posts: posts
          .map(
            (post) =>
                EscapePost.fromJson(Map<String, dynamic>.from(post as Map)),
          )
          .toList(),
      entryCode: json['entryCode'] as String?,
      membershipToken: json['membershipToken'] as String?,
    );
  }
}

class EscapeDimensionService {
  static const _localKey = 'escape_dimension_local_rooms_v1';
  static const _sharedKey = 'escape_dimension_shared_memberships_v1';

  static Future<List<EscapeRoom>> loadLocalRooms() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadRooms(prefs.getString(_localKey));
  }

  static Future<List<EscapeRoom>> loadSharedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadRooms(prefs.getString(_sharedKey));
  }

  static List<EscapeRoom> _loadRooms(String? encoded) {
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Saved dimension rooms must be a list.');
    }
    return decoded
        .map(
          (room) => EscapeRoom.fromJson(Map<String, dynamic>.from(room as Map)),
        )
        .toList();
  }

  static Future<void> saveLocalRooms(List<EscapeRoom> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _localKey,
      jsonEncode(rooms.map((room) => room.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('The device declined to save dimension rooms.');
    }
  }

  static Future<void> saveSharedRooms(List<EscapeRoom> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _sharedKey,
      jsonEncode(rooms.map((room) => room.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('The device declined to save shared room access.');
    }
  }

  static SupabaseClient get _client {
    if (!FontMarketplaceService.isReady) {
      throw StateError(
        'Configure Supabase to create or join shared Dimensions.',
      );
    }
    return FontMarketplaceService.client;
  }

  static Future<EscapeRoom> createSharedRoom({
    required String name,
    required String vibe,
    required String codename,
  }) async {
    final result = await _client.rpc(
      'create_escape_dimension',
      params: {'p_name': name, 'p_vibe': vibe, 'p_codename': codename},
    );
    return _roomFromResponse(result);
  }

  static Future<EscapeRoom> joinSharedRoom({
    required String code,
    required String codename,
  }) async {
    final result = await _client.rpc(
      'join_escape_dimension',
      params: {'p_invite_code': code, 'p_codename': codename},
    );
    return _roomFromResponse(result);
  }

  static EscapeRoom _roomFromResponse(dynamic result) {
    if (result is! Map) {
      throw const FormatException(
        'The Dimension server returned invalid room data.',
      );
    }
    final json = Map<String, dynamic>.from(result);
    return EscapeRoom(
      id: json['room_id'] as String,
      name: json['name'] as String,
      vibe: json['vibe'] as String,
      codename: json['codename'] as String,
      posts: const [],
      entryCode: json['invite_code'] as String?,
      membershipToken: json['membership_token'] as String,
    );
  }

  static Future<List<EscapePost>> loadSharedPosts(EscapeRoom room) async {
    final result = await _client.rpc(
      'list_escape_posts',
      params: {
        'p_room_id': room.id,
        'p_membership_token': room.membershipToken,
      },
    );
    if (result is! List) {
      throw const FormatException(
        'The Dimension server returned invalid posts.',
      );
    }
    return result
        .map(
          (post) => EscapePost.fromJson(Map<String, dynamic>.from(post as Map)),
        )
        .toList();
  }

  static Future<EscapePost> sendSharedPost(
    EscapeRoom room,
    String message,
  ) async {
    final result = await _client.rpc(
      'send_escape_post',
      params: {
        'p_room_id': room.id,
        'p_membership_token': room.membershipToken,
        'p_content': message,
      },
    );
    if (result is! Map) {
      throw const FormatException(
        'The Dimension server returned invalid post data.',
      );
    }
    return EscapePost.fromJson(Map<String, dynamic>.from(result));
  }

  static Future<void> reportSharedPost(
    EscapeRoom room,
    EscapePost post,
    String reason,
  ) async {
    await _client.rpc(
      'report_escape_post',
      params: {
        'p_room_id': room.id,
        'p_membership_token': room.membershipToken,
        'p_post_id': post.id,
        'p_reason': reason,
      },
    );
  }
}

class EscapeDimensionsScreen extends StatefulWidget {
  const EscapeDimensionsScreen({
    super.key,
    required this.soundStudio,
    required this.onExit,
    required this.onThemeChanged,
  });

  final SoundStudioController soundStudio;
  final VoidCallback onExit;
  final ValueChanged<Color?> onThemeChanged;

  @override
  State<EscapeDimensionsScreen> createState() => _EscapeDimensionsScreenState();
}

class _EscapeDimensionsScreenState extends State<EscapeDimensionsScreen>
    with WidgetsBindingObserver {
  DimensionMode _mode = DimensionMode.local;
  List<EscapeRoom> _localRooms = [];
  List<EscapeRoom> _sharedRooms = [];
  EscapeRoom? _activeRoom;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _ambientEnabled = false;
  String _selectedVibe = 'lofi';
  final TextEditingController _messageController = TextEditingController();

  List<EscapeRoom> get _rooms =>
      _mode == DimensionMode.local ? _localRooms : _sharedRooms;

  Color get _vibeColor => switch (_selectedVibe) {
    'cyber' => const Color(0xFFB32EFF),
    'deep' => const Color(0xFF00A8A8),
    _ => const Color(0xFF8A65F2),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRooms();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _ambientEnabled) {
      _ambientEnabled = false;
      unawaited(widget.soundStudio.stopAmbient());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    if (_ambientEnabled) unawaited(widget.soundStudio.stopAmbient());
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final local = await EscapeDimensionService.loadLocalRooms();
      final shared = await EscapeDimensionService.loadSharedRooms();
      if (!mounted) return;
      setState(() {
        _localRooms = local;
        _sharedRooms = shared;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Could not load your Dimensions: $error');
    }
  }

  Future<void> _saveRooms(List<EscapeRoom> rooms) async {
    if (_mode == DimensionMode.local) {
      await EscapeDimensionService.saveLocalRooms(rooms);
      if (mounted) setState(() => _localRooms = rooms);
    } else {
      await EscapeDimensionService.saveSharedRooms(rooms);
      if (mounted) setState(() => _sharedRooms = rooms);
    }
  }

  Future<void> _createRoom([String initialName = '']) async {
    final details = await _showRoomDialog(
      isJoining: false,
      initialName: initialName,
    );
    if (details == null) return;
    try {
      final room = _mode == DimensionMode.local
          ? EscapeRoom(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: details.name,
              vibe: details.vibe,
              codename: details.codename,
              posts: const [],
              entryCode: _makeLocalCode(),
            )
          : await EscapeDimensionService.createSharedRoom(
              name: details.name,
              vibe: details.vibe,
              codename: details.codename,
            );
      await _saveRooms([..._rooms, room]);
      _enterRoom(room);
      if (room.entryCode != null && mounted) {
        _showMessage(
          'Invite code: ${room.entryCode} — copy it to invite people.',
        );
      }
    } catch (error) {
      _showMessage('Could not create that Dimension: $error');
    }
  }

  Future<void> _joinRoom() async {
    final details = await _showRoomDialog(isJoining: true);
    if (details == null) return;
    try {
      EscapeRoom room;
      if (_mode == DimensionMode.local) {
        room = _localRooms.firstWhere(
          (item) => item.entryCode == details.code,
          orElse: () => throw const FormatException(
            'No local room has that code. Local rooms only exist on this device.',
          ),
        );
        room = room.copyWith(codename: details.codename);
      } else {
        room = await EscapeDimensionService.joinSharedRoom(
          code: details.code,
          codename: details.codename,
        );
      }
      if (!_rooms.any((item) => item.id == room.id)) {
        await _saveRooms([..._rooms, room]);
      }
      _enterRoom(room);
    } catch (error) {
      _showMessage('Could not enter that Dimension: $error');
    }
  }

  Future<_RoomDetails?> _showRoomDialog({
    required bool isJoining,
    String initialName = '',
  }) => showDialog<_RoomDetails>(
    context: context,
    builder: (_) => _RoomDialog(isJoining: isJoining, initialName: initialName),
  );

  String _makeLocalCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = math.Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void _enterRoom(EscapeRoom room) {
    setState(() {
      _activeRoom = room;
      _selectedVibe = room.vibe;
    });
    widget.onThemeChanged(switch (room.vibe) {
      'cyber' => const Color(0xFFB32EFF),
      'deep' => const Color(0xFF00A8A8),
      _ => const Color(0xFF8A65F2),
    });
    if (room.isShared) {
      unawaited(_refreshSharedPosts(room));
    }
  }

  Future<void> _refreshSharedPosts(EscapeRoom room) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final posts = await EscapeDimensionService.loadSharedPosts(room);
      final updated = room.copyWith(posts: posts);
      final rooms = _rooms
          .map((item) => item.id == room.id ? updated : item)
          .toList();
      await _saveRooms(rooms);
      if (mounted && _activeRoom?.id == room.id) {
        setState(() => _activeRoom = updated);
      }
    } catch (error) {
      _showMessage('Could not refresh this room: $error');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _sendPost() async {
    final room = _activeRoom;
    final message = _messageController.text.trim();
    if (room == null || message.isEmpty || message.length > 1000) return;
    _messageController.clear();
    try {
      final post = room.isShared
          ? await EscapeDimensionService.sendSharedPost(room, message)
          : EscapePost(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              codename: room.codename,
              message: message,
              createdAt: DateTime.now(),
            );
      final updated = room.copyWith(posts: [...room.posts, post]);
      await _replaceRoom(updated);
    } catch (error) {
      if (mounted) _messageController.text = message;
      _showMessage('Could not send your message: $error');
    }
  }

  Future<void> _reportPost(EscapePost post) async {
    final room = _activeRoom;
    if (room == null) return;
    try {
      if (room.isShared) {
        await EscapeDimensionService.reportSharedPost(
          room,
          post,
          'Community report',
        );
      } else {
        final updated = room.copyWith(
          posts: room.posts
              .map(
                (item) => item.id == post.id
                    ? EscapePost(
                        id: item.id,
                        codename: item.codename,
                        message: item.message,
                        createdAt: item.createdAt,
                        isReported: true,
                      )
                    : item,
              )
              .toList(),
        );
        await _replaceRoom(updated);
      }
      _showMessage('Report received. Thanks for helping keep the space safer.');
    } catch (error) {
      _showMessage('Could not submit that report: $error');
    }
  }

  Future<void> _replaceRoom(EscapeRoom room) async {
    final rooms = _rooms
        .map((item) => item.id == room.id ? room : item)
        .toList();
    await _saveRooms(rooms);
    if (mounted) setState(() => _activeRoom = room);
  }

  void _leaveRoom() {
    setState(() => _activeRoom = null);
    widget.onThemeChanged(null);
    if (_ambientEnabled) {
      setState(() => _ambientEnabled = false);
      unawaited(widget.soundStudio.stopAmbient());
    }
  }

  Future<void> _toggleAmbient(bool enabled) async {
    try {
      if (enabled) {
        await widget.soundStudio.playAmbient(_selectedVibe);
      } else {
        await widget.soundStudio.stopAmbient();
      }
      if (mounted) setState(() => _ambientEnabled = enabled);
    } catch (error) {
      _showMessage('Could not change ambient sound: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final room = _activeRoom;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _vibeColor,
          brightness: Theme.of(context).brightness,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Return to Quexdc',
            onPressed: room == null ? widget.onExit : _leaveRoom,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(room?.name ?? 'Community Spaces'),
          actions: [
            if (room != null && room.isShared)
              IconButton(
                tooltip: 'Refresh messages',
                onPressed: _isRefreshing
                    ? null
                    : () => _refreshSharedPosts(room),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: room == null ? _buildLobby() : _buildRoom(room),
      ),
    );
  }

  Widget _buildLobby() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your secret space in Quexdc.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create an invite-only room, use a codename instead of your '
                'Quexdc profile name, and hang out away from the main feed. '
                'It has the feel of a private game lobby, but room messages '
                'are not end-to-end encrypted.',
              ),
              const SizedBox(height: 14),
              SegmentedButton<DimensionMode>(
                segments: const [
                  ButtonSegment(
                    value: DimensionMode.local,
                    icon: Icon(Icons.phone_android),
                    label: Text('On this device'),
                  ),
                  ButtonSegment(
                    value: DimensionMode.shared,
                    icon: Icon(Icons.public),
                    label: Text('Shared online'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 10),
              Text(
                _mode == DimensionMode.local
                    ? 'Local rooms stay on this device. Their invite codes do not work on other devices.'
                    : FontMarketplaceService.isReady
                    ? 'Shared rooms are separate from Quexdc profiles. Invite codes are single-purpose room keys.'
                    : 'Shared rooms need the Supabase setup in supabase/README.md and the Escape Dimensions migration.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: const Icon(Icons.terminal),
          title: const Text('Secret Builder Underground'),
          subtitle: const Text(
            'A private-feeling lobby for projects, questions, and unfinished ideas.',
          ),
          trailing: const Icon(Icons.arrow_forward),
          onTap: _isLoading
              ? null
              : () => _createRoom('Secret Builder Underground'),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The room vibe',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Quexdc is the stage; members are the seekers, observers, and '
                'players who shape what happens here. Bring opinions, debate, '
                'and playful trolling. Quexdc isn’t here to referee every '
                'disagreement or decide who is right. Granduality is the balance '
                'that keeps shifting as people interact. Quexdc and its creator '
                'usually observe, but may step in when things tip so far that '
                'staying silent could let serious harm continue. Respect privacy '
                'and report messages that cross that line.',
              ),
              const SizedBox(height: 10),
              const Text(
                'Codenames separate your room name from your Quexdc profile; '
                'they don’t guarantee anonymity. Shared messages are stored '
                'by the service and aren’t end-to-end encrypted.',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _isLoading ? null : _createRoom,
            icon: const Icon(Icons.add),
            label: const Text('Create a space'),
          ),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _joinRoom,
            icon: const Icon(Icons.login),
            label: const Text('Join with invite code'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_isLoading)
        const Center(child: CircularProgressIndicator())
      else if (_rooms.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text('No secret spaces yet. Create one and invite people.'),
          ),
        )
      else
        for (final room in _rooms)
          Card(
            child: ListTile(
              leading: Icon(
                room.vibe == 'cyber' ? Icons.bolt : Icons.nights_stay,
              ),
              title: Text(room.name),
              subtitle: Text(
                '${room.vibe} · ${room.isShared ? 'Shared' : 'This device'} · ${room.posts.length} messages loaded',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _enterRoom(room),
            ),
          ),
      const SizedBox(height: 12),
      Card(
        child: SwitchListTile(
          secondary: const Icon(Icons.surround_sound),
          title: const Text('Ambient dimension sound'),
          subtitle: Text(
            _ambientEnabled
                ? 'Soft original tone is looping. It stops when you leave.'
                : 'Off until you turn it on.',
          ),
          value: _ambientEnabled,
          onChanged: _toggleAmbient,
        ),
      ),
    ],
  );

  Widget _buildRoom(EscapeRoom room) => Column(
    children: [
      MaterialBanner(
        leading: const Icon(Icons.visibility_outlined),
        content: Text(
          room.isShared
              ? 'You are ${room.codename}. Messages expire after 24 hours. Not encrypted.'
              : 'Local-only room as ${room.codename}. It is stored on this device.',
        ),
        actions: [
          if (room.entryCode != null)
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: room.entryCode!));
                _showMessage('Invite code copied.');
              },
              child: const Text('Copy code'),
            ),
          TextButton(onPressed: _leaveRoom, child: const Text('Leave')),
        ],
      ),
      Expanded(
        child: room.posts.isEmpty
            ? const Center(
                child: Text('Quiet in here. Drop a thought or a build idea.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: room.posts.length,
                itemBuilder: (context, index) {
                  final post = room.posts[index];
                  if (post.isReported) return const SizedBox.shrink();
                  return Card(
                    child: ListTile(
                      title: Text(post.codename),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(post.message),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Message options',
                        onSelected: (_) => _reportPost(post),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'report',
                            child: Text('Report message'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Drop a thought…',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendPost(),
                ),
              ),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: _sendPost,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
      SwitchListTile(
        dense: true,
        secondary: const Icon(Icons.surround_sound),
        title: const Text('Ambient sound'),
        value: _ambientEnabled,
        onChanged: _toggleAmbient,
      ),
    ],
  );
}

class _RoomDetails {
  const _RoomDetails({
    this.name = '',
    this.vibe = 'lofi',
    required this.codename,
    this.code = '',
  });

  final String name;
  final String vibe;
  final String codename;
  final String code;
}

class _RoomDialog extends StatefulWidget {
  const _RoomDialog({required this.isJoining, required this.initialName});

  final bool isJoining;
  final String initialName;

  @override
  State<_RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<_RoomDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _codenameController;
  String _vibe = 'lofi';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _codeController = TextEditingController();
    _codenameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _codenameController.dispose();
    super.dispose();
  }

  void _submit() {
    final codename = _codenameController.text.trim();
    if (codename.isEmpty) {
      setState(() => _validationError = 'Choose a codename to continue.');
      return;
    }

    if (widget.isJoining) {
      final code = _codeController.text.trim().toUpperCase();
      if (code.isEmpty) {
        setState(() => _validationError = 'Enter the room invite code.');
        return;
      }
      Navigator.pop(context, _RoomDetails(codename: codename, code: code));
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = 'Give your room a name.');
      return;
    }
    Navigator.pop(
      context,
      _RoomDetails(name: name, vibe: _vibe, codename: codename),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isJoining ? 'Enter a Dimension' : 'Create a Dimension'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isJoining)
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Invite code'),
            )
          else ...[
            TextField(
              controller: _nameController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Room name',
                hintText: 'Late-night builders',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _vibe,
              decoration: const InputDecoration(labelText: 'Dimension vibe'),
              items: const [
                DropdownMenuItem(value: 'lofi', child: Text('Lo-fi lounge')),
                DropdownMenuItem(value: 'cyber', child: Text('Cyber city')),
                DropdownMenuItem(value: 'deep', child: Text('Deep sea')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _vibe = value);
              },
            ),
          ],
          TextField(
            controller: _codenameController,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: 'Your codename',
              hintText: 'No main Quexdc username',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Don’t use a password you use elsewhere. Codenames are not verified identities.',
          ),
          if (_validationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.isJoining ? 'Enter' : 'Create'),
      ),
    ],
  );
}
