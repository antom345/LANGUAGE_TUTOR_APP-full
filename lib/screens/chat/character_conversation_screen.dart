import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/screens/chat/chat_screen.dart';
import 'package:language_tutor_app/screens/home/learning_language_select_screen.dart';
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
  bool _isChatSheetOpen = false;
  bool _pendingExternalRecord = false;
  final ChatViewController _chatViewController = ChatViewController();
  final ScrollController _chatScrollController = ScrollController();

  CharacterLook get _characterLook =>
      characterLookFor(widget.partnerLanguage, widget.partnerGender);

  @override
  void initState() {
    super.initState();
    _characterFrames = buildCharacterFrames(widget.partnerLanguage);
    _chatViewController.onAttached = () {
      if (_pendingExternalRecord) {
        _pendingExternalRecord = false;
        _chatViewController.startRecording();
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final partnerName = partnerNameForLanguage(widget.partnerLanguage);

    return AppScaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const LearningLanguageSelectScreen(),
                            ),
                            (route) => false,
                          );
                        },
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
                        onPressed: () =>
                            setState(() => _isChatSheetOpen = true),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: size.height * 0.4,
                          child:
                              Center(child: _buildCharacterStage(_characterLook)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нажмите и удерживайте кнопку внизу, чтобы говорить',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: _VoiceInputBar(
                    isPressing: _isPressing,
                    onPressChanged: (value) => setState(() => _isPressing = value),
                    accent: _characterLook.accentColor,
                    onLongPressStart: _handleMicPressStart,
                    onLongPressEnd: _handleMicPressEnd,
                    onLongPressCancel: _handleMicPressCancel,
                  ),
                ),
              ],
            ),
          ),
          _buildPersistentChatSheet(),
        ],
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

  Widget _buildPersistentChatSheet() {
    return IgnorePointer(
      ignoring: !_isChatSheetOpen,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        offset: _isChatSheetOpen ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isChatSheetOpen ? 1 : 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
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
                  height: MediaQuery.of(context).size.height * 0.65,
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
                          scrollController: _chatScrollController,
                          controller: _chatViewController,
                          onCorrections: _onCorrectionsFromChat,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isChatSheetOpen = false;
                            _pendingExternalRecord = false;
                          });
                        },
                        child: const Text('Закрыть'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleMicPressStart() {
    if (_chatViewController.isReady) {
      _chatViewController.startRecording();
    } else {
      _pendingExternalRecord = true;
    }
  }

  void _handleMicPressEnd() {
    _pendingExternalRecord = false;
    if (_chatViewController.isReady) {
      _chatViewController.stopRecordingAndSend();
    }
  }

  void _handleMicPressCancel() {
    _pendingExternalRecord = false;
    if (_chatViewController.isReady) {
      _chatViewController.cancelRecording();
    }
  }

  void _onCorrectionsFromChat(String text) {
    if (_isChatSheetOpen) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        duration: const Duration(seconds: 3),
        content: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chatViewController.onAttached = null;
    _chatScrollController.dispose();
    super.dispose();
  }
}

class _VoiceInputBar extends StatelessWidget {
  final bool isPressing;
  final ValueChanged<bool> onPressChanged;
  final Color accent;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;

  const _VoiceInputBar({
    required this.isPressing,
    required this.onPressChanged,
    required this.accent,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(
          child: GestureDetector(
            onLongPressStart: (_) {
              onPressChanged(true);
              onLongPressStart();
            },
            onLongPressEnd: (_) {
              onPressChanged(false);
              onLongPressEnd();
            },
            onLongPressCancel: () {
              onPressChanged(false);
              onLongPressCancel();
            },
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
