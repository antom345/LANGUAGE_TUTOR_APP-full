import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:language_tutor_app/models/message.dart';
import 'package:language_tutor_app/services/api_service.dart';

class TranslationResult {
  final String translation;
  final String example;
  final String exampleTranslation;
  final String? audioBase64;

  TranslationResult({
    required this.translation,
    required this.example,
    required this.exampleTranslation,
    this.audioBase64,
  });
}

class ChatController {
  final String language;
  final String level;
  final String topic;
  final String userGender;
  final int? userAge;
  final String partnerGender;

  ChatController({
    required this.language,
    required this.level,
    required this.topic,
    required this.userGender,
    required this.userAge,
    required this.partnerGender,
  });

  Future<ChatResponseModel> sendChat(
    List<ChatMessage> messages, {
    required bool initial,
  }) async {
    final messagesPayload =
        initial ? <Map<String, String>>[] : _buildMessagesPayload(messages);

    final data = await ApiService.sendChat(
      messages: messagesPayload,
      language: language,
      topic: topic,
      level: level,
      userGender: userGender,
      userAge: userAge,
      partnerGender: partnerGender,
    );
    return ChatResponseModel.fromJson(data);
  }

  Future<TranslationResult> translateWord(String word) async {
    final data = await ApiService.translateWord(
      word: word,
      language: language,
      withAudio: true,
    );
    return TranslationResult(
      translation: data['translation'] as String? ?? 'нет данных',
      example: data['example'] as String? ?? 'нет примера',
      exampleTranslation:
          data['example_translation'] as String? ?? 'нет перевода примера',
      audioBase64: data['audio_base64'] as String?,
    );
  }

  Future<Uint8List?> fetchWordAudioBytes(String word) async {
    final data = await ApiService.translateWord(
      word: word,
      language: language,
      withAudio: true,
    );
    final audio = data['audio_base64'] as String?;
    return _decodeAudio(audio);
  }

  Future<String> speechToText(File file) async {
    final langCode = _languageCodeFromName(language);
    return ApiService.speechToText(
      audioFile: file,
      languageCode: langCode,
    );
  }

  List<Map<String, String>> _buildMessagesPayload(List<ChatMessage> messages) {
    final items = messages
        .where((m) => !m.isCorrections)
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();

    if (items.length <= 5) return items;
    return items.sublist(items.length - 5);
  }

  String _languageCodeFromName(String language) {
    switch (language) {
      case 'English':
        return 'en';
      case 'German':
        return 'de';
      case 'French':
        return 'fr';
      case 'Spanish':
        return 'es';
      case 'Italian':
        return 'it';
      case 'Korean':
        return 'ko';
      case 'Russian':
        return 'ru';
      default:
        return 'en';
    }
  }

  Future<Uint8List?> fetchMessageTtsBytes(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;

    try {
      return await ApiService.synthesizeTts(
        text: normalized,
        language: language,
      );
    } catch (e, st) {
      debugPrint('Message TTS error: $e\n$st');
      return null;
    }
  }

  Uint8List? _decodeAudio(String? audio) {
    if (audio == null || audio.isEmpty) return null;
    try {
      return base64Decode(audio);
    } catch (e, st) {
      debugPrint('TTS decode error: $e\n$st');
      return null;
    }
  }
}

class ChatResponseModel {
  final String reply;
  final String? correctionsText;
  final String? partnerName;
  final String? audioBase64;
  final String? audioUrl;

  ChatResponseModel({
    required this.reply,
    this.correctionsText,
    this.partnerName,
    this.audioBase64,
    this.audioUrl,
  });

  factory ChatResponseModel.fromJson(Map<String, dynamic> json) {
    String? reply;
    if (json['reply'] is String && (json['reply'] as String).trim().isNotEmpty) {
      reply = (json['reply'] as String).trim();
    } else if (json['message'] is String &&
        (json['message'] as String).trim().isNotEmpty) {
      reply = (json['message'] as String).trim();
    } else if (json['text'] is String &&
        (json['text'] as String).trim().isNotEmpty) {
      reply = (json['text'] as String).trim();
    }

    if (reply == null || reply.isEmpty) {
      debugPrint('Chat response missing reply. Raw json: $json');
      throw const FormatException('Invalid server response format');
    }

    String? corrections =
        (json['corrections_text'] as String?)?.trim().isNotEmpty == true
            ? (json['corrections_text'] as String).trim()
            : null;

    // Если reply содержит слепленные reply/corrections_text — попытаемся распарсить.
    if (corrections == null &&
        (reply.contains('reply:') || reply.contains('corrections_text:'))) {
      final parsed = _extractCombined(reply);
      if (parsed.reply.isNotEmpty) {
        reply = parsed.reply;
      }
      if (parsed.corrections.isNotEmpty) {
        corrections = parsed.corrections;
      }
    }

    return ChatResponseModel(
      reply: reply,
      correctionsText: corrections,
      partnerName: (json['partner_name'] as String?)?.trim(),
      audioBase64: json['audio_base64'] as String?,
      audioUrl: json['audio_url'] as String?,
    );
  }

  static _ParsedCombined _extractCombined(String raw) {
    final lower = raw.toLowerCase();
    final replyIdx = lower.indexOf('reply:');
    final corrIdx = lower.indexOf('corrections_text:');

    String reply = raw.trim();
    String corrections = '';

    String trimVal(String val) => val.trim().replaceFirst(RegExp(r'^[\s.:]+'), '').trim();

    if (replyIdx != -1 && corrIdx != -1) {
      if (replyIdx < corrIdx) {
        reply = trimVal(raw.substring(replyIdx + 'reply:'.length, corrIdx));
        corrections =
            trimVal(raw.substring(corrIdx + 'corrections_text:'.length));
      } else {
        corrections =
            trimVal(raw.substring(corrIdx + 'corrections_text:'.length, replyIdx));
        reply = trimVal(raw.substring(replyIdx + 'reply:'.length));
      }
    } else if (replyIdx != -1) {
      reply = trimVal(raw.substring(replyIdx + 'reply:'.length));
    } else if (corrIdx != -1) {
      reply = '';
      corrections =
          trimVal(raw.substring(corrIdx + 'corrections_text:'.length));
    }

    return _ParsedCombined(reply: reply, corrections: corrections);
  }
}

class _ParsedCombined {
  final String reply;
  final String corrections;
  _ParsedCombined({required this.reply, required this.corrections});
}
