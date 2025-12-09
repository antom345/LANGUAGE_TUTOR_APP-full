import 'dart:async';

import 'package:flutter/material.dart';

class LoopingPngAnimation extends StatefulWidget {
  final List<String> frames; // список путей к кадрам
  final Duration frameDuration; // длительность одного кадра
  final BoxFit fit;

  const LoopingPngAnimation({
    super.key,
    required this.frames,
    this.frameDuration = const Duration(milliseconds: 80),
    this.fit = BoxFit.contain,
  });

  @override
  State<LoopingPngAnimation> createState() => _LoopingPngAnimationState();
}

class _LoopingPngAnimationState extends State<LoopingPngAnimation> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();

    if (widget.frames.isEmpty) return;

    _timer = Timer.periodic(widget.frameDuration, (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % widget.frames.length;
      });
    });
  }

  @override
  void didUpdateWidget(covariant LoopingPngAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      _index = 0;
      _timer?.cancel();

      if (widget.frames.isNotEmpty) {
        _timer = Timer.periodic(widget.frameDuration, (_) {
          if (!mounted) return;
          setState(() {
            _index = (_index + 1) % widget.frames.length;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Image.asset(
      widget.frames[_index],
      fit: widget.fit,
      gaplessPlayback: true, // важно: без мерцания при смене кадров
    );
  }
}
