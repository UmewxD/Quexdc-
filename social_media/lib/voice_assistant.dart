import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceAssistantMode { idle, wakePhrase, command, replying, unavailable }

enum VoiceCommandType {
  navigate,
  previewSound,
  openSoundSettings,
  enableWakePhrase,
  disableWakePhrase,
  help,
  unknown,
}

class VoiceCommand {
  const VoiceCommand(this.type, [this.target = '']);

  final VoiceCommandType type;
  final String target;

  @override
  bool operator ==(Object other) =>
      other is VoiceCommand && other.type == type && other.target == target;

  @override
  int get hashCode => Object.hash(type, target);
}

String normalizeVoiceText(String text) => text
    .toLowerCase()
    .replaceAll('é', 'e')
    .replaceAll('è', 'e')
    .replaceAll('ê', 'e')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String? extractWakePhraseCommand(String text) {
  final normalized = normalizeVoiceText(text);
  final match = RegExp(r'^(?:hey\s+)?(?:que|kweh|keh|kay|cue|kway|quay)\b\s*')
      .firstMatch(normalized);
  if (match == null) return null;
  return normalized.substring(match.end).trim();
}

VoiceCommand parseVoiceCommand(String text) {
  final command = normalizeVoiceText(text);
  if (command.isEmpty) return const VoiceCommand(VoiceCommandType.unknown);
  if (const {
    'help',
    'what can you do',
    'what can i say',
    'show commands',
  }.contains(command)) {
    return const VoiceCommand(VoiceCommandType.help);
  }
  if (RegExp(r'\b(stop|disable|turn off|pause)\b.*\b(wake|listening)\b')
      .hasMatch(command)) {
    return const VoiceCommand(VoiceCommandType.disableWakePhrase);
  }
  if (RegExp(r'\b(enable|turn on|start)\b.*\b(wake|listening)\b')
      .hasMatch(command)) {
    return const VoiceCommand(VoiceCommandType.enableWakePhrase);
  }

  if (RegExp(r'\b(microphone|mic|snap|whistle|motion)\b').hasMatch(command) &&
      RegExp(r'\b(turn on|enable|open|show)\b').hasMatch(command)) {
    final target = command.contains('motion') ? 'motion' : 'microphone';
    return VoiceCommand(VoiceCommandType.openSoundSettings, target);
  }

  if (RegExp(r'\b(play|preview)\b').hasMatch(command)) {
    const sounds = {
      'aurora chime': 'tone:chime',
      'chime': 'tone:chime',
      'bubble': 'tone:bubble',
      'bubble pop': 'tone:bubble',
      'glitch': 'tone:glitch',
      'pixel glitch': 'tone:glitch',
      'zap': 'tone:zap',
      'neon zap': 'tone:zap',
      'heartbeat': 'tone:heartbeat',
      'heart beat': 'tone:heartbeat',
      'whistle': 'tone:whistle',
      'snap': 'tone:snap',
      'tap': 'tone:tap',
      'like': 'tone:like',
    };
    for (final entry in sounds.entries) {
      if (command.contains(entry.key)) {
        return VoiceCommand(VoiceCommandType.previewSound, entry.value);
      }
    }
  }

  if (RegExp(r'\b(sound|music|studio)\b').hasMatch(command) &&
      RegExp(r'\b(open|go to|show|take me to|turn on)\b').hasMatch(command)) {
    return const VoiceCommand(VoiceCommandType.navigate, 'sound');
  }

  const destinations = {
    'feed': ['feed', 'home', 'posts'],
    'boards': ['boards', 'board', 'inspiration', 'art'],
    'search': ['search', 'explore'],
    'ranking': ['ranking', 'leaderboard', 'quests'],
    'notifications': ['notifications', 'notification', 'alerts'],
    'profile': ['profile', 'my page'],
    'dimension': ['dimension', 'escape room', 'sanctuary', 'underground'],
  };
  if (RegExp(r'\b(open|go to|show|take me to|navigate to)\b')
          .hasMatch(command) ||
      command.startsWith('my ')) {
    for (final entry in destinations.entries) {
      if (entry.value.any(command.contains)) {
        return VoiceCommand(VoiceCommandType.navigate, entry.key);
      }
    }
  }

  return const VoiceCommand(VoiceCommandType.unknown);
}

class VoiceAssistantController extends ChangeNotifier {
  VoiceAssistantController({required this.onCommand}) {
    _speech = SpeechToText();
    _tts = FlutterTts();
    _ttsReady = _configureTts();
  }

  final Future<String> Function(VoiceCommand command) onCommand;
  late final SpeechToText _speech;
  late final FlutterTts _tts;
  late final Future<void> _ttsReady;
  Timer? _restartTimer;
  VoiceAssistantMode mode = VoiceAssistantMode.idle;
  bool wakePhraseEnabled = false;
  bool isListening = false;
  String transcript = '';
  String response = 'Hi! I’m Qué. Tap to talk or enable the wake phrase.';
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isForeground = true;
  bool _isStarting = false;
  bool _handlingResult = false;
  bool _resumeWakeAfterReply = false;
  String? _ttsError;

  Future<void> _configureTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.48);
    } catch (error) {
      _ttsError = error.toString();
    }
  }

  Future<bool> _initialize() async {
    if (_isInitialized) return mode != VoiceAssistantMode.unavailable;
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!_isInitialized) {
        mode = VoiceAssistantMode.unavailable;
        response =
            'Speech recognition is not available in this browser or device.';
        _notify();
      }
      return _isInitialized;
    } catch (error) {
      mode = VoiceAssistantMode.unavailable;
      response = 'Could not start voice recognition: $error';
      _notify();
      return false;
    }
  }

  Future<void> setWakePhraseEnabled(bool enabled) async {
    if (_isDisposed) return;
    if (!enabled) {
      wakePhraseEnabled = false;
      _resumeWakeAfterReply = false;
      _restartTimer?.cancel();
      mode = VoiceAssistantMode.idle;
      isListening = false;
      _notify();
      if (_isInitialized) await _speech.stop();
      return;
    }

    if (!await _initialize()) return;
    wakePhraseEnabled = true;
    _resumeWakeAfterReply = false;
    transcript = '';
    await _startListening(VoiceAssistantMode.wakePhrase);
  }

  Future<void> startTapToTalk() async {
    if (_isDisposed ||
        mode == VoiceAssistantMode.command ||
        mode == VoiceAssistantMode.replying) {
      return;
    }
    if (!await _initialize()) return;
    _resumeWakeAfterReply = wakePhraseEnabled;
    _restartTimer?.cancel();
    mode = VoiceAssistantMode.idle;
    isListening = false;
    await _speech.stop();
    transcript = '';
    await _startListening(VoiceAssistantMode.command);
  }

  Future<void> stopListening() async {
    _restartTimer?.cancel();
    _resumeWakeAfterReply = false;
    wakePhraseEnabled = false;
    mode = VoiceAssistantMode.idle;
    isListening = false;
    _notify();
    if (_isInitialized) await _speech.stop();
  }

  Future<void> handleLifecycle(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      if (wakePhraseEnabled) {
        await _startListening(VoiceAssistantMode.wakePhrase);
      }
      return;
    }
    _isForeground = false;
    _restartTimer?.cancel();
    isListening = false;
    mode = VoiceAssistantMode.idle;
    _notify();
    if (_isInitialized) await _speech.stop();
  }

  Future<void> _startListening(VoiceAssistantMode listenMode) async {
    if (_isDisposed || !_isForeground || _isStarting || !_isInitialized) {
      return;
    }
    _isStarting = true;
    mode = listenMode;
    isListening = true;
    _notify();
    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          listenFor: listenMode == VoiceAssistantMode.wakePhrase
              ? const Duration(seconds: 45)
              : const Duration(seconds: 12),
          pauseFor: listenMode == VoiceAssistantMode.wakePhrase
              ? const Duration(seconds: 4)
              : const Duration(seconds: 3),
          partialResults: true,
          listenMode: ListenMode.confirmation,
          contextualPhrases: const [
            'Quexdc',
            'Qué',
            'Kweh',
            'boards',
            'sound studio',
            'notifications',
          ],
        ),
      );
    } catch (error) {
      isListening = false;
      mode = VoiceAssistantMode.idle;
      response = 'Could not listen: $error';
      _notify();
    } finally {
      _isStarting = false;
    }
  }

  void _onStatus(String status) {
    if (_isDisposed) return;
    isListening = status == SpeechToText.listeningStatus;
    _notify();
    if ((status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) &&
        mode == VoiceAssistantMode.wakePhrase &&
        wakePhraseEnabled) {
      _restartTimer?.cancel();
      _restartTimer = Timer(
        const Duration(milliseconds: 350),
        () => _startListening(VoiceAssistantMode.wakePhrase),
      );
    } else if ((status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) &&
        mode == VoiceAssistantMode.command &&
        _resumeWakeAfterReply) {
      response = 'I didn’t hear a request. Say the wake phrase to try again.';
      mode = VoiceAssistantMode.idle;
      _notify();
      _restartTimer?.cancel();
      _restartTimer = Timer(
        const Duration(milliseconds: 350),
        () => _startListening(VoiceAssistantMode.wakePhrase),
      );
    }
  }

  void _onError(dynamic error) {
    if (_isDisposed) return;
    final permanent = error.permanent == true;
    response = 'Voice recognition error: ${error.errorMsg ?? error}';
    isListening = false;
    if (permanent) {
      wakePhraseEnabled = false;
      _resumeWakeAfterReply = false;
      mode = VoiceAssistantMode.unavailable;
    }
    _notify();
  }

  void _onResult(dynamic result) {
    if (_isDisposed || _handlingResult) return;
    transcript = result.recognizedWords as String;
    _notify();
    if (result.finalResult != true) return;

    if (mode == VoiceAssistantMode.wakePhrase) {
      final commandText = extractWakePhraseCommand(transcript);
      if (commandText == null) return;
      _handlingResult = true;
      _restartTimer?.cancel();
      _resumeWakeAfterReply = wakePhraseEnabled;
      if (commandText.isEmpty) {
        unawaited(_greetAndListenForCommand());
      } else {
        unawaited(_processCommand(commandText));
      }
    } else if (mode == VoiceAssistantMode.command) {
      _handlingResult = true;
      unawaited(_processCommand(transcript));
    }
  }

  Future<void> _greetAndListenForCommand() async {
    mode = VoiceAssistantMode.replying;
    isListening = false;
    _notify();
    await _speech.stop();
    await _speak('I’m here. What would you like me to do?');
    if (!_isDisposed) {
      _handlingResult = false;
      await _startListening(VoiceAssistantMode.command);
    }
  }

  Future<void> _processCommand(String text) async {
    mode = VoiceAssistantMode.replying;
    isListening = false;
    _notify();
    _restartTimer?.cancel();
    await _speech.stop();
    final command = parseVoiceCommand(text);
    String reply;
    switch (command.type) {
      case VoiceCommandType.help:
        reply =
            'Say open feed, boards, sound, search, ranking, notifications, or profile. '
            'You can also say play chime, bubble, glitch, zap, or heartbeat.';
      case VoiceCommandType.enableWakePhrase:
        wakePhraseEnabled = true;
        _resumeWakeAfterReply = true;
        reply = 'Wake phrase is on. Say Hey Qué, Kweh, Keh, or Kay.';
      case VoiceCommandType.disableWakePhrase:
        wakePhraseEnabled = false;
        _resumeWakeAfterReply = false;
        reply = 'Wake phrase is off.';
      case VoiceCommandType.unknown:
        reply =
            'I didn’t catch a Quexdc command. Say help to hear what I can do.';
      case VoiceCommandType.navigate ||
          VoiceCommandType.previewSound ||
          VoiceCommandType.openSoundSettings:
        try {
          reply = await onCommand(command);
        } catch (error) {
          reply = 'I could not complete that: $error';
        }
    }
    await _speak(reply);
    _handlingResult = false;
    if (_isDisposed) return;
    if (wakePhraseEnabled || _resumeWakeAfterReply) {
      await _startListening(VoiceAssistantMode.wakePhrase);
    } else {
      mode = VoiceAssistantMode.idle;
      isListening = false;
      _notify();
    }
  }

  Future<void> _speak(String text) async {
    response = text;
    mode = VoiceAssistantMode.replying;
    _notify();
    try {
      await _ttsReady;
      if (_ttsError != null) {
        response = '$text (Spoken replies are unavailable: $_ttsError)';
        _notify();
        return;
      }
      await _tts.speak(text);
    } catch (error) {
      response = '$text (I could not play the spoken reply: $error)';
      _notify();
    }
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _restartTimer?.cancel();
    if (_isInitialized) unawaited(_speech.stop());
    unawaited(_tts.stop());
    super.dispose();
  }
}

class VoiceAssistantScreen extends StatelessWidget {
  const VoiceAssistantScreen({super.key, required this.controller});

  final VoiceAssistantController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final isWakeEnabled = controller.wakePhraseEnabled;
      final isListening = controller.isListening;
      return Scaffold(
        appBar: AppBar(title: const Text('Qué Voice Assistant')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Icon(
                        isListening ? Icons.graphic_eq : Icons.auto_awesome,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isListening
                          ? 'I’m listening…'
                          : 'Hey Qué, Kweh, Keh, or Kay',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      controller.transcript.isEmpty
                          ? controller.response
                          : 'You: ${controller.transcript}\n\nQué: ${controller.response}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: controller.mode == VoiceAssistantMode.command
                          ? controller.stopListening
                          : controller.startTapToTalk,
                      icon: Icon(
                        controller.mode == VoiceAssistantMode.command
                            ? Icons.stop
                            : Icons.mic,
                      ),
                      label: Text(
                        controller.mode == VoiceAssistantMode.command
                            ? 'Stop listening'
                            : 'Ask Qué',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.hearing),
                title: const Text('Wake phrase while Quexdc is open'),
                subtitle: Text(
                  isWakeEnabled
                      ? 'Listening for “Hey Qué”, “Kweh”, “Keh”, or “Kay”.'
                      : 'Off by default. Turn on to listen for your wake phrase.',
                ),
                value: isWakeEnabled,
                onChanged: controller.setWakePhraseEnabled,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Try saying',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '“Open my boards”\n'
                      '“Open notifications”\n'
                      '“Play the Aurora Chime”\n'
                      '“Turn on motion snap”\n'
                      '“Help”',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Voice commands can open app sections and preview sounds. '
                      'For safety, you must tap to enable microphone or motion triggers. '
                      'Wake listening pauses when Quexdc is in the background. '
                      'Speech recognition is provided by your browser or device and may use its online service.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
