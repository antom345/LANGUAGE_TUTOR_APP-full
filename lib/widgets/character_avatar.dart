import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/utils/helpers.dart';

class CharacterAvatar extends StatelessWidget {
  final CharacterLook look;
  final double size;

  const CharacterAvatar({super.key, required this.look, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [
        lighten(look.primaryColor, 0.12),
        lighten(look.accentColor, 0.08),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: look.accentColor.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            look.badgeText,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: darken(look.accentColor, 0.28),
              fontSize: size * 0.32,
            ),
          ),
          Positioned(
            bottom: size * 0.16,
            right: size * 0.2,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.person,
                size: size * 0.16,
                color: darken(look.accentColor, 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
