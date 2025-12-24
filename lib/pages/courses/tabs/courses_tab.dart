import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/screens/map/lesson_screen.dart';
import 'package:language_tutor_app/screens/map/map_controller.dart';
import 'package:language_tutor_app/screens/map/map_screen.dart';
import 'package:language_tutor_app/services/api_service.dart';
import 'package:language_tutor_app/ui/widgets/buttons.dart';
import 'package:language_tutor_app/ui/widgets/gradient_card.dart';

class CoursesTab extends StatefulWidget {
  final String learningLanguage;
  final String userLevel;
  final int userAge;
  final String userGender;
  final List<String> userInterests;

  const CoursesTab({
    super.key,
    required this.learningLanguage,
    required this.userLevel,
    required this.userAge,
    required this.userGender,
    required this.userInterests,
  });

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  CoursePlan? _coursePlan;
  bool _isLoading = false;
  String? _courseError;
  final Set<String> _completedLessons = {};

  @override
  void initState() {
    super.initState();
    _loadCoursePlan();
  }

  @override
  void didUpdateWidget(covariant CoursesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.learningLanguage != widget.learningLanguage) {
      _coursePlan = null;
      _completedLessons.clear();
      _loadCoursePlan();
    }
  }

  Future<void> _loadCoursePlan() async {
    if (_isLoading || _coursePlan != null) return;
    setState(() {
      _isLoading = true;
      _courseError = null;
    });

    try {
      final gender =
          widget.userGender == 'unspecified' ? null : widget.userGender;
      final plan = await _retry<CoursePlan>(
        2,
        () => ApiService.generateCoursePlan(
          language: widget.learningLanguage,
          levelHint: widget.userLevel,
          age: widget.userAge,
          gender: gender,
          interests: widget.userInterests,
          goals:
              'Improve ${widget.learningLanguage} through conversation and vocabulary.',
        ),
      );
      setState(() {
        _coursePlan = plan;
      });
    } catch (e) {
      setState(() {
        _courseError =
            'Не удалось сформировать курс. Попробуйте ещё раз чуть позже.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _coursePlan;
    final look = _buildFallbackLook(theme);

    Widget buildLessonCards(List<MapLessonPoint> lessons) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lessons.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final lessonPoint = lessons[index];
          final lesson = lessonPoint.lesson;
          final level = lessonPoint.level.levelIndex;
          final completed =
              _completedLessons.contains('${lessonPoint.level.title}-${lesson.title}');
          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LessonScreen(
                    language: plan?.language ?? widget.learningLanguage,
                    level: widget.userLevel,
                    lesson: lesson,
                    grammarTopics: lesson.grammarTopics,
                    vocabTopics: lesson.vocabTopics,
                    userInterests: widget.userInterests,
                    onComplete: (total, done) {
                      setState(() {
                        _completedLessons
                            .add('${lessonPoint.level.title}-${lesson.title}');
                      });
                    },
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    look.primaryColor.withOpacity(0.08),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: look.accentColor.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Урок ${index + 1} · Level $level',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lesson.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lesson.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lesson.experienceLine.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            lesson.experienceLine,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: look.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    completed ? Icons.check_circle : Icons.chevron_right,
                    color: completed ? Colors.green : Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (plan == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Карта курсов',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                GradientCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сформируйте курс на основе ваших целей и предпочтений.',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Мы подберём уроки и построим карту с персонажем.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Сформировать курс',
                        expand: false,
                        onPressed: _loadCoursePlan,
                      ),
                      if (_courseError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _courseError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final List<MapLessonPoint> mapLessons = [];
    for (final level in plan.levels) {
      for (final lesson in level.lessons) {
        mapLessons.add(MapLessonPoint(level: level, lesson: lesson));
      }
    }
    final takeCount = math.min(mapLessons.length, lessonPositions.length);
    final positionedLessons = <MapLessonPoint>[];
    for (var i = 0; i < takeCount; i++) {
      positionedLessons.add(
        mapLessons[i].copyWithPosition(lessonPositions[i]),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Уроки',
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return DraggableScrollableSheet(
                        initialChildSize: 0.6,
                        minChildSize: 0.4,
                        maxChildSize: 0.95,
                        builder: (context, scrollController) {
                          return Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 16),
                              child: SingleChildScrollView(
                                controller: scrollController,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 48,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade400,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Уроки курса',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 12),
                                    buildLessonCards(
                                        mapLessons.take(20).toList()),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: MapScreen(
              language: plan.language,
              userLevel: widget.userLevel,
              plan: plan,
              look: look,
              lessons: positionedLessons,
              completedLessons: _completedLessons,
              userInterests: widget.userInterests,
              onLessonCompleted: (lessonKey) {
                setState(() {
                  _completedLessons.add(lessonKey);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<T> _retry<T>(int times, Future<T> Function() action) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await action();
      } catch (e) {
        if (attempt > times) rethrow;
      }
    }
  }

  CharacterLook _buildFallbackLook(ThemeData theme) {
    final lang = widget.learningLanguage.trim();
    final badge = lang.isEmpty
        ? 'LN'
        : (lang.length >= 2
            ? lang.substring(0, 2).toUpperCase()
            : lang.toUpperCase());
    final isMale = widget.userGender.toLowerCase() == 'male';
    return CharacterLook(
      primaryColor: theme.colorScheme.primary.withOpacity(0.08),
      accentColor: theme.colorScheme.primary,
      hairColor: isMale ? Colors.brown.shade700 : Colors.brown.shade500,
      outfitColor: theme.colorScheme.secondary.withOpacity(0.8),
      skinColor: const Color(0xFFF1C27D),
      narrowEyes: false,
      longHair: !isMale,
      badgeText: badge,
    );
  }
}
