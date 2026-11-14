import 'dart:io';
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
}
