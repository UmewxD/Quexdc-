import 'package:flutter_test/flutter_test.dart';
import 'package:social_media/voice_assistant.dart';

void main() {
  group('extractWakePhraseCommand', () {
    test('recognizes Que Qué spellings and returns the spoken command', () {
      expect(
        extractWakePhraseCommand('Hey Qué, open my boards'),
        'open my boards',
      );
      expect(extractWakePhraseCommand('Kweh play the chime'), 'play the chime');
      expect(extractWakePhraseCommand('Keh'), '');
      expect(
        extractWakePhraseCommand('Kay show notifications'),
        'show notifications',
      );
    });

    test('does not treat a wake phrase in the middle as activation', () {
      expect(extractWakePhraseCommand('open my boards, hey Qué'), isNull);
    });
  });

  group('parseVoiceCommand', () {
    test('maps app sections to navigation commands', () {
      expect(
        parseVoiceCommand('Open my boards'),
        const VoiceCommand(VoiceCommandType.navigate, 'boards'),
      );
      expect(
        parseVoiceCommand('Go to notifications'),
        const VoiceCommand(VoiceCommandType.navigate, 'notifications'),
      );
      expect(
        parseVoiceCommand('Open the Escape Dimension'),
        const VoiceCommand(VoiceCommandType.navigate, 'dimension'),
      );
    });

    test('maps sound requests to preview and safe settings commands', () {
      expect(
        parseVoiceCommand('Play the Aurora Chime'),
        const VoiceCommand(VoiceCommandType.previewSound, 'tone:chime'),
      );
      expect(
        parseVoiceCommand('Turn on motion snap'),
        const VoiceCommand(VoiceCommandType.openSoundSettings, 'motion'),
      );
    });

    test('supports help and wake phrase controls', () {
      expect(
        parseVoiceCommand('help'),
        const VoiceCommand(VoiceCommandType.help),
      );
      expect(
        parseVoiceCommand('turn off wake listening'),
        const VoiceCommand(VoiceCommandType.disableWakePhrase),
      );
      expect(
        parseVoiceCommand('turn on wake phrase'),
        const VoiceCommand(VoiceCommandType.enableWakePhrase),
      );
    });
  });
}
