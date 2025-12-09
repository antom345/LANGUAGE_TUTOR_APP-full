import 'package:flutter/material.dart';
class CharacterLook {
  final Color primaryColor; // background tint
  final Color accentColor;
  final Color hairColor;
  final Color outfitColor;
  final Color skinColor;
  final bool narrowEyes;
  final bool longHair;
  final String badgeText;

  const CharacterLook({
    required this.primaryColor,
    required this.accentColor,
    required this.hairColor,
    required this.outfitColor,
    required this.skinColor,
    required this.narrowEyes,
    required this.longHair,
    required this.badgeText,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CharacterLook &&
        other.primaryColor == primaryColor &&
        other.accentColor == accentColor &&
        other.hairColor == hairColor &&
        other.outfitColor == outfitColor &&
        other.skinColor == skinColor &&
        other.narrowEyes == narrowEyes &&
        other.longHair == longHair &&
        other.badgeText == badgeText;
  }

  @override
  int get hashCode => Object.hash(
        primaryColor,
        accentColor,
        hairColor,
        outfitColor,
        skinColor,
        narrowEyes,
        longHair,
        badgeText,
      );
}
