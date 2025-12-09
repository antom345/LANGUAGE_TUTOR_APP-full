import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'gradient_card.dart';
import 'language_chip.dart';

class LanguageCharacterCard extends StatelessWidget {
  final String name;
  final String language;
  final String code;
  final String hint;
  final Color accent;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? leading;

  const LanguageCharacterCard({
    super.key,
    required this.name,
    required this.language,
    required this.code,
    required this.hint,
    required this.accent,
    required this.onTap,
    this.trailing,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      colors: [
        accent.withOpacity(0.12),
        Colors.white.withOpacity(0.95),
      ],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        child: Row(
          children: [
            leading ??
                LanguageChip(
                  code: code,
                  size: 54,
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name ($language)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: accent,
                ),
          ],
        ),
      ),
    );
  }
}
