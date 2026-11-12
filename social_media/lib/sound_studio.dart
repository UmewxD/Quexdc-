import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundTrigger {
  static const snap = 'snap';
  static const whistle = 'whistle';
  static const motionSnap = 'motionSnap';
  static const tap = 'tap';
  static const doubleTap = 'doubleTap';
  static const like = 'like';
  static const portal = 'portal';

  static const all = [snap, whistle, motionSnap, tap, doubleTap, like, portal];

  static String label(String trigger) => switch (trigger) {
    snap => 'Finger snap',
    whistle => 'Whistle',
    motionSnap => 'Motion snap',
    tap => 'Tap',
    doubleTap => 'Double tap',
    like => 'Like a post',
    portal => 'Escape portal',
    _ => trigger,
  };
}

class SoundClip {
  const SoundClip({
    required this.id,
    required this.name,
    required this.path,
    required this.mimeType,
  });

  final String id;
  final String name;
  final String path;
  final String mimeType;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'mimeType': mimeType,
  };

  factory SoundClip.fromJson(Map<String, dynamic> json) => SoundClip(
    id: json['id'] as String,
    name: json['name'] as String,
    path: json['path'] as String,
    mimeType: json['mimeType'] as String? ?? 'audio/mpeg',
  );
}

class SoundStudioSettings {
  SoundStudioSettings({
    Map<String, String>? assignments,
    List<SoundClip>? customSounds,
  }) : assignments = assignments ?? _defaultAssignments(),
       customSounds = customSounds ?? [];

  final Map<String, String> assignments;
  final List<SoundClip> customSounds;

  static Map<String, String> _defaultAssignments() => {
    SoundTrigger.snap: 'tone:snap',
    SoundTrigger.whistle: 'tone:whistle',
    SoundTrigger.motionSnap: 'tone:motion',
    SoundTrigger.tap: 'tone:tap',
    SoundTrigger.doubleTap: 'tone:doubleTap',
    SoundTrigger.like: 'tone:like',
    SoundTrigger.portal: 'tone:chime',
  };

  Map<String, dynamic> toJson() => {
    'assignments': assignments,
    'customSounds': customSounds.map((sound) => sound.toJson()).toList(),
  };

  factory SoundStudioSettings.fromJson(Map<String, dynamic> json) {
    final rawAssignments = json['assignments'];
    final assignments = <String, String>{};
    if (rawAssignments == null || rawAssignments is Map) {
      if (rawAssignments is Map) {
        for (final entry in rawAssignments.entries) {
          if (entry.key is String && entry.value is String) {
            assignments[entry.key as String] = entry.value as String;
          }
        }
      }
    } else {
      throw const FormatException('Sound assignments must be an object.');
    }

    final rawSounds = json['customSounds'];
    if (rawSounds != null && rawSounds is! List) {
      throw const FormatException('Custom sounds must be a list.');
    }
    final sounds = (rawSounds as List? ?? [])
        .map(
          (sound) =>
              SoundClip.fromJson(Map<String, dynamic>.from(sound as Map)),
        )
        .toList();

    final restored = SoundStudioSettings(
      assignments: {..._defaultAssignments(), ...assignments},
      customSounds: sounds,
    );
    for (final trigger in SoundTrigger.all) {
      if (!restored.availableSounds.any(
        (sound) => sound.id == restored.assignments[trigger],
      )) {
        restored.assignments[trigger] = 'tone:${_toneForTrigger(trigger)}';
      }
    }
    return restored;
  }

  List<SoundClip> get availableSounds => [
    const SoundClip(
      id: 'tone:snap',
      name: 'Cosmic Pop',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:whistle',
      name: 'Star Whistle',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:motion',
      name: 'Motion Spark',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:tap',
      name: 'Soft Tap',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:doubleTap',
      name: 'Double Pulse',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:like',
      name: 'Like Bloom',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:chime',
      name: 'Aurora Chime',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:bubble',
      name: 'Bubble Pop',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:glitch',
      name: 'Pixel Glitch',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:zap',
      name: 'Neon Zap',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:heartbeat',
      name: 'Heart Beat',
      path: '',
      mimeType: 'audio/wav',
    ),
    const SoundClip(
      id: 'tone:ambient',
      name: 'Dimension Ambience',
      path: '',
      mimeType: 'audio/wav',
    ),
    ...customSounds,
  ];

  static String _toneForTrigger(String trigger) => switch (trigger) {
    SoundTrigger.whistle => 'whistle',
    SoundTrigger.motionSnap => 'motion',
    SoundTrigger.tap => 'tap',
    SoundTrigger.doubleTap => 'doubleTap',
    SoundTrigger.like => 'like',
    SoundTrigger.portal => 'chime',
    _ => 'snap',
  };
}

class SoundStudioController {
  static const _storageKey = 'sound_studio_settings';
  static const _maxCustomSoundBytes = 20 * 1024 * 1024;
  static const _maxWebSoundBytes = 1572864;

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  SoundStudioSettings settings = SoundStudioSettings();
  bool _isLoaded = false;

  Future<void> load() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded != null) {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        throw const FormatException('Sound settings must be a JSON object.');
      }
      settings = SoundStudioSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    }
    _isLoaded = true;
  }

  Future<void> _save(SoundStudioSettings updated) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _storageKey,
      jsonEncode(updated.toJson()),
    );
    if (!saved) throw StateError('The device declined to save sound settings.');
    settings = updated;
  }

  Future<void> assignSound(String trigger, String soundId) async {
    await load();
    if (!SoundTrigger.all.contains(trigger) ||
        !settings.availableSounds.any((sound) => sound.id == soundId)) {
      throw ArgumentError('That sound or trigger is not available.');
    }
    final assignments = Map<String, String>.from(settings.assignments)
      ..[trigger] = soundId;
    await _save(
      SoundStudioSettings(
        assignments: assignments,
        customSounds: List<SoundClip>.from(settings.customSounds),
      ),
    );
  }

  Future<SoundClip?> addCustomSound() async {
    final picked = await FilePicker.pickFile(type: FileType.audio);
    if (picked == null) return null;
    final size = await picked.length();
    if (size == null || size <= 0 || size > _maxCustomSoundBytes) {
      throw const FormatException('Choose an audio file smaller than 20 MB.');
    }

    final extension = _audioExtension(picked.name);
    final id = 'custom:${DateTime.now().microsecondsSinceEpoch}';
    final mimeType = _mimeType(extension);
    late final String savedPath;
    if (kIsWeb) {
      if (size > _maxWebSoundBytes) {
        throw const FormatException(
          'For browser storage, choose an audio file under 1.5 MB.',
        );
      }
      final bytes = await picked.readAsBytes();
      savedPath = 'data:$mimeType;base64,${base64Encode(bytes)}';
    } else {
      final sourcePath = picked.path;
      if (sourcePath == null) {
        throw StateError('The selected audio file has no readable path.');
      }
      final documents = await getApplicationDocumentsDirectory();
      final soundDirectory = Directory(
        '${documents.path}${Platform.pathSeparator}sound_studio',
      );
      await soundDirectory.create(recursive: true);
      final destination = File(
        '${soundDirectory.path}${Platform.pathSeparator}'
        '${id.replaceFirst(':', '_')}.$extension',
      );
      await File(sourcePath).copy(destination.path);
      savedPath = destination.path;
    }

    final clip = SoundClip(
      id: id,
      name: picked.name,
      path: savedPath,
      mimeType: mimeType,
    );
    try {
      await _save(
        SoundStudioSettings(
          assignments: Map<String, String>.from(settings.assignments),
          customSounds: [...settings.customSounds, clip],
        ),
      );
    } catch (error) {
      await _deleteStoredFile(savedPath);
      rethrow;
    }
    return clip;
  }

  Future<void> removeCustomSound(String id) async {
    await load();
    final clip = settings.customSounds.where((sound) => sound.id == id);
    if (clip.isEmpty) return;
    final removed = clip.first;
    final sounds = settings.customSounds
        .where((sound) => sound.id != id)
        .toList();
    final assignments = Map<String, String>.from(settings.assignments);
    for (final trigger in SoundTrigger.all) {
      if (assignments[trigger] == id) {
        assignments[trigger] =
            SoundStudioSettings._defaultAssignments()[trigger]!;
      }
    }
    await _save(
      SoundStudioSettings(assignments: assignments, customSounds: sounds),
    );
    await _deleteStoredFile(removed.path);
  }

  Future<void> playTrigger(String trigger) async {
    await load();
    final soundId = settings.assignments[trigger];
    if (soundId == null) {
      throw StateError('No sound is assigned to this action.');
    }
    await playSound(soundId);
  }

  Future<void> playSound(String soundId) async {
    await load();
    final clip = settings.availableSounds.where((sound) => sound.id == soundId);
    if (soundId.startsWith('tone:')) {
      await _player.play(BytesSource(_createTone(soundId)));
    } else if (clip.isNotEmpty) {
      final sound = clip.first;
      if (sound.path.startsWith('data:')) {
        final separator = sound.path.indexOf(',');
        if (separator < 0) throw const FormatException('Invalid sound data.');
        await _player.play(
          BytesSource(
            base64Decode(sound.path.substring(separator + 1)),
            mimeType: sound.mimeType,
          ),
        );
      } else {
        await _player.play(
          DeviceFileSource(sound.path, mimeType: sound.mimeType),
        );
      }
    } else {
      throw StateError('The selected sound is no longer available.');
    }
  }

  Future<void> playAmbient(String style) async {
    final frequency = switch (style) {
      'lofi' => 130.81,
      'cyber' => 164.81,
      'deep' => 110.0,
      _ => 146.83,
    };
    await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    await _ambientPlayer.setVolume(0.14);
    await _ambientPlayer.play(BytesSource(_createAmbient(frequency)));
  }

  Future<void> stopAmbient() async {
    await _ambientPlayer.stop();
    await _ambientPlayer.setReleaseMode(ReleaseMode.release);
  }

  Future<void> _deleteStoredFile(String path) async {
    if (kIsWeb || path.startsWith('data:')) return;
    try {
      final documents = await getApplicationDocumentsDirectory();
      final soundDirectory = Directory(
        '${documents.path}${Platform.pathSeparator}sound_studio',
      );
      final file = File(path);
      if (file.parent.absolute.path == soundDirectory.absolute.path &&
          await file.exists()) {
        await file.delete();
      }
    } on Exception catch (error) {
      throw FileSystemException('Could not remove the custom sound: $error');
    }
  }

  Future<void> dispose() async {
    await Future.wait([_player.dispose(), _ambientPlayer.dispose()]);
  }

  static Uint8List _createAmbient(double frequency) {
    const sampleRate = 22050;
    const sampleCount = sampleRate * 4;
    const dataLength = sampleCount * 2;
    final output = ByteData(44 + dataLength);
    final chunks = <List<int>>[
      'RIFF'.codeUnits,
      'WAVE'.codeUnits,
      'fmt '.codeUnits,
      'data'.codeUnits,
    ];
    for (var index = 0; index < 4; index++) {
      output.setUint8(index, chunks[0][index]);
      output.setUint8(8 + index, chunks[1][index]);
      output.setUint8(12 + index, chunks[2][index]);
      output.setUint8(36 + index, chunks[3][index]);
    }
    output.setUint32(4, 36 + dataLength, Endian.little);
    output.setUint32(16, 16, Endian.little);
    output.setUint16(20, 1, Endian.little);
    output.setUint16(22, 1, Endian.little);
    output.setUint32(24, sampleRate, Endian.little);
    output.setUint32(28, sampleRate * 2, Endian.little);
    output.setUint16(32, 2, Endian.little);
    output.setUint16(34, 16, Endian.little);
    output.setUint32(40, dataLength, Endian.little);
    for (var index = 0; index < sampleCount; index++) {
      final phase = 2 * math.pi * index / sampleRate;
      final fade =
          math.min(index % sampleRate, sampleRate - index % sampleRate) /
          (sampleRate * 0.08);
      final sample =
          ((math.sin(phase * frequency) * 0.52 +
                      math.sin(phase * frequency * 1.5) * 0.2 +
                      math.sin(phase * frequency * 2.01) * 0.14) *
                  fade.clamp(0, 1) *
                  6200)
              .round()
              .clamp(-32768, 32767);
      output.setInt16(44 + index * 2, sample, Endian.little);
    }
    return output.buffer.asUint8List();
  }

  static String _audioExtension(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    if (!const {
      'mp3',
      'wav',
      'm4a',
      'aac',
      'ogg',
      'flac',
      'opus',
    }.contains(extension)) {
      throw const FormatException(
        'Choose an MP3, WAV, M4A, AAC, OGG, FLAC, or OPUS audio file.',
      );
    }
    return extension;
  }

  static String _mimeType(String extension) => switch (extension) {
    'wav' => 'audio/wav',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'ogg' || 'opus' => 'audio/ogg',
    'flac' => 'audio/flac',
    _ => 'audio/mpeg',
  };

  static Uint8List _createTone(String id) {
    final settings = switch (id) {
      'tone:whistle' => (880.0, 0.28),
      'tone:motion' => (520.0, 0.16),
      'tone:tap' => (720.0, 0.08),
      'tone:doubleTap' => (640.0, 0.12),
      'tone:like' => (1040.0, 0.2),
      'tone:chime' => (880.0, 0.48),
      'tone:bubble' => (680.0, 0.3),
      'tone:glitch' => (190.0, 0.2),
      'tone:zap' => (340.0, 0.26),
      'tone:heartbeat' => (92.0, 0.34),
      _ => (420.0, 0.12),
    };
    const sampleRate = 22050;
    const channels = 1;
    const bytesPerSample = 2;
    final sampleCount = (sampleRate * settings.$2).round();
    final dataLength = sampleCount * channels * bytesPerSample;
    final output = ByteData(44 + dataLength);
    final ascii = <int>[
      ...'RIFF'.codeUnits,
      ...'WAVE'.codeUnits,
      ...'fmt '.codeUnits,
      ...'data'.codeUnits,
    ];
    for (var index = 0; index < 4; index++) {
      output.setUint8(index, ascii[index]);
      output.setUint8(8 + index, ascii[4 + index]);
      output.setUint8(12 + index, ascii[8 + index]);
      output.setUint8(36 + index, ascii[12 + index]);
    }
    output.setUint32(4, 36 + dataLength, Endian.little);
    output.setUint32(16, 16, Endian.little);
    output.setUint16(20, 1, Endian.little);
    output.setUint16(22, channels, Endian.little);
    output.setUint32(24, sampleRate, Endian.little);
    output.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
    output.setUint16(32, channels * bytesPerSample, Endian.little);
    output.setUint16(34, bytesPerSample * 8, Endian.little);
    output.setUint32(40, dataLength, Endian.little);

    for (var index = 0; index < sampleCount; index++) {
      final progress = index / sampleCount;
      final phase = 2 * math.pi * settings.$1 * index / sampleRate;
      final envelope = math
          .pow(1 - progress, id == 'tone:chime' ? 1.4 : 2.2)
          .toDouble();
      final wave = switch (id) {
        'tone:chime' => math.sin(phase) * 0.72 + math.sin(phase * 2.76) * 0.28,
        'tone:bubble' =>
          math.sin(phase * (1 - progress * 0.52)) +
              math.sin(phase * (1 - progress * 0.52) * 1.5) * 0.18,
        'tone:glitch' =>
          (math.sin(phase * (1 + (progress * 18).floor() % 3)) >= 0
                  ? 1.0
                  : -1.0) *
              (progress < 0.15 ? 0.7 : 0.35),
        'tone:zap' =>
          (2 * ((phase / (2 * math.pi)) % 1) - 1) * (1 - progress * 0.6),
        'tone:heartbeat' =>
          math.sin(phase) *
              ((progress < 0.22 || (progress > 0.34 && progress < 0.52))
                  ? 1.0
                  : 0.12),
        _ => math.sin(phase) + math.sin(phase * 2) * 0.16,
      };
      final sample = (wave * envelope * 15000).round().clamp(-32768, 32767);
      output.setInt16(44 + index * 2, sample, Endian.little);
    }
    return output.buffer.asUint8List();
  }
}

enum GestureAudioEvent { snap, whistle }

class SnapStreakCounter {
  static const threshold = 10;
  static const window = Duration(seconds: 5);

  final List<DateTime> _snaps = [];

  bool record(DateTime time) {
    while (_snaps.isNotEmpty &&
        (time.isBefore(_snaps.first) ||
            time.difference(_snaps.first) > window)) {
      _snaps.removeAt(0);
    }
    _snaps.add(time);
    if (_snaps.length < threshold) return false;
    _snaps.clear();
    return true;
  }
}

class GestureAudioDetector {
  static const _frameSize = 512;
  static const _sampleRate = 16000;

  DateTime? _lastDetection;
  int _whistleFrames = 0;
  final List<int> _pendingBytes = [];

  List<GestureAudioEvent> addPcm16(Uint8List bytes, DateTime now) {
    final events = <GestureAudioEvent>[];
    _pendingBytes.addAll(bytes);
    const frameBytes = _frameSize * 2;
    while (_pendingBytes.length >= frameBytes) {
      final frame = Uint8List.fromList(_pendingBytes.take(frameBytes).toList());
      _pendingBytes.removeRange(0, frameBytes);
      final frameData = ByteData.sublistView(frame);
      final samples = List<double>.generate(_frameSize, (index) {
        final value = frameData.getInt16(index * 2, Endian.little);
        return value / 32768;
      }, growable: false);
      final metrics = _measure(samples);
      if (metrics.$1 > 0.62 &&
          metrics.$2 > 0.035 &&
          metrics.$3 > 4.5 &&
          _readyToDetect(now)) {
        events.add(GestureAudioEvent.snap);
        _lastDetection = now;
        _whistleFrames = 0;
        continue;
      }

      if (metrics.$2 > 0.012 && _whistleToneRatio(samples) > 0.34) {
        _whistleFrames++;
      } else {
        _whistleFrames = 0;
      }
      if (_whistleFrames >= 5 && _readyToDetect(now)) {
        events.add(GestureAudioEvent.whistle);
        _lastDetection = now;
        _whistleFrames = 0;
      }
    }
    return events;
  }

  bool _readyToDetect(DateTime now) =>
      _lastDetection == null ||
      now.difference(_lastDetection!) >= const Duration(milliseconds: 350);

  (double, double, double) _measure(List<double> samples) {
    var peak = 0.0;
    var energy = 0.0;
    for (final sample in samples) {
      final absolute = sample.abs();
      if (absolute > peak) peak = absolute;
      energy += sample * sample;
    }
    final rms = math.sqrt(energy / samples.length);
    return (peak, rms, peak / (rms + 0.000001));
  }

  double _whistleToneRatio(List<double> samples) {
    var totalEnergy = 0.0;
    for (final sample in samples) {
      totalEnergy += sample * sample;
    }
    if (totalEnergy == 0) return 0;

    var strongestRatio = 0.0;
    for (var frequency = 1500; frequency <= 4000; frequency += 250) {
      final bin = (frequency * _frameSize / _sampleRate).round();
      final omega = 2 * math.pi * bin / _frameSize;
      final coefficient = 2 * math.cos(omega);
      var previous = 0.0;
      var previousPrevious = 0.0;
      for (final sample in samples) {
        final current = sample + coefficient * previous - previousPrevious;
        previousPrevious = previous;
        previous = current;
      }
      final power =
          previous * previous +
          previousPrevious * previousPrevious -
          coefficient * previous * previousPrevious;
      final ratio = power / (_frameSize * totalEnergy);
      if (ratio > strongestRatio) strongestRatio = ratio;
    }
    return strongestRatio;
  }
}

class SoundStudioScreen extends StatefulWidget {
  const SoundStudioScreen({
    super.key,
    required this.controller,
    this.onPortalTrigger,
  });

  final SoundStudioController controller;
  final ValueChanged<String>? onPortalTrigger;

  @override
  State<SoundStudioScreen> createState() => _SoundStudioScreenState();
}

class _SoundStudioScreenState extends State<SoundStudioScreen>
    with WidgetsBindingObserver {
  final AudioRecorder _recorder = AudioRecorder();
  final GestureAudioDetector _audioDetector = GestureAudioDetector();
  final SnapStreakCounter _snapStreakCounter = SnapStreakCounter();
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<UserAccelerometerEvent>? _motionSubscription;
  bool _microphoneListening = false;
  bool _motionListening = false;
  bool _motionArmed = true;
  bool _isImporting = false;
  bool _portalArmed = false;
  DateTime? _lastMotionSnap;
  DateTime? _ignoreInputUntil;
  String _detectorMessage = 'Microphone and motion detection are off.';

  bool get _supportsMotion =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopMicrophone(reportError: true));
    unawaited(_stopMotion());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_stopMicrophone());
      unawaited(_stopMotion());
    }
  }

  Future<void> _toggleMicrophone(bool enabled) async {
    if (enabled) {
      try {
        final permitted = await _recorder.hasPermission();
        if (!permitted) {
          throw StateError('Microphone permission was not granted.');
        }
        if (!mounted) return;
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );
        if (!mounted) {
          await _recorder.stop();
          return;
        }
        _audioSubscription = stream.listen(
          _processAudio,
          onError: (Object error, StackTrace stackTrace) {
            _showDetectorError('Microphone detection stopped: $error');
            unawaited(_stopMicrophone(reportError: true));
          },
          cancelOnError: true,
        );
        setState(() {
          _microphoneListening = true;
          _detectorMessage = 'Listening for snaps and whistles. Audio is analyzed live and not saved.';
        });
      } catch (error) {
        _showDetectorError('Could not start microphone detection: $error');
      }
    } else {
      await _stopMicrophone();
    }
  }

  Future<void> _stopMicrophone({bool reportError = false}) async {
    final subscription = _audioSubscription;
    _audioSubscription = null;
    try {
      await subscription?.cancel();
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (error) {
      if (reportError) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            library: 'sound studio microphone',
            context: ErrorDescription('while stopping live audio detection'),
          ),
        );
      } else {
        _showDetectorError('Could not stop microphone detection: $error');
      }
    }
    if (mounted) {
      setState(() {
        _microphoneListening = false;
        if (!_motionListening) {
          _detectorMessage = 'Microphone detection is off.';
        }
      });
    }
  }

  void _processAudio(Uint8List bytes) {
    if (_ignoreInputUntil case final expiry?
        when DateTime.now().isBefore(expiry)) {
      return;
    }
    for (final event in _audioDetector.addPcm16(bytes, DateTime.now())) {
      final trigger = switch (event) {
        GestureAudioEvent.snap => SoundTrigger.snap,
        GestureAudioEvent.whistle => SoundTrigger.whistle,
      };
      _detectedTrigger(trigger);
    }
  }

  Future<void> _toggleMotion(bool enabled) async {
    if (!_supportsMotion) {
      _showDetectorError(
        'Motion snap detection is supported on Android, iOS, and compatible browsers.',
      );
      return;
    }
    if (!enabled) {
      await _stopMotion();
      return;
    }
    try {
      _motionSubscription =
          userAccelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen(
            _processMotion,
            onError: (Object error, StackTrace stackTrace) {
              _showDetectorError('Motion detection stopped: $error');
              unawaited(_stopMotion());
            },
            cancelOnError: true,
          );
      if (mounted) {
        setState(() {
          _motionListening = true;
          _motionArmed = true;
          _detectorMessage = 'Motion detection is on. A quick phone flick can trigger a sound.';
        });
      }
    } catch (error) {
      _showDetectorError('Could not start motion detection: $error');
    }
  }

  void _processMotion(UserAccelerometerEvent event) {
    if (_ignoreInputUntil case final expiry?
        when DateTime.now().isBefore(expiry)) {
      return;
    }
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude < 5) _motionArmed = true;
    final now = DateTime.now();
    if (_motionArmed &&
        magnitude > 16 &&
        (_lastMotionSnap == null ||
            now.difference(_lastMotionSnap!) >
                const Duration(milliseconds: 900))) {
      _motionArmed = false;
      _lastMotionSnap = now;
      _detectedTrigger(SoundTrigger.motionSnap);
    }
  }

  Future<void> _stopMotion() async {
    await _motionSubscription?.cancel();
    _motionSubscription = null;
    if (mounted) {
      setState(() {
        _motionListening = false;
        if (!_microphoneListening) {
          _detectorMessage = 'Motion detection is off.';
        }
      });
    }
  }

  void _detectedTrigger(String trigger) {
    _ignoreInputUntil = DateTime.now().add(const Duration(milliseconds: 250));
    if (mounted) {
      setState(
        () => _detectorMessage = '${SoundTrigger.label(trigger)} detected!',
      );
    }
    unawaited(_playTrigger(trigger));
    if (_portalArmed &&
        (trigger == SoundTrigger.snap || trigger == SoundTrigger.whistle)) {
      widget.onPortalTrigger?.call(trigger);
    }
  }

  Future<void> _playTrigger(String trigger) async {
    if (trigger == SoundTrigger.snap &&
        _snapStreakCounter.record(DateTime.now())) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '10 snaps in 5 seconds? (Okiii! We hope you don’t overdo it '
              'so your skin doesn’t get rough... or are you even human?)',
            ),
          ),
        );
    }
    try {
      await widget.controller.playTrigger(trigger);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not play the ${SoundTrigger.label(trigger)} sound: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _playSound(String soundId) async {
    try {
      await widget.controller.playSound(soundId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play that sound: $error')),
        );
      }
    }
  }

  Future<void> _assignSound(String trigger, String? soundId) async {
    if (soundId == null) return;
    try {
      await widget.controller.assignSound(trigger, soundId);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save this sound choice: $error')),
        );
      }
    }
  }

  Future<void> _addCustomSound() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final sound = await widget.controller.addCustomSound();
      if (sound != null && mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${sound.name} to your sound shelf.')),
        );
      }
    } on FormatException catch (error) {
      _showDetectorError(error.message);
    } on Exception catch (error) {
      _showDetectorError('Could not add that sound: $error');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _removeCustomSound(SoundClip sound) async {
    try {
      await widget.controller.removeCustomSound(sound.id);
      if (mounted) setState(() {});
    } catch (error) {
      _showDetectorError('Could not remove that sound: $error');
    }
  }

  void _showDetectorError(String message) {
    if (!mounted) return;
    setState(() => _detectorMessage = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    final availableSounds = settings.availableSounds;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture & Sound Studio'),
        actions: [
          IconButton(
            tooltip: 'Add a custom sound',
            onPressed: _isImporting ? null : _addCustomSound,
            icon: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.library_music_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your sounds, your rules',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick a sound for each trigger. Built-in tones are generated '
                    'in the app; custom audio stays on this device.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _detectorMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSoundAssignments(availableSounds),
          const SizedBox(height: 12),
          _buildFreeSoundPack(availableSounds),
          const SizedBox(height: 12),
          _buildCustomSounds(settings.customSounds),
          const SizedBox(height: 12),
          _buildTryItCard(),
          const SizedBox(height: 12),
          _buildPortalSetting(),
          const SizedBox(height: 12),
          _buildDetectionSettings(),
        ],
      ),
    );
  }

  Widget _buildSoundAssignments(List<SoundClip> sounds) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assign sounds', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final trigger in SoundTrigger.all)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    SoundTrigger.label(trigger),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        widget.controller.settings.assignments[trigger],
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(),
                    ),
                    items: sounds
                        .map(
                          (sound) => DropdownMenuItem(
                            value: sound.id,
                            child: Text(
                              sound.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => _assignSound(trigger, value),
                  ),
                ),
                IconButton(
                  tooltip: 'Preview ${SoundTrigger.label(trigger)} sound',
                  onPressed: () => _playTrigger(trigger),
                  icon: const Icon(Icons.play_circle_outline),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _buildCustomSounds(List<SoundClip> sounds) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Custom sound shelf',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _isImporting ? null : _addCustomSound,
                icon: const Icon(Icons.add),
                label: const Text('Add audio'),
              ),
            ],
          ),
          if (sounds.isEmpty)
            const Text('No custom sounds yet. Import an audio clip to begin.')
          else
            for (final sound in sounds)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.music_note),
                title: Text(
                  sound.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  sound.id.startsWith('tone:')
                      ? 'Built-in tone'
                      : 'Private on this device',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Preview ${sound.name}',
                      onPressed: () => _playSound(sound.id),
                      icon: const Icon(Icons.play_arrow),
                    ),
                    if (sound.id.startsWith('custom:'))
                      IconButton(
                        tooltip: 'Remove ${sound.name}',
                        onPressed: () => _removeCustomSound(sound),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );

  Widget _buildFreeSoundPack(List<SoundClip> sounds) {
    const freePackIds = {
      'tone:chime',
      'tone:bubble',
      'tone:glitch',
      'tone:zap',
      'tone:heartbeat',
    };
    final pack = sounds.where((sound) => freePackIds.contains(sound.id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Free synth pack',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Original sounds made in-app. No downloads or purchases.',
            ),
            for (final sound in pack)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome),
                title: Text(sound.name),
                trailing: IconButton(
                  tooltip: 'Preview ${sound.name}',
                  onPressed: () => _playSound(sound.id),
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTryItCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try your triggers',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Try a snap streak for a playful reminder.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _playTrigger(SoundTrigger.snap),
                icon: const Icon(Icons.front_hand_outlined),
                label: const Text('Snap'),
              ),
              OutlinedButton.icon(
                onPressed: () => _playTrigger(SoundTrigger.whistle),
                icon: const Icon(Icons.waves),
                label: const Text('Whistle'),
              ),
              OutlinedButton.icon(
                onPressed: () => _playTrigger(SoundTrigger.like),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Like'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _playTrigger(SoundTrigger.tap),
            onDoubleTap: () => _playTrigger(SoundTrigger.doubleTap),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Tap or double-tap here to preview gesture sounds',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDetectionSettings() => Card(
    child: Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.mic_none),
          title: const Text('Listen for snaps and whistles'),
          subtitle: Text(
            _microphoneListening
                ? 'Listening only while this screen is open. Audio is not saved.'
                : 'Microphone permission is requested only when enabled.',
          ),
          value: _microphoneListening,
          onChanged: _toggleMicrophone,
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.vibration),
          title: const Text('Motion snap'),
          subtitle: Text(
            _supportsMotion
                ? 'Trigger with a quick phone flick.'
                : 'Available on Android, iOS, and compatible browsers.',
          ),
          value: _motionListening,
          onChanged: _toggleMotion,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Snap and whistle detection is approximate and can react to other '
            'loud or high-pitched sounds. Turn listening off anytime.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildPortalSetting() => Card(
    child: SwitchListTile(
      secondary: const Icon(Icons.blur_on),
      title: const Text('Snap or whistle into the Dimension'),
      subtitle: const Text(
        'When microphone listening is on, a detected snap or whistle opens the Escape Dimension.',
      ),
      value: _portalArmed,
      onChanged: (enabled) => setState(() => _portalArmed = enabled),
    ),
  );
}
