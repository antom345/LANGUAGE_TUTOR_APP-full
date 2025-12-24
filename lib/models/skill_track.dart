class SkillTrack {
  final String id;
  final String title;
  final String? description;
  final int lessonsCount;
  final int xp;
  final int xpGoal;

  SkillTrack({
    required this.id,
    required this.title,
    this.description,
    required this.lessonsCount,
    required this.xp,
    required this.xpGoal,
  });

  factory SkillTrack.fromJson(Map<String, dynamic> json) {
    return SkillTrack(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description'] as String?,
      lessonsCount: json['lessonsCount'] is int
          ? json['lessonsCount'] as int
          : int.tryParse(json['lessonsCount']?.toString() ?? '') ?? 0,
      xp: json['xp'] is int ? json['xp'] as int : int.tryParse(json['xp']?.toString() ?? '') ?? 0,
      xpGoal: json['xpGoal'] is int
          ? json['xpGoal'] as int
          : int.tryParse(json['xpGoal']?.toString() ?? '') ?? 0,
    );
  }
}

class SkillLesson {
  final String lessonId;
  final String title;
  final int progress; // 0..100

  SkillLesson({
    required this.lessonId,
    required this.title,
    required this.progress,
  });

  factory SkillLesson.fromJson(Map<String, dynamic> json) {
    return SkillLesson(
      lessonId: (json['lessonId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      progress: json['progress'] is int
          ? json['progress'] as int
          : int.tryParse(json['progress']?.toString() ?? '') ?? 0,
    );
  }
}
