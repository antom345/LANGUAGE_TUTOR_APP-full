import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/skill_track.dart';
import 'package:language_tutor_app/pages/courses/skill_track_page.dart';
import 'package:language_tutor_app/services/api_service.dart';

class SkillsTab extends StatefulWidget {
  final String learningLanguage;
  final String userLevel;
  final int userAge;
  final String userGender;
  final List<String> userInterests;

  const SkillsTab({
    super.key,
    required this.learningLanguage,
    required this.userLevel,
    required this.userAge,
    required this.userGender,
    required this.userInterests,
  });

  @override
  State<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends State<SkillsTab> {
  bool _loading = false;
  String? _error;
  List<SkillTrack> _tracks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SkillsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.learningLanguage != widget.learningLanguage) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracks =
          await ApiService.fetchSkillTracks(widget.learningLanguage);
      setState(() {
        _tracks = tracks;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить навыки. Попробуйте позже.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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

    if (_tracks.isEmpty) {
      return const Center(
        child: Text('Навыки пока недоступны.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final track = _tracks[index];
        final progress =
            track.xpGoal == 0 ? 0.0 : (track.xp / track.xpGoal).clamp(0.0, 1.0);
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SkillTrackPage(
                    language: widget.learningLanguage,
                    track: track,
                    userLevel: widget.userLevel,
                    userAge: widget.userAge,
                    userGender: widget.userGender,
                    userInterests: widget.userInterests,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (track.description != null &&
                      track.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      track.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Уроков: ${track.lessonsCount}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${track.xp} / ${track.xpGoal} XP',
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
