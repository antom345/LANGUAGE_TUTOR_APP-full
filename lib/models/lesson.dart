class LessonPlan {
  final String id;
  final String title;
  final String type;
  final String description;
  final List<String> grammarTopics;
  final List<String> vocabTopics;

  LessonPlan({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.grammarTopics,
    required this.vocabTopics,
  });

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    return LessonPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      grammarTopics:
          (json['grammar_topics'] as List<dynamic>?)?.cast<String>() ?? const [],
      vocabTopics:
          (json['vocab_topics'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

class LessonExercise {
  final String id;

  /// multiple_choice / translate_sentence / fill_in_blank / reorder_words
  final String type;

  /// Общий текст вопроса / задания
  final String? instruction;
  final String question;

  /// Объяснение после проверки
  final String explanation;

  /// Только для multiple_choice
  final List<String>? options;
  final int? correctIndex;

  /// Для translate_sentence и fill_in_blank
  final String? correctAnswer;
  final String? sentenceWithGap;

  /// Для reorder_words
  final List<String>? reorderWords;
  final List<String>? reorderCorrect;

  LessonExercise({
    required this.id,
    required this.type,
    required this.question,
    required this.explanation,
    this.instruction,
    this.options,
    this.correctIndex,
    this.correctAnswer,
    this.sentenceWithGap,
    this.reorderWords,
    this.reorderCorrect,
  });

  factory LessonExercise.fromJson(Map<String, dynamic> json) {
    final optionsList = (json['options'] as List?)?.cast<dynamic>();
    final reorderWordsRaw = (json['reorder_words'] as List?)?.cast<dynamic>();
    final reorderCorrectRaw =
        (json['reorder_correct'] as List?)?.cast<dynamic>();
    return LessonExercise(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString(),
      instruction: (json['instruction'] as String?)?.trim(),
      options: optionsList?.map((e) => e.toString()).toList(),
      correctIndex: json['correct_index'] is int
          ? json['correct_index'] as int
          : int.tryParse(json['correct_index']?.toString() ?? ''),
      correctAnswer: (json['correct_answer'] as String?)?.trim(),
      sentenceWithGap: (json['sentence_with_gap'] as String?)?.trim(),
      reorderWords:
          reorderWordsRaw?.map((e) => e.toString()).toList(growable: false),
      reorderCorrect:
          reorderCorrectRaw?.map((e) => e.toString()).toList(growable: false),
    );
  }
}

class LessonContentModel {
  final String lessonId;
  final String lessonTitle;
  final String description;
  final List<LessonExercise> exercises;

  LessonContentModel({
    required this.lessonId,
    required this.lessonTitle,
    required this.description,
    required this.exercises,
  });

  factory LessonContentModel.fromJson(Map<String, dynamic> json) {
    final exercisesJson =
        (json['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return LessonContentModel(
      lessonId: (json['lesson_id'] ?? '').toString(),
      lessonTitle: (json['lesson_title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      exercises: exercisesJson.map(LessonExercise.fromJson).toList(),
    );
  }
}

class CourseLevelPlan {
  final int levelIndex;
  final String title;
  final String description;
  final List<String> targetGrammar;
  final List<String> targetVocab;
  final List<LessonPlan> lessons;

  CourseLevelPlan({
    required this.levelIndex,
    required this.title,
    required this.description,
    required this.targetGrammar,
    required this.targetVocab,
    required this.lessons,
  });

  factory CourseLevelPlan.fromJson(Map<String, dynamic> json) {
    final grammar = (json['target_grammar'] as List).cast<String>();
    final vocab = (json['target_vocab'] as List).cast<String>();
    final lessonsJson = (json['lessons'] as List).cast<Map<String, dynamic>>();

    return CourseLevelPlan(
      levelIndex: json['level_index'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      targetGrammar: grammar,
      targetVocab: vocab,
      lessons: lessonsJson.map((e) => LessonPlan.fromJson(e)).toList(),
    );
  }
}

class CoursePlan {
  final String language;
  final String overallLevel;
  final List<CourseLevelPlan> levels;

  CoursePlan({
    required this.language,
    required this.overallLevel,
    required this.levels,
  });

  factory CoursePlan.fromJson(Map<String, dynamic> json) {
    final levelsJson = (json['levels'] as List).cast<Map<String, dynamic>>();
    return CoursePlan(
      language: json['language'] as String,
      overallLevel: json['overall_level'] as String,
      levels: levelsJson.map((e) => CourseLevelPlan.fromJson(e)).toList(),
    );
  }
}

class PlacementQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  PlacementQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}
