import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String? label;

  const LoadingIndicator({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label!),
        ],
      ],
    );
  }
}
