import 'package:flutter/material.dart';

class MapCharacterWidget extends StatelessWidget {
  final String? framePath;
  final double size;

  const MapCharacterWidget({
    super.key,
    required this.framePath,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    if (framePath == null) {
      return SizedBox(width: size, height: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        framePath!,
        gaplessPlayback: true,
      ),
    );
  }
}
