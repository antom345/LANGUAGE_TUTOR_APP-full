import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/screens/chat/character_conversation_screen.dart';
import 'package:language_tutor_app/screens/home/learning_language_select_screen.dart';
import 'package:language_tutor_app/screens/map/map_screen.dart';
import 'package:language_tutor_app/services/api_service.dart';
import 'package:language_tutor_app/services/character_service.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:language_tutor_app/ui/widgets/app_scaffold.dart';
import 'package:language_tutor_app/ui/widgets/buttons.dart';
import 'package:language_tutor_app/ui/widgets/gradient_card.dart';
import 'package:language_tutor_app/screens/map/map_controller.dart';
import 'package:language_tutor_app/screens/map/lesson_screen.dart';
import 'dart:math' as math;

class HomeShell extends StatefulWidget {
  final int userAge;
  final String userGender;
  final List<String> userInterests;
  final String learningLanguage;

  const HomeShell({
    super.key,
    required this.userAge,
    required this.userGender,
    this.userInterests = const [],
    required this.learningLanguage,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late String _learningLanguage;
  static const _defaultLevel = 'B2';

  @override
  void initState() {
    super.initState();
    _learningLanguage = widget.learningLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _index,
        children: [
          CharacterConversationScreen(
            learningLanguage: _learningLanguage,
            partnerLanguage: _learningLanguage,
            level: _defaultLevel,
            topic: 'General conversation',
            userGender: widget.userGender,
            userAge: widget.userAge,
            partnerGender: 'male',
          ),
          MapTab(
            learningLanguage: _learningLanguage,
            userLevel: _defaultLevel,
            userAge: widget.userAge,
            userGender: widget.userGender,
            userInterests: widget.userInterests,
          ),
          ProfileScreen(
            age: widget.userAge,
            gender: widget.userGender,
            interests: widget.userInterests,
            learningLanguage: _learningLanguage,
            onChangeLanguage: (lang) {
              setState(() {
                _learningLanguage = lang;
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Диалог',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Карта',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    switch (_index) {
      case 1:
        return AppBar(
          title: const Text('Карта курсов'),
          centerTitle: true,
        );
      case 2:
        return AppBar(
          title: const Text('Профиль'),
          centerTitle: true,
        );
      case 0:
      default:
        return AppBar(
          title: const Text('Диалог'),
          centerTitle: true,
        );
    }
  }
}

class MapTab extends StatefulWidget {
  final String learningLanguage;
  final String userLevel;
  final int userAge;
  final String userGender;
  final List<String> userInterests;

  const MapTab({
    super.key,
    required this.learningLanguage,
    required this.userLevel,
    required this.userAge,
    required this.userGender,
    required this.userInterests,
  });

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
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
  void didUpdateWidget(covariant MapTab oldWidget) {
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
    final look = characterLookFor(
      widget.learningLanguage,
      widget.userGender == 'female' ? 'female' : 'male',
    );

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
}
class ProfileScreen extends StatelessWidget {
  final int age;
  final String gender;
  final List<String> interests;
  final String learningLanguage;
  final ValueChanged<String> onChangeLanguage;

  const ProfileScreen({
    super.key,
    required this.age,
    required this.gender,
    required this.interests,
    required this.learningLanguage,
    required this.onChangeLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.colorPrimary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.colorPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ваш аккаунт',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Возраст: $age · Пол: $gender',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Изучаемый язык: $learningLanguage',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: const Text('Цель: говорить свободно'),
                        backgroundColor:
                            AppColors.colorAccentBlue.withOpacity(0.14),
                      ),
                      Chip(
                        label: const Text('Уровень: B2'),
                        backgroundColor:
                            AppColors.colorAccentGreen.withOpacity(0.18),
                      ),
                      if (interests.isNotEmpty)
                        Chip(
                          label: Text('Интересы: ${interests.join(", ")}'),
                          backgroundColor:
                              AppColors.colorPrimary.withOpacity(0.12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Изменить язык',
                          expand: true,
                          onPressed: () async {
                            final lang = await Navigator.of(context).push(
                              MaterialPageRoute<String>(
                                builder: (_) => LearningLanguageSelectScreen(
                                  initialLanguage: learningLanguage,
                                  returnSelectionOnly: true,
                                ),
                              ),
                            );
                            if (lang is String && lang.isNotEmpty) {
                              onChangeLanguage(lang);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Изменить цель',
                          expand: true,
                          onPressed: () => _showStub(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Выйти',
                          expand: true,
                          onPressed: () => _showStub(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStub(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Скоро добавим действие'),
      ),
    );
  }
}
