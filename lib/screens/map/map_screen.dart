import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/screens/map/character_widget.dart';
import 'package:language_tutor_app/screens/map/lesson_flag.dart';
import 'package:language_tutor_app/screens/map/map_controller.dart';
import 'package:language_tutor_app/utils/constants.dart';
import 'package:language_tutor_app/widgets/character_avatar.dart';

import 'lesson_screen.dart';

class MapScreenArgs {
  final String language;
  final String userLevel;
  final CoursePlan plan;
  final CharacterLook look;
  final List<MapLessonPoint> lessons;
  final Set<String> completedLessons;
  final List<String> userInterests;
  final void Function(String lessonKey) onLessonCompleted;

  MapScreenArgs({
    required this.language,
    required this.userLevel,
    required this.plan,
    required this.look,
    required this.lessons,
    required this.completedLessons,
    required this.userInterests,
    required this.onLessonCompleted,
  });
}

class MapScreen extends StatefulWidget {
  final String language;
  final String userLevel;
  final CoursePlan plan;
  final CharacterLook look;
  final List<MapLessonPoint> lessons;
  final Set<String> completedLessons;
  final List<String> userInterests;
  final void Function(String lessonKey) onLessonCompleted;

  const MapScreen({
    super.key,
    required this.language,
    required this.userLevel,
    required this.plan,
    required this.look,
    required this.lessons,
    required this.completedLessons,
    required this.userInterests,
    required this.onLessonCompleted,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _moveController;
  late final MapController _mapController;
  Animation<Offset>? _moveAnimation;
  MapPosition _characterPosition = initialCharacterPosition;
  MapLessonPoint? _pendingLesson;
  bool _isMoving = false;

  List<String> _idleFrames = const [];
  List<String> _walkFrames = const [];
  List<String> _happyFrames = const [];
  List<String> _sadFrames = const [];
  Timer? _frameTimer;
  Timer? _happyTimer;
  int _frameIndex = 0;
  MapCharacterMood _characterMood = MapCharacterMood.idle;

  late List<MapLessonPoint> _lessonPoints;

  @override
  void initState() {
    super.initState();
    _mapController = MapController(language: widget.language);
    _lessonPoints = _mapController.applyLessonPositions(widget.lessons);
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _moveController.addListener(() {
      if (_moveAnimation == null) return;
      final value = _moveAnimation!.value;
      setState(() {
        _characterPosition = MapPosition(value.dx, value.dy);
      });
    });
    _moveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishMovement();
      }
    });
    _loadAllFrames();
    _startFrameTimer();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _loadAllFrames();
    }
    if (oldWidget.lessons != widget.lessons) {
      setState(() {
        _lessonPoints = _mapController.applyLessonPositions(widget.lessons);
      });
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _happyTimer?.cancel();
    _moveController.dispose();
    super.dispose();
  }

  Future<void> _loadAllFrames() async {
    try {
      final results = await Future.wait([
        _mapController.loadFrames('idle'),
        _mapController.loadFrames('walk'),
        _mapController.loadFrames('happy'),
        _mapController.loadFrames('sad'),
      ]);
      if (!mounted) return;
      setState(() {
        _idleFrames = results[0];
        _walkFrames = results[1];
        _happyFrames = results[2];
        _sadFrames = results[3];
        _frameIndex = 0;
      });
    } catch (e) {
      debugPrint('Failed to load map frames: $e');
      if (!mounted) return;
      setState(() {
        _idleFrames = const [];
        _walkFrames = const [];
        _happyFrames = const [];
        _sadFrames = const [];
      });
    }
  }

  void _startFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final frames = _currentFrames();
      if (frames.isEmpty || !mounted) return;
      setState(() {
        _frameIndex = (_frameIndex + 1) % frames.length;
      });
    });
  }

  List<String> _currentFrames() {
    switch (_characterMood) {
      case MapCharacterMood.walking:
        return _walkFrames.isNotEmpty ? _walkFrames : _idleFrames;
      case MapCharacterMood.happy:
        return _happyFrames.isNotEmpty ? _happyFrames : _idleFrames;
      case MapCharacterMood.sad:
        return _sadFrames.isNotEmpty ? _sadFrames : _idleFrames;
      case MapCharacterMood.idle:
      default:
        return _idleFrames;
    }
  }

  String? get _currentFramePath {
    final frames = _currentFrames();
    if (frames.isEmpty) return null;
    return frames[_frameIndex % frames.length];
  }

  void _setMood(MapCharacterMood mood) {
    if (_characterMood == mood) return;
    if (!mounted) return;
    setState(() {
      _characterMood = mood;
      _frameIndex = 0;
    });
    if (mood != MapCharacterMood.happy) {
      _happyTimer?.cancel();
    }
  }

  void _moveToLesson(MapLessonPoint point) {
    if (_isMoving || point.position == null) return;
    final begin = Offset(_characterPosition.x, _characterPosition.y);
    final end = Offset(point.position!.x, point.position!.y);
    _moveAnimation = Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
    );
    _pendingLesson = point;
    _isMoving = true;
    _setMood(MapCharacterMood.walking);
    _moveController.forward(from: 0);
  }

  void _finishMovement() {
    if (!mounted) return;
    setState(() {
      _isMoving = false;
      if (_pendingLesson?.position != null) {
        _characterPosition = _pendingLesson!.position!;
      }
    });
    _setMood(MapCharacterMood.idle);
    final pending = _pendingLesson;
    _pendingLesson = null;
    if (pending != null) {
      _openLesson(pending);
    }
  }

  String _lessonKey(MapLessonPoint point) {
    return '${point.level.title}-${point.lesson.title}';
  }

  Future<void> _openLesson(MapLessonPoint point) async {
    final lessonKey = _lessonKey(point);
    var completedLesson = false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          language: widget.language,
          level: widget.userLevel,
          lesson: point.lesson,
          grammarTopics: point.lesson.grammarTopics,
          vocabTopics: point.lesson.vocabTopics,
          userInterests: widget.userInterests,
          onComplete: (total, done) {
            widget.onLessonCompleted(lessonKey);
            completedLesson = true;
          },
        ),
      ),
    );
    if (!mounted) return;
    if (completedLesson) {
      _showHappy();
    } else {
      _setMood(MapCharacterMood.idle);
    }
  }

  void _showHappy() {
    _setMood(MapCharacterMood.happy);
    _happyTimer?.cancel();
    _happyTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _setMood(MapCharacterMood.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            math.max(constraints.maxHeight, constraints.maxWidth * 1.9);
        final width = constraints.maxWidth;
        final framePath = _currentFramePath;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    kMapBackgroundAsset,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _CourseMapHeader(plan: widget.plan, look: widget.look),
                ),
                for (final point in _lessonPoints)
                  _buildLessonSpot(point, width, height),
                if (framePath != null)
                  Positioned(
                    left: width * _characterPosition.x - 32,
                    top: height * _characterPosition.y - 32,
                    child: MapCharacterWidget(framePath: framePath, size: 64),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLessonSpot(
    MapLessonPoint point,
    double width,
    double height,
  ) {
    final pos = point.position!;
    final left = pos.x * width - 30;
    final top = pos.y * height - 36;
    final lessonKey = _lessonKey(point);
    final completed = widget.completedLessons.contains(lessonKey);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _moveToLesson(point),
        child: SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: LessonFlag(
              completed: completed,
              accent: widget.look.accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseMapHeader extends StatelessWidget {
  final CoursePlan plan;
  final CharacterLook look;

  const _CourseMapHeader({required this.plan, required this.look});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
