class Exam {
  final String id;
  final String title;
  final String subject;
  final String examDate;
  final String center;
  final int questionCount;
  final double mcqScorePerQ;
  final double writtenMaxScore;
  final double totalScore;
  final Map<String, Map<int, String>> models;
  final String status;

  Exam({
    required this.id,
    required this.title,
    this.subject = '',
    this.examDate = '',
    this.center = 'All Centers',
    this.questionCount = 30,
    this.mcqScorePerQ = 1.0,
    this.writtenMaxScore = 0.0,
    this.totalScore = 30.0,
    this.models = const {},
    this.status = 'active',
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    final rawModels = json['models'];
    final parsedModels = <String, Map<int, String>>{};

    if (rawModels is Map) {
      rawModels.forEach((modelKey, val) {
        if (val is Map) {
          final qMap = <int, String>{};
          val.forEach((qKey, ansVal) {
            final qNum = int.tryParse(qKey.toString());
            if (qNum != null && ansVal != null) {
              qMap[qNum] = ansVal.toString().trim().toUpperCase();
            }
          });
          parsedModels[modelKey.toString()] = qMap;
        }
      });
    }

    return Exam(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Exam',
      subject: json['subject']?.toString() ?? '',
      examDate: json['exam_date']?.toString() ?? '',
      center: json['center']?.toString() ?? 'All Centers',
      questionCount: (json['question_count'] as num?)?.toInt() ?? 30,
      mcqScorePerQ: (json['mcq_score_per_q'] as num?)?.toDouble() ?? 1.0,
      writtenMaxScore: (json['written_max_score'] as num?)?.toDouble() ?? 0.0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 30.0,
      models: parsedModels,
      status: json['status']?.toString() ?? 'active',
    );
  }

  Map<int, String>? getAnswerKey(String modelLetter) {
    return models[modelLetter.toUpperCase()];
  }
}

class ExamResult {
  final String? id;
  final String examId;
  final String studentCode;
  final String studentName;
  final String center;
  final String model;
  final double mcqScore;
  final double writtenScore;
  final double totalScore;
  final Map<String, String> studentAnswers;
  final String assistantName;
  final String createdAt;

  ExamResult({
    this.id,
    required this.examId,
    required this.studentCode,
    required this.studentName,
    required this.center,
    required this.model,
    required this.mcqScore,
    required this.writtenScore,
    required this.totalScore,
    required this.studentAnswers,
    required this.assistantName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'exam_id': examId,
    'student_code': studentCode,
    'student_name': studentName,
    'center': center,
    'model': model,
    'mcq_score': mcqScore,
    'written_score': writtenScore,
    'total_score': totalScore,
    'student_answers': studentAnswers,
    'assistant_name': assistantName,
    'created_at': createdAt,
  };

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    final rawAns = json['student_answers'];
    final ansMap = <String, String>{};
    if (rawAns is Map) {
      rawAns.forEach((k, v) {
        ansMap[k.toString()] = v?.toString() ?? '';
      });
    }

    return ExamResult(
      id: json['id']?.toString(),
      examId: json['exam_id']?.toString() ?? '',
      studentCode: json['student_code']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      center: json['center']?.toString() ?? '',
      model: json['model']?.toString() ?? 'A',
      mcqScore: (json['mcq_score'] as num?)?.toDouble() ?? 0.0,
      writtenScore: (json['written_score'] as num?)?.toDouble() ?? 0.0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
      studentAnswers: ansMap,
      assistantName: json['assistant_name']?.toString() ?? 'Assistant',
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}
