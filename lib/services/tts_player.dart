import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Simple singleton TTS player that plays audio bytes only (no temp files).
class TtsPlayer {
  TtsPlayer._();
  static final TtsPlayer _instance = TtsPlayer._();
  factory TtsPlayer() => _instance;

  final AudioPlayer _player = AudioPlayer();
  bool _busy = false;

  Future<bool> playBytes(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) {
      debugPrint('TTS: empty bytes, skip');
      return false;
    }

    if (_busy) {
      // Stop previous playback before starting new one to avoid duplicate
      // method channel messages.
      try {
        await _player.stop();
      } catch (_) {}
    }

    _busy = true;
    try {
      await _player.stop();
      await _player.play(BytesSource(bytes));
      return true;
    } catch (e, st) {
      debugPrint('TTS play error: $e\n$st');
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();
  }
}
