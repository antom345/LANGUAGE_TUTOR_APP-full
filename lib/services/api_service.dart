import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/utils/constants.dart';

class ApiService {
  static Map<String, String> get _jsonHeaders =>
      const {'Content-Type': 'application/json'};

  static Map<String, dynamic> _decodeJsonMap({
    required String body,
    required String label,
  }) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // log below
    }

    final preview = body.length > 300 ? body.substring(0, 300) : body;
    debugPrint('$label invalid JSON/map. Body preview: $preview');
    throw const FormatException('Invalid server response format');
  }

  static Future<Map<String, dynamic>> _postJson({
    required Uri uri,
    required Map<String, dynamic> payload,
    required String label,
  }) async {
    http.Response resp;
    try {
      resp = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('$label network error: $e');
      rethrow;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      debugPrint(
        '$label failed (${resp.statusCode}): ${resp.body.isEmpty ? '<empty body>' : resp.body}',
      );
      throw HttpException('$label error ${resp.statusCode}: ${resp.body}');
    }

    if (resp.body.isEmpty) {
      throw HttpException('$label empty response');
    }

    return _decodeJsonMap(body: resp.body, label: label);
  }

  static Future<Map<String, dynamic>> sendChat({
    required List<Map<String, String>> messages,
    required String language,
    required String topic,
    required String level,
    required String userGender,
    required int? userAge,
    required String partnerGender,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/chat');
    final payload = {
      'messages': messages,
      'language': language,
      'topic': topic,
      'level': level,
      'user_gender': userGender,
      'user_age': userAge,
      'partner_gender': partnerGender,
    };

    http.Response resp;
    try {
      resp = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('Chat network error: $e');
      rethrow;
    }

    final isOk = resp.statusCode >= 200 && resp.statusCode < 300;
    final preview =
        resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
    if (messages.isEmpty) {
      debugPrint(
          'Chat first response url=$uri status=${resp.statusCode} len=${resp.body.length}; body preview: $preview');
    }

    if (!isOk) {
      debugPrint(
        'Chat failed (${resp.statusCode}): ${resp.body.isEmpty ? '<empty body>' : resp.body}',
      );
      throw HttpException('Chat error ${resp.statusCode}: ${resp.body}');
    }

    if (resp.body.isEmpty) {
      throw HttpException('Chat empty response');
    }

    return _decodeJsonMap(body: resp.body, label: 'Chat');
  }

  static Future<Map<String, dynamic>> translateWord({
    required String word,
    required String language,
    required bool withAudio,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/translate-word');
    final payload = {
      'word': word,
      'language': language,
      'with_audio': withAudio,
    };

    return _postJson(uri: uri, payload: payload, label: 'Translate');
  }

  static Future<String> speechToText({
    required File audioFile,
    required String languageCode,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/stt?language_code=$languageCode');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw HttpException('STT error ${streamed.statusCode}: $body');
    }

    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    return (jsonMap['text'] ?? '') as String;
  }

  static Future<CoursePlan> generateCoursePlan({
    required String language,
    required String levelHint,
    required int? age,
    required String? gender,
    required List<String> interests,
    required String goals,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/generate_course_plan');

    final body = {
      'language': language,
      'level_hint': levelHint,
      'age': age,
      'gender': gender,
      'goals': goals,
      'interests': interests,
    };

    final data = await _postJson(
      uri: uri,
      payload: body,
      label: 'Course plan',
    );
    return CoursePlan.fromJson(data);
  }

  static Future<LessonContentModel> generateLesson({
    required String language,
    required String level,
    required String lessonTitle,
    required List<String> grammarTopics,
    required List<String> vocabTopics,
    required List<String> interests,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/generate_lesson');

    final body = {
      'language': language,
      'level_hint': level,
      'lesson_title': lessonTitle,
      'grammar_topics': grammarTopics,
      'vocab_topics': vocabTopics,
      'interests': interests,
    };

    final data = await _postJson(
      uri: uri,
      payload: body,
      label: 'Lesson',
    );
    return LessonContentModel.fromJson(data);
  }

  static Future<Uint8List> synthesizeTts({
    required String text,
    required String language,
    String? voice,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl/tts');
    http.Response resp;
    try {
      resp = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          'text': text,
          'language': language,
          'voice': voice,
        }),
      );
    } catch (e) {
      debugPrint('TTS network error: $e');
      rethrow;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      debugPrint(
        'TTS failed (${resp.statusCode}): ${resp.body.isEmpty ? '<empty body>' : resp.body}',
      );
      throw HttpException('TTS error ${resp.statusCode}: ${resp.body}');
    }

    return resp.bodyBytes;
  }
}
