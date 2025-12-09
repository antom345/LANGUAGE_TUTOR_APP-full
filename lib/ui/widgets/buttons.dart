import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      textStyle: Theme.of(context).textTheme.labelLarge,
      backgroundColor: AppColors.colorPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
      ),
    );

    final button = icon != null
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: icon!,
            label: Text(label),
            style: style,
          )
        : FilledButton(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.colorPrimary,
        side: const BorderSide(color: AppColors.colorPrimary, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        ),
        textStyle: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.colorPrimary),
      ),
      child: Text(label),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
