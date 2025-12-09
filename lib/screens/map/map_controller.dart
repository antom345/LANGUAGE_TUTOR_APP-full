import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/services/character_service.dart';

class MapPosition {
  final double x; // 0..1
  final double y; // 0..1
  const MapPosition(this.x, this.y);
}

class MapLessonPoint {
  final CourseLevelPlan level;
  final LessonPlan lesson;
  final MapPosition? position;

  const MapLessonPoint({
    required this.level,
    required this.lesson,
    this.position,
  });

  MapLessonPoint copyWithPosition(MapPosition pos) {
    return MapLessonPoint(
      level: level,
      lesson: lesson,
      position: pos,
    );
  }
}

enum MapCharacterMood { idle, walking, happy, sad }

const List<MapPosition> lessonPositions = <MapPosition>[
  MapPosition(0.50, 0.88),
  MapPosition(0.55, 0.70),
  MapPosition(0.52, 0.54),
  MapPosition(0.50, 0.38),
  MapPosition(0.48, 0.20),
];

const MapPosition initialCharacterPosition = MapPosition(0.5, 0.92);

class MapController {
  final String language;

  MapController({required this.language});

  String get folder => mapCharacterFolder(language);

  Future<List<String>> loadFrames(String state) async {
    final prefix = 'assets/anim_map/$folder/$state/';
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final frames = manifest
          .listAssets()
          .where((k) => k.startsWith(prefix) && k.endsWith('.webp'))
          .toList()
        ..sort();
      if (frames.isNotEmpty) return frames;
    } catch (e) {
      debugPrint('MAP manifest load failed ($state): $e');
    }

    final fallbackCount = state == 'walk' ? 31 : 56;
    return List.generate(
      fallbackCount,
      (i) => '$prefix${(i + 1).toString().padLeft(4, '0')}.webp',
    );
  }

  List<MapLessonPoint> applyLessonPositions(List<MapLessonPoint> source) {
    final result = <MapLessonPoint>[];
    for (var i = 0; i < source.length && i < lessonPositions.length; i++) {
      result.add(source[i].copyWithPosition(lessonPositions[i]));
    }
    return result;
  }
}
