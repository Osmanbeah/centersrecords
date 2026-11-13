import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanner_app/services/omr_engine.dart';

void main() {
  group('OMREngine Core Tests', () {
    test('checkQuality rejects tiny low-resolution images', () {
      final tinyImg = img.Image(width: 200, height: 200);
      final res = OMREngine.checkQuality(tinyImg);
      expect(res['passed'], isFalse);
      expect(res['reason'], 'LOW_RESOLUTION');
    });

    test('checkQuality rejects pitch-black images', () {
      final blackImg = img.Image(width: 800, height: 1000);
      img.fill(blackImg, color: img.ColorRgb8(10, 10, 10));
      final res = OMREngine.checkQuality(blackImg);
      expect(res['passed'], isFalse);
      expect(res['reason'], 'TOO_DARK');
    });

    test('classifyQuestion correctly detects a filled bubble B', () {
      const w = 200;
      const h = 50;
      final gray = Uint8List(w * h);
      // Fill with clean paper white (lum = 230)
      for (int i = 0; i < gray.length; i++) {
        gray[i] = 230;
      }

      final coords = {
        'A': const math.Point<int>(30, 25),
        'B': const math.Point<int>(70, 25),
        'C': const math.Point<int>(110, 25),
        'D': const math.Point<int>(150, 25),
      };

      // Draw bubble outlines (rings)
      coords.forEach((opt, pt) {
        for (int dy = -10; dy <= 10; dy++) {
          for (int dx = -10; dx <= 10; dx++) {
            final distSq = dx * dx + dy * dy;
            if (distSq >= 64 && distSq <= 100) {
              final py = pt.y + dy;
              final px = pt.x + dx;
              if (py >= 0 && py < h && px >= 0 && px < w) {
                gray[py * w + px] = 40; // dark border
              }
            }
          }
        }
      });

      // Fill option B with dark pencil mark (radius 7, lum = 25)
      final ptB = coords['B']!;
      for (int dy = -7; dy <= 7; dy++) {
        for (int dx = -7; dx <= 7; dx++) {
          if (dx * dx + dy * dy <= 49) {
            final py = ptB.y + dy;
            final px = ptB.x + dx;
            gray[py * w + px] = 25;
          }
        }
      }

      final result = OMREngine.classifyQuestion(gray, coords, w, h);
      expect(result.state, QuestionState.selected);
      expect(result.selected, 'B');
      expect(result.confidence, greaterThan(0.80));
    });

    test('classifyQuestion classifies all blank bubbles as EMPTY', () {
      const w = 200;
      const h = 50;
      final gray = Uint8List(w * h);
      for (int i = 0; i < gray.length; i++) {
        gray[i] = 230;
      }

      final coords = {
        'A': const math.Point<int>(30, 25),
        'B': const math.Point<int>(70, 25),
        'C': const math.Point<int>(110, 25),
        'D': const math.Point<int>(150, 25),
      };

      final result = OMREngine.classifyQuestion(gray, coords, w, h);
      expect(result.state, QuestionState.empty);
      expect(result.selected, isNull);
    });

    test('classifyQuestion classifies multiple dark marks as MULTIPLE', () {
      const w = 200;
      const h = 50;
      final gray = Uint8List(w * h);
      for (int i = 0; i < gray.length; i++) {
        gray[i] = 230;
      }

      final coords = {
        'A': const math.Point<int>(30, 25),
        'B': const math.Point<int>(70, 25),
        'C': const math.Point<int>(110, 25),
        'D': const math.Point<int>(150, 25),
      };

      // Fill both A and C
      for (final opt in ['A', 'C']) {
        final pt = coords[opt]!;
        for (int dy = -7; dy <= 7; dy++) {
          for (int dx = -7; dx <= 7; dx++) {
            if (dx * dx + dy * dy <= 49) {
              final py = pt.y + dy;
              final px = pt.x + dx;
              gray[py * w + px] = 20;
            }
          }
        }
      }

      final result = OMREngine.classifyQuestion(gray, coords, w, h);
      expect(result.state, QuestionState.multiple);
    });
  });
}
