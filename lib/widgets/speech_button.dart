import 'package:flutter/material.dart';

class SpeechButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onCancel;

  const SpeechButton({
    super.key,
    required this.isRecording,
    this.onTapDown,
    this.onTapUp,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onTapDown == null ? null : (_) => onTapDown!(),
      onTapUp: onTapUp == null ? null : (_) => onTapUp!(),
      onTapCancel: onCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isRecording ? Colors.red.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRecording
                ? Colors.redAccent
                : Theme.of(context).colorScheme.primary.withOpacity(0.4),
          ),
        ),
        child: Icon(
          isRecording ? Icons.mic : Icons.mic_none,
          color: isRecording
              ? Colors.red
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
