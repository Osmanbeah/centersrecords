import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanner_app/services/omr_engine.dart';

void main() {
  test('Scan phone capture media_1794669074855_e5c3d4d7.png with 100% accuracy', () {
    final file = File(r'C:\Users\Admin\.gemini\antigravity\brain\e32c0684-da8a-471a-bd36-7a5b793303a5\.user_uploaded\media_1794669074855_e5c3d4d7.png');
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes)!;
    final res = OMREngine.scanImage(decoded, 15);

    expect(res.success, isTrue, reason: res.message ?? res.error);
    expect(res.model, 'B');
    expect(res.modelDetected, isTrue);
    expect(res.studentCode, '12345');

    const expectedAnswers = {
      1: 'A',
      2: 'A',
      3: 'A',
      4: 'A',
      5: 'B',
      6: 'C',
      7: 'C',
      8: 'C',
      9: 'C',
      10: 'B',
      11: 'D',
      12: 'C',
      // Q13 has both B and C marked in the screenshot image
      14: 'A',
      15: 'B',
    };

    for (final entry in expectedAnswers.entries) {
      expect(
        res.answers[entry.key]?.selected,
        entry.value,
        reason: 'Question ${entry.key} expected ${entry.value} but got ${res.answers[entry.key]?.selected}',
      );
      expect(res.answers[entry.key]?.state, QuestionState.selected);
    }

    // Verify Q13 correctly flags multiple marks
    expect(res.answers[13]?.state, QuestionState.multiple);
    expect(res.answers[13]?.multipleSelected, containsAll(['B', 'C']));
  });
  test('EvalBee alignment checker detects 4 fiducial corners and isAligned=true', () {
    final file = File(r'C:\Users\Admin\.gemini\antigravity\brain\e32c0684-da8a-471a-bd36-7a5b793303a5\.user_uploaded\media_1794669074855_e5c3d4d7.png');
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes)!;
    final alignment = OMREngine.checkAlignmentFromImage(decoded);

    expect(alignment.isAligned, isTrue);
    expect(alignment.visibleCornersCount, 4);
    expect(alignment.detectedCorners, isNotNull);
    expect(alignment.detectedCorners!.length, 4);
  });

  test('11-digit phone number layout generates 11 columns with 10 digits each', () {
    final layout11 = OMREngine.computeBubbleLayout(14, idDigits: 11, hasCenterQuestions: false);
    expect(layout11.rollCoords.length, 11);
    for (final col in layout11.rollCoords) {
      expect(col.length, 10);
    }
    // Verify calibrated canonical coordinates from PDF
    expect(layout11.rollCoords.first.first.x, 196);
    expect(layout11.rollCoords.last.first.x, 544);
    expect(layout11.rollCoords.first.first.y, 681);
    expect(layout11.rollCoords.first.last.y, 1035);
    expect(layout11.modelCoords['A']?.x, 356);
    expect(layout11.modelCoords['A']?.y, 476);
    expect(layout11.questionCoords[1]?['A']?.x, 770);
    expect(layout11.questionCoords[1]?['A']?.y, 635);
    expect(layout11.cornerMarkers.first, const math.Point(104, 92));
    expect(layout11.cornerMarkers[2], const math.Point(1098, 1593));
  });

  test('Scan canonical template rendered from Bubble Sheet7 - statics part 2.pdf', () {
    final file = File('canonical_pdf_render.png').existsSync()
        ? File('canonical_pdf_render.png')
        : File('../canonical_pdf_render.png');
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes)!;

    // Test live alignment check on canonical template
    final alignment = OMREngine.checkAlignmentFromImage(decoded);
    expect(alignment.isAligned, isTrue);
    expect(alignment.visibleCornersCount, 4);

    // Test full OMR scan on canonical template
    final res = OMREngine.scanImage(decoded, 14, null, 11, false);
    expect(res.success, isTrue, reason: res.message ?? res.error);
    expect(res.model, 'C');
    expect(res.modelDetected, isTrue);
    expect(res.studentCode, '01125098795');
    expect(res.answers[1]?.selected, 'C');
    expect(res.answers[2]?.selected, 'C');
    expect(res.answers[3]?.selected, 'C');
    expect(res.answers[4]?.selected, 'C');
    expect(res.answers[5]?.selected, 'C');
    expect(res.answers[6]?.selected, 'B');
    expect(res.answers[7]?.selected, 'A');
    expect(res.answers[9]?.selected, 'C');
    expect(res.answers[10]?.selected, 'C');
    expect(res.answers[11]?.selected, 'D');
    expect(res.answers[12]?.selected, 'C');
    expect(res.answers[13]?.selected, 'C');
    expect(res.answers[14]?.selected, 'C');
  });
}
