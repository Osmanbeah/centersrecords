import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/exam.dart';

void main() {
  group('Student MCQ Edit & Recalculation Tests', () {
    final exam = Exam(
      id: 'test-exam-1',
      title: 'Math Test',
      questionCount: 5,
      mcqScorePerQ: 2.0,
      writtenMaxScore: 10.0,
      totalScore: 20.0,
      models: {
        'A': {1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'A'},
        'B': {1: 'B', 2: 'C', 3: 'D', 4: 'A', 5: 'B'},
      },
    );

    test('Editing student MCQ updates score correctly', () {
      final initialResult = ExamResult(
        examId: exam.id,
        studentCode: '1001',
        studentName: 'Ali Ahmed',
        center: 'Dokki',
        model: 'A',
        mcqScore: 4.0, // only Q1 & Q2 right (2 * 2.0 = 4.0)
        writtenScore: 5.0,
        totalScore: 9.0,
        studentAnswers: {'1': 'A', '2': 'B', '3': 'A', '4': 'A', '5': 'A'},
        assistantName: 'Ahmed Ragab (AST-01)',
        createdAt: DateTime.now().toIso8601String(),
      );

      expect(initialResult.assistantName, contains('Ahmed Ragab'));

      // Edit Q3 answer from 'A' to 'C' (now Q3 is correct!)
      final updatedAnswers = Map<String, String>.from(initialResult.studentAnswers);
      updatedAnswers['3'] = 'C';

      final keyA = exam.getAnswerKey('A')!;
      int newCorrect = 0;
      updatedAnswers.forEach((qStr, ans) {
        final q = int.parse(qStr);
        if (keyA[q] == ans) newCorrect++;
      });

      final newMcqScore = newCorrect * exam.mcqScorePerQ;
      final newTotalScore = newMcqScore + initialResult.writtenScore;

      final updatedResult = initialResult.copyWith(
        studentAnswers: updatedAnswers,
        mcqScore: newMcqScore,
        totalScore: newTotalScore,
      );

      expect(newCorrect, 4);
      expect(updatedResult.mcqScore, 8.0);
      expect(updatedResult.totalScore, 13.0);
      expect(updatedResult.studentAnswers['3'], 'C');
      expect(updatedResult.assistantName, 'Ahmed Ragab (AST-01)');
    });

    test('Changing exam model recalculates score according to new key', () {
      final initialResult = ExamResult(
        examId: exam.id,
        studentCode: '1002',
        studentName: 'Sara Ali',
        center: 'Maadi',
        model: 'A',
        mcqScore: 0.0,
        writtenScore: 0.0,
        totalScore: 0.0,
        studentAnswers: {'1': 'B', '2': 'C', '3': 'D', '4': 'A', '5': 'B'},
        assistantName: 'Sara (AST-02)',
        createdAt: DateTime.now().toIso8601String(),
      );

      // Model B key matches all answers!
      final keyB = exam.getAnswerKey('B')!;
      int correctB = 0;
      initialResult.studentAnswers.forEach((qStr, ans) {
        final q = int.parse(qStr);
        if (keyB[q] == ans) correctB++;
      });

      final updated = initialResult.copyWith(
        model: 'B',
        mcqScore: correctB * exam.mcqScorePerQ,
        totalScore: correctB * exam.mcqScorePerQ + initialResult.writtenScore,
      );

      expect(correctB, 5);
      expect(updated.mcqScore, 10.0);
      expect(updated.totalScore, 10.0);
    });
  });
}
