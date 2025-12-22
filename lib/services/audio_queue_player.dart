import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioQueuePlayer {
  final AudioPlayer _player = AudioPlayer();
  final Queue<String> _queue = Queue<String>();
  bool _isPlaying = false;
  StreamSubscription<void>? _completeSub;

  Future<void> init() async {
    _completeSub ??= _player.onPlayerComplete.listen((_) {
      unawaited(_playNext());
    });
  }

  Future<void> dispose() async {
    await _completeSub?.cancel();
    _completeSub = null;
    await stopAndClear();
    await _player.dispose();
  }

  Future<void> enqueue(String url) async {
    if (url.isEmpty) return;
    _queue.add(url);
    if (!_isPlaying) {
      await _playNext();
    }
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) {
      _isPlaying = false;
      return;
    }

    final url = _queue.removeFirst();
    _isPlaying = true;
    try {
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('AudioQueue play error: $e');
      _isPlaying = false;
      await _playNext();
    }
  }

  Future<void> stopAndClear() async {
    await _player.stop();
    _queue.clear();
    _isPlaying = false;
  }
}
