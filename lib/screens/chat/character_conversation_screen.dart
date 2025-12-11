import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/screens/chat/chat_screen.dart';
import 'package:language_tutor_app/services/character_service.dart';
import 'package:language_tutor_app/ui/widgets/app_scaffold.dart';
import 'package:language_tutor_app/widgets/looping_png_animation.dart';

class CharacterConversationScreen extends StatefulWidget {
  final String learningLanguage;
  final String partnerLanguage;
  final String level;
  final String topic;
  final String userGender;
  final int? userAge;
  final String partnerGender;

  const CharacterConversationScreen({
    super.key,
    required this.learningLanguage,
    required this.partnerLanguage,
    required this.level,
    required this.topic,
    required this.userGender,
    required this.userAge,
    required this.partnerGender,
  });

  @override
  State<CharacterConversationScreen> createState() =>
      _CharacterConversationScreenState();
}

class _CharacterConversationScreenState
    extends State<CharacterConversationScreen> {
  late final List<String> _characterFrames;
  bool _isPressing = false;

  CharacterLook get _characterLook =>
      characterLookFor(widget.partnerLanguage, widget.partnerGender);

  @override
  void initState() {
    super.initState();
    _characterFrames = buildCharacterFrames(widget.partnerLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final partnerName = partnerNameForLanguage(widget.partnerLanguage);

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          partnerName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${widget.learningLanguage} · level ${widget.level}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'История чата',
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: _openChatSheet,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: size.height * 0.55,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(child: _buildCharacterStage(_characterLook)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Нажмите и удерживайте кнопку внизу, чтобы говорить',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade700),
              ),
            ),
            _VoiceInputBar(
              isPressing: _isPressing,
              onPressChanged: (value) => setState(() => _isPressing = value),
              accent: _characterLook.accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterStage(CharacterLook look) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final figureHeight = constraints.maxHeight * 0.9;
        final shadowWidth = figureHeight * 0.62;

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: shadowWidth * 1.2,
              height: figureHeight * 0.2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(160),
                gradient: RadialGradient(
                  colors: [
                    look.primaryColor.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  radius: 0.9,
                ),
              ),
            ),
            Container(
              width: shadowWidth,
              height: figureHeight * 0.12,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(120),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 22,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: figureHeight * 0.98,
                maxWidth: constraints.maxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: figureHeight * 0.02),
                child: LoopingPngAnimation(
                  frames: _characterFrames,
                  frameDuration: const Duration(milliseconds: 80),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ChatView(
                      learningLanguage: widget.learningLanguage,
                      partnerLanguage: widget.partnerLanguage,
                      level: widget.level,
                      topic: widget.topic,
                      userGender: widget.userGender,
                      userAge: widget.userAge,
                      partnerGender: widget.partnerGender,
                      scrollController: scrollController,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _VoiceInputBar extends StatelessWidget {
  final bool isPressing;
  final ValueChanged<bool> onPressChanged;
  final Color accent;

  const _VoiceInputBar({
    required this.isPressing,
    required this.onPressChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(
          child: GestureDetector(
            onLongPressStart: (_) => onPressChanged(true),
            onLongPressEnd: (_) => onPressChanged(false),
            onLongPressCancel: () => onPressChanged(false),
            child: AnimatedScale(
              scale: isPressing ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: isPressing ? accent : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(isPressing ? 0.35 : 0.18),
                      blurRadius: isPressing ? 22 : 14,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 36,
                  color: isPressing ? Colors.white : accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
