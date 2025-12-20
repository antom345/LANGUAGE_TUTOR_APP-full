import 'dart:convert';
import 'package:http/http.dart' as http;

class AiCheckResult {
  final bool isCorrect;
  final int score;
  final String feedback;

  AiCheckResult({
    required this.isCorrect,
    required this.score,
    required this.feedback,
  });
}

class AiCheckService {
  final String base = "https://api.languagetutorapp.org"; 
  // если у тебя другой backend URL — впиши свой

  Future<AiCheckResult> checkAnswer({
    required String exerciseType,
    required String question,
    required String userAnswer,
    String? correctAnswer,
    String? sampleAnswer,
    String? evaluationCriteria,
    required String language,
  }) async {
    final res = await http.post(
      Uri.parse("$base/check_answer"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "exercise_type": exerciseType,
        "question": question,
        "user_answer": userAnswer,
        "correct_answer": correctAnswer,
        "sample_answer": sampleAnswer,
        "evaluation_criteria": evaluationCriteria,
        "language": language,
      }),
    );

    final data = jsonDecode(utf8.decode(res.bodyBytes));

    return AiCheckResult(
      isCorrect: data["is_correct"] ?? false,
      score: data["score"] ?? 0,
      feedback: data["feedback"] ?? "No feedback",
    );
  }
}
