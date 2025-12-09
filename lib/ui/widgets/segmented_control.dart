import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SegmentedControlItem<T> {
  final String label;
  final T value;

  SegmentedControlItem({required this.label, required this.value});
}

class SegmentedControl<T> extends StatelessWidget {
  final List<SegmentedControlItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  const SegmentedControl({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppRadius.radiusChip),
        border: Border.all(color: AppColors.colorDivider),
      ),
      child: Row(
        children: [
          for (final item in items) ...[
            Expanded(
              child: _Segment<T>(
                label: item.label,
                value: item.value,
                groupValue: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  final String label;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  const _Segment({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value == groupValue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: isActive ? AppColors.colorPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.radiusChip),
        border: Border.all(
          color: isActive ? AppColors.colorPrimary : AppColors.colorDivider,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.colorPrimary.withOpacity(0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(AppRadius.radiusChip),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          isActive ? Colors.white : AppColors.colorTextPrimary,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
