import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/services/omr_engine.dart';

void main() {
  test('Empty bubbles shifted by (3, 3) must snap to (x+3, y+3)', () {
    const w = 300;
    const h = 100;
    final gray = Uint8List(w * h);
    for (int i = 0; i < gray.length; i++) {
      gray[i] = 230;
    }

    final coords = {
      'A': const math.Point<int>(50, 50),
      'B': const math.Point<int>(100, 50),
      'C': const math.Point<int>(150, 50),
      'D': const math.Point<int>(200, 50),
    };

    // Draw empty bubble outlines shifted by dx=+3, dy=+3
    const shiftX = 3;
    const shiftY = 3;
    coords.forEach((opt, pt) {
      final actualCenter = math.Point(pt.x + shiftX, pt.y + shiftY);
      for (int dy = -10; dy <= 10; dy++) {
        for (int dx = -10; dx <= 10; dx++) {
          final distSq = dx * dx + dy * dy;
          if (distSq >= 64 && distSq <= 100) {
            final py = actualCenter.y + dy;
            final px = actualCenter.x + dx;
            if (py >= 0 && py < h && px >= 0 && px < w) {
              gray[py * w + px] = 40;
            }
          }
        }
      }
    });

    final result = OMREngine.classifyQuestion(gray, coords, w, h);

    expect(result.state, QuestionState.empty);
    expect(result.snappedCoords['A']!.x, 53);
    expect(result.snappedCoords['A']!.y, 53);
  });
}
