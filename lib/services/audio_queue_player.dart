import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioQueuePlayer {
  final AudioPlayer _player = AudioPlayer();
  final Queue<_QueueItem> _queue = Queue<_QueueItem>();
  bool _isPlaying = false;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;
  _QueueItem? _currentItem;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _completeSub ??= _player.onPlayerComplete.listen((_) {
      _currentItem = null;
      _isPlaying = false;
      unawaited(_playNext());
    });

    _stateSub ??= _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing &&
          _currentItem != null &&
          !_currentItem!.started) {
        _currentItem!.started = true;
        _currentItem!.onStart?.call();
      }
    });
  }

  Future<void> dispose() async {
    _initialized = false;
    await _stateSub?.cancel();
    _stateSub = null;
    await _completeSub?.cancel();
    _completeSub = null;
    await stopAndClear();
    await _player.dispose();
  }

  Future<void> enqueue(String url, {VoidCallback? onStart}) async {
    if (url.isEmpty) return;
    _queue.add(_QueueItem(url, onStart: onStart));
    if (!_isPlaying) {
      await _playNext();
    }
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) {
      _isPlaying = false;
      _currentItem = null;
      return;
    }

    final item = _queue.removeFirst();
    _isPlaying = true;
    _currentItem = item;
    try {
      await _player.stop();
      await _player.play(UrlSource(item.url));
    } catch (e) {
      debugPrint('AudioQueue play error: $e');
      _isPlaying = false;
      _currentItem = null;
      await _playNext();
    }
  }

  Future<void> stopAndClear() async {
    await _player.stop();
    _queue.clear();
    _isPlaying = false;
    _currentItem = null;
  }
}

class _QueueItem {
  final String url;
  final VoidCallback? onStart;
  bool started = false;

  _QueueItem(this.url, {this.onStart});
}
