import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/services/api_service.dart';

class LessonService {
  Future<LessonContentModel> loadLesson({
    required String language,
    required String level,
    required LessonPlan lesson,
    required List<String> grammarTopics,
    required List<String> vocabTopics,
    required List<String> interests,
  }) {
    return ApiService.generateLesson(
      language: language,
      level: level,
      lessonTitle: lesson.title,
      grammarTopics: grammarTopics,
      vocabTopics: vocabTopics,
      interests: interests,
    );
  }
}
