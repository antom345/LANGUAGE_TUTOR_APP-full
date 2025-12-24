import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:language_tutor_app/models/message.dart';
import 'package:language_tutor_app/models/situation.dart';
import 'package:language_tutor_app/services/api_service.dart';

class TranslationResult {
  final String translation;
  final String example;
  final String exampleTranslation;
  final String? audioUrl;

  TranslationResult({
    required this.translation,
    required this.example,
    required this.exampleTranslation,
    this.audioUrl,
  });
}

class ChatController {
  final String language;
  final String level;
  final String topic;
  final String userGender;
  final int? userAge;
  final String partnerGender;
  final String? ttsVoice;
  final double? ttsSpeed;
  final int? ttsSampleRate;

  ChatController({
    required this.language,
    required this.level,
    required this.topic,
    required this.userGender,
    required this.userAge,
    required this.partnerGender,
    this.ttsVoice,
    this.ttsSpeed,
    this.ttsSampleRate,
  });

  Future<ChatResponseModel> sendChat(
    List<ChatMessage> messages, {
    required bool initial,
    SituationContext? situation,
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
      situation: situation,
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
      audioUrl: data['audio_url'] as String?,
    );
  }

  Future<String?> fetchWordAudioUrl(String word) async {
    final data = await ApiService.translateWord(
      word: word,
      language: language,
      withAudio: true,
    );
    final audioUrl = data['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) {
      debugPrint('Translate audio_url is empty');
      return null;
    }
    return audioUrl;
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

  Future<String?> fetchMessageTtsUrl(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;

    final voiceToSend = () {
      final v = ttsVoice?.trim() ?? '';
      if (v.isEmpty || v.toLowerCase() == 'default') return 'af_heart';
      return v;
    }();

    try {
      final audioUrl = await ApiService.synthesizeTts(
        text: normalized,
        language: language,
        voice: voiceToSend,
        speed: ttsSpeed,
        sampleRate: ttsSampleRate,
      );
      return audioUrl;
    } catch (e, st) {
      debugPrint('Message TTS error: $e\n$st');
      return null;
    }
  }
}

class ChatResponseModel {
  final String reply;
  final String? correctionsText;
  final String? partnerName;
  final String? audioUrl;

  ChatResponseModel({
    required this.reply,
    this.correctionsText,
    this.partnerName,
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
    final inline = _extractInlineCorrections(reply);
    if (inline.reply.isNotEmpty) {
      reply = inline.reply;
    }
    if (corrections == null && inline.corrections.isNotEmpty) {
      corrections = inline.corrections;
    }

    return ChatResponseModel(
      reply: reply,
      correctionsText: corrections,
      partnerName: (json['partner_name'] as String?)?.trim(),
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

class _InlineExtraction {
  final String reply;
  final String corrections;
  const _InlineExtraction({required this.reply, required this.corrections});
}

_InlineExtraction _extractInlineCorrections(String raw) {
  if (raw.isEmpty) return const _InlineExtraction(reply: '', corrections: '');

  // Случай 1: JSON с corrections_text внутри.
  final parsed = _tryParseJson(raw);
  if (parsed != null) {
    final replyVal = (parsed['reply'] ?? '').toString().trim();
    final corrVal = (parsed['corrections_text'] ?? '').toString().trim();
    if (replyVal.isNotEmpty || corrVal.isNotEmpty) {
      return _InlineExtraction(reply: replyVal, corrections: corrVal);
    }
  }

  // Случай 2: текст + {..json..}
  final braceIdx = raw.indexOf('{');
  if (braceIdx != -1) {
    final before = raw.substring(0, braceIdx).trim();
    final parsedTail = _tryParseJson(raw.substring(braceIdx));
    final corrVal = parsedTail?['corrections_text']?.toString().trim() ?? '';
    return _InlineExtraction(
      reply: before.isNotEmpty ? before : raw.trim(),
      corrections: corrVal,
    );
  }

  // Случай 3: текстовые подсказки reply: / corrections_text:
  if (raw.contains('reply:') || raw.contains('corrections_text:')) {
    final parsedCombined = ChatResponseModel._extractCombined(raw);
    return _InlineExtraction(
      reply: parsedCombined.reply,
      corrections: parsedCombined.corrections,
    );
  }

  return _InlineExtraction(reply: raw.trim(), corrections: '');
}

Map<String, dynamic>? _tryParseJson(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
