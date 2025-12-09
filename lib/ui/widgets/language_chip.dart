import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LanguageChip extends StatelessWidget {
  final String code;
  final double size;

  const LanguageChip({
    super.key,
    required this.code,
    this.size = 48,
  });

  Color _colorForCode(String code) {
    switch (code.toUpperCase()) {
      case 'EN':
        return AppColors.colorAccentBlue;
      case 'DE':
        return const Color(0xFF00BFA6);
      case 'FR':
        return AppColors.colorAccentPink;
      case 'ES':
        return const Color(0xFFFFB300);
      case 'IT':
        return const Color(0xFF29B6F6);
      case 'KR':
        return AppColors.colorAccentGreen;
      default:
        return AppColors.colorPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCode(code);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.9),
            color.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        code.toUpperCase(),
        style: const TextStyle(
          color: AppColors.languageChipText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
