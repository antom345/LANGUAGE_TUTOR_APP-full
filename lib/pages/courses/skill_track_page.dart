import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/models/skill_track.dart';
import 'package:language_tutor_app/screens/map/lesson_screen.dart';
import 'package:language_tutor_app/services/api_service.dart';

class SkillTrackPage extends StatefulWidget {
  final String language;
  final SkillTrack track;
  final String userLevel;
  final int userAge;
  final String userGender;
  final List<String> userInterests;

  const SkillTrackPage({
    super.key,
    required this.language,
    required this.track,
    required this.userLevel,
    required this.userAge,
    required this.userGender,
    required this.userInterests,
  });

  @override
  State<SkillTrackPage> createState() => _SkillTrackPageState();
}

class _SkillTrackPageState extends State<SkillTrackPage> {
  bool _loading = false;
  String? _error;
  List<SkillLesson> _lessons = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final lessons = await ApiService.fetchSkillLessons(
        widget.language,
        widget.track.id,
      );
      setState(() {
        _lessons = lessons;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить уроки навыка.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.track.title),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_lessons.isEmpty) {
      return const Center(child: Text('Пока нет уроков для этого навыка.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _lessons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        final progress = (lesson.progress / 100).clamp(0.0, 1.0);
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              final plan = LessonPlan(
                id: lesson.lessonId,
                title: lesson.title,
                type: 'skill',
                description: '',
                grammarTopics: const [],
                vocabTopics: const [],
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LessonScreen(
                    language: widget.language,
                    level: widget.userLevel,
                    lesson: plan,
                    grammarTopics: plan.grammarTopics,
                    vocabTopics: plan.vocabTopics,
                    userInterests: widget.userInterests,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lesson.progress}%',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
