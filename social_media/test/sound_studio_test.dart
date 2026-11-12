import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_media/sound_studio.dart';

void main() {
  group('SoundStudioSettings', () {
    test('includes free synth sounds in the assignable sound shelf', () {
      final settings = SoundStudioSettings.fromJson({
        'assignments': {SoundTrigger.snap: 'tone:chime'},
        'customSounds': [],
      });

      expect(settings.assignments[SoundTrigger.snap], 'tone:chime');
      expect(
        settings.availableSounds.map((sound) => sound.id),
        containsAll([
          'tone:chime',
          'tone:bubble',
          'tone:glitch',
          'tone:zap',
          'tone:heartbeat',
        ]),
      );
    });

    test('round-trips assignments and custom sound metadata', () {
      final settings = SoundStudioSettings(
        assignments: {
          SoundTrigger.snap: 'custom:clip-1',
          SoundTrigger.whistle: 'tone:whistle',
        },
        customSounds: const [
          SoundClip(
            id: 'custom:clip-1',
            name: 'My snap',
            path: 'data:audio/mpeg;base64,ZmFrZQ==',
            mimeType: 'audio/mpeg',
          ),
        ],
      );

      final restored = SoundStudioSettings.fromJson(settings.toJson());

      expect(restored.assignments[SoundTrigger.snap], 'custom:clip-1');
      expect(restored.assignments[SoundTrigger.whistle], 'tone:whistle');
      expect(restored.assignments[SoundTrigger.like], 'tone:like');
      expect(restored.customSounds.single.name, 'My snap');
      expect(
        restored.customSounds.single.path,
        settings.customSounds.single.path,
      );
    });

    test('replaces assignments to a removed sound with built-in tones', () {
      final restored = SoundStudioSettings.fromJson({
        'assignments': {SoundTrigger.snap: 'custom:missing'},
        'customSounds': [],
      });

      expect(restored.assignments[SoundTrigger.snap], 'tone:snap');
    });
  });

  group('GestureAudioDetector', () {
    test('allows repeated snaps at a rate that can detect a snap streak', () {
      final detector = GestureAudioDetector();
      final pcm = Int16List(512);
      pcm[180] = 26000;
      final bytes = Uint8List.view(pcm.buffer);
      final start = DateTime.utc(2026, 11, 10);

      for (var index = 0; index < 10; index++) {
        expect(
          detector.addPcm16(
            bytes,
            start.add(Duration(milliseconds: index * 400)),
          ),
          contains(GestureAudioEvent.snap),
        );
      }
    });

    test('detects an isolated sharp snap transient', () {
      final detector = GestureAudioDetector();
      final pcm = Int16List(512);
      pcm[180] = 26000;
      final bytes = Uint8List.view(pcm.buffer);

      expect(
        detector.addPcm16(bytes, DateTime.utc(2026, 11, 10)),
        contains(GestureAudioEvent.snap),
      );
    });

    test('keeps partial microphone frames until the next audio chunk', () {
      final detector = GestureAudioDetector();
      final pcm = Int16List(512);
      pcm[180] = 26000;
      final bytes = Uint8List.view(pcm.buffer);
      const splitAt = 300;
      final now = DateTime.utc(2026, 11, 10);

      expect(detector.addPcm16(bytes.sublist(0, splitAt), now), isEmpty);
      expect(
        detector.addPcm16(bytes.sublist(splitAt), now),
        contains(GestureAudioEvent.snap),
      );
    });

    test('detects a sustained whistle-like tone', () {
      final detector = GestureAudioDetector();
      const sampleRate = 16000;
      const frequency = 2500;
      final pcm = Int16List(512 * 5);
      for (var index = 0; index < pcm.length; index++) {
        pcm[index] =
            (math.sin(2 * math.pi * frequency * index / sampleRate) * 10000)
                .round();
      }

      expect(
        detector.addPcm16(
          Uint8List.view(pcm.buffer),
          DateTime.utc(2026, 11, 10),
        ),
        contains(GestureAudioEvent.whistle),
      );
    });
  });

  group('SnapStreakCounter', () {
    test(
      'fires on ten snaps within five seconds and resets after the streak',
      () {
        final counter = SnapStreakCounter();
        final start = DateTime.utc(2026, 11, 10);

        for (var index = 0; index < 9; index++) {
          expect(
            counter.record(start.add(Duration(milliseconds: index * 400))),
            isFalse,
          );
        }
        expect(
          counter.record(start.add(const Duration(milliseconds: 3600))),
          isTrue,
        );
        expect(
          counter.record(start.add(const Duration(milliseconds: 3700))),
          isFalse,
        );
      },
    );

    test('drops snaps older than the five-second rolling window', () {
      final counter = SnapStreakCounter();
      final start = DateTime.utc(2026, 11, 10);

      for (var index = 0; index < 9; index++) {
        counter.record(start.add(Duration(milliseconds: index * 400)));
      }
      expect(counter.record(start.add(const Duration(seconds: 9))), isFalse);
    });
  });
}
