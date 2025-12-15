import 'package:audioplayers/audioplayers.dart';

/// Simple singleton TTS player that streams audio by URL (no temp files/base64).
class TtsPlayer {
  TtsPlayer._();
  static final TtsPlayer _instance = TtsPlayer._();
  factory TtsPlayer() => _instance;

  final AudioPlayer _player = AudioPlayer();

  Future<void> playUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e) {
      // ignore: avoid_print
      print('[TTS] playUrl failed: $e');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
