import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/utils/constants.dart';

CharacterLook characterLookFor(String language, String gender) {
  final isMale = gender.toLowerCase() == 'male';
  final cleanLang = language.trim().isEmpty ? 'Language' : language.trim();
  final shortCode = cleanLang.length >= 2
      ? cleanLang.substring(0, 2).toUpperCase()
      : cleanLang.toUpperCase();
  switch (language) {
    case 'Korean':
      return CharacterLook(
        primaryColor: const Color(0xFFFFF3E0),
        accentColor: const Color(0xFFFFB74D),
        hairColor: const Color(0xFF4E342E),
        outfitColor: const Color(0xFF90CAF9),
        skinColor: kFairSkin,
        narrowEyes: true,
        longHair: !isMale,
        badgeText: 'KR',
      );
    case 'German':
      return CharacterLook(
        primaryColor: const Color(0xFFE3F2FD),
        accentColor: const Color(0xFF64B5F6),
        hairColor: isMale ? const Color(0xFF3E2723) : const Color(0xFF6D4C41),
        outfitColor: const Color(0xFFFFD54F),
        skinColor: kFairSkin,
        narrowEyes: false,
        longHair: !isMale,
        badgeText: 'DE',
      );
    case 'French':
      return CharacterLook(
        primaryColor: const Color(0xFFFFEBEE),
        accentColor: const Color(0xFFF06292),
        hairColor: const Color(0xFF4E342E),
        outfitColor: const Color(0xFF90A4AE),
        skinColor: kFairSkin,
        narrowEyes: false,
        longHair: true,
        badgeText: 'FR',
      );
    case 'Spanish':
      return CharacterLook(
        primaryColor: const Color(0xFFFFF8E1),
        accentColor: const Color(0xFFFFD54F),
        hairColor: const Color(0xFF5D4037),
        outfitColor: const Color(0xFFD32F2F),
        skinColor: kFairSkin,
        narrowEyes: false,
        longHair: !isMale,
        badgeText: 'ES',
      );
    case 'Italian':
      return CharacterLook(
        primaryColor: const Color(0xFFE8F5E9),
        accentColor: const Color(0xFF66BB6A),
        hairColor: const Color(0xFF3E2723),
        outfitColor: const Color(0xFF1E88E5),
        skinColor: kFairSkin,
        narrowEyes: false,
        longHair: !isMale,
        badgeText: 'IT',
      );
    default:
      return CharacterLook(
        primaryColor: const Color(0xFFEDE7F6),
        accentColor: const Color(0xFF9575CD),
        hairColor: isMale ? const Color(0xFF5D4037) : const Color(0xFF4E342E),
        outfitColor: const Color(0xFF4DB6AC),
        skinColor: kFairSkin,
        narrowEyes: false,
        longHair: !isMale,
        badgeText: shortCode,
      );
  }
}

List<String> buildCharacterFrames(String language) {
  final folder = mapCharacterFolder(language);
  const frameCount = 419;
  return List.generate(frameCount, (i) {
    final n = i + 1;
    final name = n.toString().padLeft(4, '0');
    return 'assets/anim/$folder/$name.webp';
  });
}

String mapCharacterFolder(String language) {
  switch (language) {
    case 'French':
      return 'french';
    case 'German':
      return 'german';
    case 'Italian':
      return 'italian';
    case 'Korean':
      return 'korean';
    case 'Spanish':
      return 'spanish';
    default:
      return 'default';
  }
}
