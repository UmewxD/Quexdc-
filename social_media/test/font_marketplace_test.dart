import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_media/font_marketplace.dart';

void main() {
  group('FontMarketplaceService.validateFontFile', () {
    test('accepts a TrueType font signature', () {
      expect(
        () => FontMarketplaceService.validateFontFile(
          'sample.ttf',
          Uint8List.fromList([0x00, 0x01, 0x00, 0x00]),
        ),
        returnsNormally,
      );
    });

    test('accepts an OpenType font signature', () {
      expect(
        () => FontMarketplaceService.validateFontFile(
          'sample.otf',
          Uint8List.fromList([0x4f, 0x54, 0x54, 0x4f]),
        ),
        returnsNormally,
      );
    });

    test('rejects mismatched font file contents', () {
      expect(
        () => FontMarketplaceService.validateFontFile(
          'sample.ttf',
          Uint8List.fromList([0x4f, 0x54, 0x54, 0x4f]),
        ),
        throwsFormatException,
      );
    });

    test('rejects unsupported extensions and files larger than 5 MB', () {
      expect(
        () => FontMarketplaceService.validateFontFile(
          'sample.txt',
          Uint8List.fromList([0x00, 0x01, 0x00, 0x00]),
        ),
        throwsFormatException,
      );
      expect(
        () => FontMarketplaceService.validateFontFile(
          'large.ttf',
          Uint8List(5 * 1024 * 1024 + 1),
        ),
        throwsFormatException,
      );
    });
  });
}
