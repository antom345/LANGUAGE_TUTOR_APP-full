import 'package:flutter/material.dart';

class LessonFlag extends StatelessWidget {
  final bool completed;
  final Color accent;

  const LessonFlag({
    super.key,
    required this.completed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: completed ? 52 : 48,
      height: completed ? 52 : 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: completed ? Colors.greenAccent : accent.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: completed
          ? const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: 6, right: 6),
                child: Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Colors.greenAccent,
                ),
              ),
            )
          : null,
    );
  }
}
