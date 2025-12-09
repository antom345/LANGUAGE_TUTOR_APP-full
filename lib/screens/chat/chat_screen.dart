import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/models/message.dart';
import 'package:language_tutor_app/screens/chat/chat_controller.dart';
import 'package:language_tutor_app/screens/map/lesson_screen.dart';
import 'package:language_tutor_app/screens/map/map_controller.dart';
import 'package:language_tutor_app/screens/map/map_screen.dart';
import 'package:language_tutor_app/services/api_service.dart';
import 'package:language_tutor_app/services/character_service.dart';
import 'package:language_tutor_app/services/tts_player.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:language_tutor_app/ui/widgets/app_scaffold.dart';
import 'package:language_tutor_app/ui/widgets/buttons.dart';
import 'package:language_tutor_app/ui/widgets/empty_state.dart';
import 'package:language_tutor_app/ui/widgets/gradient_card.dart';
import 'package:language_tutor_app/ui/widgets/segmented_control.dart';
import 'package:language_tutor_app/utils/helpers.dart';
import 'package:language_tutor_app/widgets/character_avatar.dart';
import 'package:language_tutor_app/widgets/looping_png_animation.dart';

class ChatScreenArgs {
  final String language;
  final String level;
  final String topic;
  final String userGender;
  final int? userAge;
  final String partnerGender;

  ChatScreenArgs({
    required this.language,
    required this.level,
    required this.topic,
    required this.userGender,
    required this.userAge,
    required this.partnerGender,
  });
}

class ChatScreen extends StatefulWidget {
  final String language;
  final String level;
  final String topic;
  final String userGender;
  final int? userAge;
  final String partnerGender;

  const ChatScreen({
    super.key,
    required this.language,
    required this.level,
    required this.topic,
    required this.userGender,
    required this.userAge,
    required this.partnerGender,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isSending = false;
  final List<SavedWord> _savedWords = [];
  int _tabIndex = 0;

  final TtsPlayer _ttsPlayer = TtsPlayer();
  late final List<String> _characterFrames;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimeoutTimer;
  DateTime? _recordingStartedAt;
  String? _currentRecordingPath;
  static const Duration _maxRecordingDuration = Duration(seconds: 20);
  static const Duration _minRecordingDuration = Duration(milliseconds: 700);
  static const int _minRecordingBytes = 2000;

  late final ChatController _chatController;

  int _userWordCount = 0;
  int _currentLevel = 1;
  final List<int> _levelTargets = [50, 150, 300, 500, 1000];
  final Set<String> _completedLessons = {};
  final List<String> _userInterests = [];
  bool _interestsAsked = false;
  static const List<String> _interestOptions = [
    'Путешествия',
    'Работа / Карьера',
    'Учёба',
    'Фильмы и сериалы',
    'Музыка',
    'Спорт',
    'Технологии и IT',
    'Еда и кулинария',
    'Отношения и общение',
    'Игры',
  ];

  CoursePlan? _coursePlan;
  bool _isLoadingCourse = false;
  String? _courseError;

  CharacterLook get _characterLook =>
      characterLookFor(widget.language, widget.partnerGender);

  @override
  void initState() {
    super.initState();
    _characterFrames = buildCharacterFrames(widget.language);
    _chatController = ChatController(
      language: widget.language,
      level: widget.level,
      topic: widget.topic,
      userGender: widget.userGender,
      userAge: widget.userAge,
      partnerGender: widget.partnerGender,
    );
    _startConversation();
  }

  Future<bool> _playTtsBytes(Uint8List bytes) {
    return _ttsPlayer.playBytes(bytes);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _ttsPlayer.dispose();
    _audioRecorder.dispose();
    _recordingTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _startConversation() async {
    await _sendToBackend(initial: true);
  }

  Future<void> _sendUserMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _userWordCount += text.split(RegExp(r'\s+')).length;
      _inputController.clear();
    });

    _updateProgress();
    await _sendToBackend(initial: false);
  }

  Future<void> _sendToBackend({required bool initial}) async {
    setState(() {
      _isSending = true;
    });

    try {
      final data = await _chatController.sendChat(_messages, initial: initial);
      final reply = data['reply'] as String? ?? '';
      final correctionsText = data['corrections_text'] as String? ?? '';

      setState(() {
        if (reply.trim().isNotEmpty) {
          _messages.add(ChatMessage(role: 'assistant', text: reply.trim()));
        }
        if (correctionsText.trim().isNotEmpty) {
          _messages.add(
            ChatMessage(
              role: 'assistant',
              text: correctionsText.trim(),
              isCorrections: true,
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(role: 'assistant', text: 'System: connection error: $e'),
        );
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _ensureInterestsCollected() async {
    if (_userInterests.isNotEmpty || _interestsAsked) return;

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        final chosen = <String>{..._userInterests};
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text('Что вам интересно?'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final interest in _interestOptions)
                      FilterChip(
                        label: Text(interest),
                        selected: chosen.contains(interest),
                        onSelected: (val) {
                          setStateDialog(() {
                            if (val) {
                              chosen.add(interest);
                            } else {
                              chosen.remove(interest);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(<String>[]),
                  child: const Text('Пропустить'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(chosen.toList()),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    setState(() {
      _interestsAsked = true;
      if (selected != null) {
        _userInterests
          ..clear()
          ..addAll(selected);
      }
    });
  }

  Future<void> _loadCoursePlan({String? overrideLevelHint}) async {
    if (_isLoadingCourse || _coursePlan != null) return;

    setState(() {
      _isLoadingCourse = true;
      _courseError = null;
    });

    try {
      await _ensureInterestsCollected();

      final gender =
          widget.userGender == 'unspecified' ? null : widget.userGender;

      final plan = await ApiService.generateCoursePlan(
        language: widget.language,
        levelHint: overrideLevelHint ?? widget.level,
        age: widget.userAge,
        gender: gender,
        interests: _userInterests,
        goals:
            'Improve ${widget.language} through conversation and vocabulary.',
      );

      setState(() {
        _coursePlan = plan;
      });
    } catch (e) {
      setState(() {
        _courseError = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoadingCourse = false;
      });
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isSending) return;

    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/input_${DateTime.now().millisecondsSinceEpoch}.wav';

    final config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    );

    await _audioRecorder.start(config, path: path);

    await Future.delayed(const Duration(milliseconds: 400));

    _recordingStartedAt = DateTime.now();
    _currentRecordingPath = path;
    _recordingTimeoutTimer?.cancel();
    _recordingTimeoutTimer = Timer(_maxRecordingDuration, () {
      if (_isRecording) {
        _stopRecordingAndSend(autoStop: true);
      }
    });

    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecordingAndSend({bool autoStop = false}) async {
    if (!_isRecording) return;

    _recordingTimeoutTimer?.cancel();

    await Future.delayed(const Duration(milliseconds: 200));
    final startedAt = _recordingStartedAt;
    final pathFromRecorder = await _audioRecorder.stop();
    final path = pathFromRecorder ?? _currentRecordingPath;

    _recordingStartedAt = null;
    _currentRecordingPath = null;

    setState(() {
      _isRecording = false;
    });

    if (path == null) {
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      return;
    }

    final bytes = await file.length();
    final durationMs = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inMilliseconds;

    final tooShortByTime =
        durationMs < _minRecordingDuration.inMilliseconds && !autoStop;
    final tooShortBySize = bytes < _minRecordingBytes;

    if (tooShortByTime || tooShortBySize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Запись слишком короткая — удерживайте дольше')),
        );
      }
    } else {
      await _sendAudioToBackend(file);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordingTimeoutTimer?.cancel();
    _recordingStartedAt = null;
    _currentRecordingPath = null;
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _sendAudioToBackend(File file) async {
    try {
      final recognized = await _chatController.speechToText(file);
      if (!mounted) return;
      setState(() {
        _inputController.text = recognized;
      });
    } catch (e) {
      debugPrint('STT exception: $e');
    }
  }

  void _updateProgress() {
    while (_currentLevel <= _levelTargets.length &&
        _userWordCount >= _levelTargets[_currentLevel - 1]) {
      _currentLevel++;
      if (_currentLevel > _levelTargets.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amazing! You completed all 5 progress levels 🎉'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Great! You finished level ${_currentLevel - 1}. Level $_currentLevel unlocked!',
            ),
          ),
        );
      }
    }
  }

  double get _progressValue {
    if (_currentLevel > _levelTargets.length) return 1.0;
    final target = _levelTargets[_currentLevel - 1].toDouble();
    return (_userWordCount / target).clamp(0.0, 1.0);
  }

  String get _progressLabel {
    if (_currentLevel > _levelTargets.length) {
      return 'All levels completed: $_userWordCount words';
    }
    return 'Level $_currentLevel · ${_userWordCount}/${_levelTargets[_currentLevel - 1]} words';
  }

  bool _isWordSaved(String word) {
    return _savedWords.any(
      (entry) => entry.word.toLowerCase() == word.toLowerCase(),
    );
  }

  void _saveWord(SavedWord word) {
    setState(() {
      final index = _savedWords.indexWhere(
        (entry) => entry.word.toLowerCase() == word.word.toLowerCase(),
      );
      if (index >= 0) {
        _savedWords[index] = word;
      } else {
        _savedWords.add(word);
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${word.word} добавлено в словарь')));
  }

  void _removeSavedWord(String word) {
    if (!_isWordSaved(word)) return;

    setState(() {
      _savedWords.removeWhere(
        (entry) => entry.word.toLowerCase() == word.toLowerCase(),
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$word удалено из словаря')));
  }

  Future<void> _onWordTap(String rawWord) async {
    final word = rawWord.replaceAll(
      RegExp(r"[^\p{Letter}']", unicode: true),
      '',
    );
    if (word.isEmpty) return;

    try {
      final result = await _chatController.translateWord(word);
      final translation = result.translation;
      final example = result.example;
      final exampleTranslation = result.exampleTranslation;
      Uint8List? audioBytes;

      final audioBase64 = result.audioBase64;
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        try {
          audioBytes = base64Decode(audioBase64);
        } catch (e, st) {
          debugPrint('TRANSLATE AUDIO DECODE ERROR: $e\n$st');
        }
      }

      if (!mounted) return;

      final savedWord = SavedWord(
        word: word,
        translation: translation,
        example: example,
        exampleTranslation: exampleTranslation,
      );

      bool isSaved = _isWordSaved(word);
      bool isAudioLoading = false;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(child: Text(word)),
                  IconButton(
                    tooltip: 'Произнести слово',
                    icon: isAudioLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_up),
                    onPressed: () async {
                      if (isAudioLoading) return;

                      dialogSetState(() {
                        isAudioLoading = true;
                      });

                      if (audioBytes == null) {
                        final fetchedBytes =
                            await _chatController.fetchWordAudioBytes(word);

                        if (!context.mounted) return;

                        dialogSetState(() {
                          isAudioLoading = false;
                          audioBytes = fetchedBytes;
                        });

                        if (fetchedBytes == null || fetchedBytes.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Аудио недоступно, попробуйте позже'),
                            ),
                          );
                          return;
                        }
                      } else {
                        dialogSetState(() {
                          isAudioLoading = false;
                        });
                      }

                      final ok = await _playTtsBytes(audioBytes!);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Не удалось воспроизвести аудио'),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip:
                        isSaved ? 'Удалить из словаря' : 'Добавить в словарь',
                    icon: Icon(
                      isSaved ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                    ),
                    onPressed: () {
                      dialogSetState(() {
                        if (isSaved) {
                          _removeSavedWord(word);
                          isSaved = false;
                        } else {
                          _saveWord(savedWord);
                          isSaved = true;
                        }
                      });
                    },
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Перевод: $translation'),
                  const SizedBox(height: 8),
                  Text(
                    'Пример:',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(example),
                  const SizedBox(height: 8),
                  Text(
                    'Перевод примера:',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(exampleTranslation),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('TRANSLATE ERROR: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Translation error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnerName = _detectPartnerNameFromMessages();

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(partnerName),
            Text(
              '${widget.language} · level ${widget.level}',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildCharacterAvatar(),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = MediaQuery.of(context).size;
            final heroHeight = size.height * 0.3;
            final isMobile = isMobileLayout(constraints);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildHeroCard(
                    partnerName: partnerName,
                    isMobile: isMobile,
                    characterHeight: heroHeight,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedControl<int>(
                    value: _tabIndex,
                    onChanged: (value) => setState(() => _tabIndex = value),
                    items: [
                      SegmentedControlItem(label: 'Chat', value: 0),
                      SegmentedControlItem(label: 'Dictionary', value: 1),
                      SegmentedControlItem(label: 'Course', value: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _buildChatTab(),
                      _buildDictionaryTab(),
                      _buildCourseTab(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required String partnerName,
    required bool isMobile,
    required double characterHeight,
  }) {
    final look = _characterLook;
    return GradientCard(
      padding: const EdgeInsets.all(16),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroText(partnerName),
                const SizedBox(height: 12),
                SizedBox(
                  height: characterHeight,
                  width: double.infinity,
                  child: _buildCharacterStage(look),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildHeroText(partnerName)),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: characterHeight,
                    child: _buildCharacterStage(look),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroText(String partnerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сегодняшняя цель',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _progressLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          child: LinearProgressIndicator(
            value: _progressValue,
            minHeight: 10,
            color: AppColors.colorPrimary,
            backgroundColor: AppColors.colorDivider,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Chip(
              label: Text(
                partnerName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: AppColors.colorPrimary.withOpacity(0.12),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text('Level ${widget.level}'),
              backgroundColor: AppColors.colorAccentBlue.withOpacity(0.18),
            ),
          ],
        ),
      ],
    );
  }

  String _detectPartnerNameFromMessages() {
    if (widget.language == 'English') {
      return 'Michael';
    }
    if (widget.language == 'German') {
      return 'Hans';
    }
    if (widget.language == 'French') {
      return 'Jack';
    }
    if (widget.language == 'Spanish') {
      return 'Pablo';
    }
    if (widget.language == 'Italian') {
      return 'Marco';
    }
    if (widget.language == 'Korean') {
      return 'Kim';
    }
    return 'Michael';
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isUser) {
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;

    Color bgColor;
    Color textColor = AppColors.colorTextPrimary;
    String name;
    final accent = AppColors.colorPrimary;

    if (msg.isCorrections) {
      bgColor = AppColors.colorAccentYellow.withOpacity(0.6);
      textColor = AppColors.colorPrimaryDark;
      name = 'Corrections';
    } else if (isUser) {
      bgColor = Colors.white;
      name = 'Вы';
    } else {
      bgColor = accent;
      textColor = Colors.white;
      name = _detectPartnerNameFromMessages();
    }

    Widget content;
    if (!isUser && !msg.isCorrections) {
      final words = msg.text.split(RegExp(r'\s+'));
      content = Wrap(
        children: [
          for (int i = 0; i < words.length; i++)
            GestureDetector(
              onTap: () => _onWordTap(words[i]),
              child: Text(
                (i == 0 ? '' : ' ') + words[i],
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  decorationColor: textColor.withOpacity(0.5),
                ),
              ),
            ),
        ],
      );
    } else {
      content = Text(
        msg.text,
        style: TextStyle(color: textColor, fontSize: 14),
      );
    }

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: isUser ? Border.all(color: AppColors.colorDivider) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isUser ? 0.06 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                color:
                    msg.isCorrections ? Colors.black54 : Colors.grey.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final accent = _characterLook.accentColor;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => AnimatedContainer(
              duration: Duration(milliseconds: 400 + (i * 120)),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: _isSending ? 12 : 8,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.9 - i * 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
                boxShadow: AppShadows.card,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _messages.length +
                    ((_isSending && _messages.isNotEmpty) ? 1 : 0),
                itemBuilder: (context, index) {
                  final showTyping = _isSending && _messages.isNotEmpty;
                  if (showTyping && index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  final isUser = msg.role == 'user';
                  return _buildMessageBubble(msg, isUser);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            top: false,
            child: _buildInputBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterStage(CharacterLook look) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: CharacterBackgroundPainter(look)),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      top: constraints.maxHeight * 0.08,
                      left: constraints.maxWidth * 0.1,
                      child: Container(
                        width: constraints.maxWidth * 0.32,
                        height: constraints.maxWidth * 0.32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              lighten(look.primaryColor, 0.4).withOpacity(0.35),
                              Colors.white.withOpacity(0.0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: look.primaryColor.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: constraints.maxHeight * 0.12,
                      right: constraints.maxWidth * 0.05,
                      child: Container(
                        width: constraints.maxWidth * 0.28,
                        height: constraints.maxWidth * 0.28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              lighten(look.accentColor, 0.35).withOpacity(0.4),
                              Colors.white.withOpacity(0.0),
                            ],
                            begin: Alignment.bottomRight,
                            end: Alignment.topLeft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: constraints.maxWidth * 0.82,
                  height: constraints.maxWidth * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        lighten(look.primaryColor, 0.35).withOpacity(0.5),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: constraints.maxHeight * 0.08,
              child: Container(
                width: constraints.maxWidth * 0.38,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: constraints.maxHeight * 0.1,
              child: Container(
                width: constraints.maxWidth * 0.52,
                height: constraints.maxHeight * 0.22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.65),
                      lighten(look.accentColor, 0.28).withOpacity(0.35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(
                  8,
                ),
                child: LoopingPngAnimation(
                  frames: _characterFrames,
                  frameDuration: const Duration(milliseconds: 80),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDictionaryTab() {
    if (_savedWords.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.star_border_rounded,
          title: 'Пока пусто',
          message:
              'Нажмите на слово в чате и отметьте его звездой, чтобы добавить в словарь',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _savedWords.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final saved = _savedWords[index];

        return GradientCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.colorPrimary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: AppColors.colorPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saved.word,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      saved.translation,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.colorPrimaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (saved.example.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        saved.example,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (saved.exampleTranslation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        saved.exampleTranslation,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.colorTextSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Удалить из словаря',
                onPressed: () => _removeSavedWord(saved.word),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseTab() {
    final look = _characterLook;

    if (_isLoadingCourse && _coursePlan == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_coursePlan == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GradientCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.colorPrimary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_graph_rounded,
                          color: AppColors.colorPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Личный курс по ${widget.language}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Текущий уровень: ${widget.level}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CoursePill(
                          icon: Icons.psychology_alt_outlined,
                          label: 'Учитываем вводный тест',
                          color: look.accentColor,
                        ),
                        const SizedBox(width: 8),
                        _CoursePill(
                          icon: Icons.menu_book_outlined,
                          label: 'Грамматика + словарь',
                          color: look.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        _CoursePill(
                          icon: Icons.auto_stories_outlined,
                          label: 'Диалоги + произношение',
                          color: AppColors.colorAccentPink,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Сгенерируйте курс из нескольких уровней, адаптированный под ваш возраст, цели и результат теста. '
                    'Каждый уровень содержит уроки с упражнениями и словарём.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_courseError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _courseError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: PrimaryButton(
                      label: 'Сгенерировать курс',
                      expand: false,
                      onPressed: _loadCoursePlan,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final plan = _coursePlan!;
    final levels = plan.levels;
    final List<MapLessonPoint> mapLessons = [];
    for (final level in levels) {
      for (final lesson in level.lessons) {
        mapLessons.add(MapLessonPoint(level: level, lesson: lesson));
      }
    }
    final takeCount = math.min(mapLessons.length, lessonPositions.length);
    final firstFive = mapLessons.take(takeCount).toList(growable: false);
    final positionedLessons = <MapLessonPoint>[];
    for (var i = 0; i < firstFive.length; i++) {
      positionedLessons.add(
        firstFive[i].copyWithPosition(lessonPositions[i]),
      );
    }

    return MapScreen(
      language: plan.language,
      userLevel: widget.level,
      plan: plan,
      look: look,
      lessons: positionedLessons,
      completedLessons: _completedLessons,
      userInterests: _userInterests,
      onLessonCompleted: (lessonKey) {
        setState(() {
          _completedLessons.add(lessonKey);
        });
      },
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          border: Border.all(
            color: AppColors.colorPrimary.withOpacity(0.2),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTapDown: _isSending ? null : (_) => _startRecording(),
              onTapUp: _isSending ? null : (_) => _stopRecordingAndSend(),
              onTapCancel: _isSending ? null : _cancelRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.colorPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.colorPrimary.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Напишите сообщение…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => _sendUserMessage(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isSending ? null : _sendUserMessage,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.colorPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.colorPrimary.withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseLevelNode({
    required BuildContext context,
    required CourseLevelPlan level,
    required int index,
    required int total,
    required CharacterLook look,
    required Set<String> completedLessons,
  }) {
    final Color nodeColor = look.accentColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (index != 0)
              Container(
                width: 3,
                height: 22,
                color: Colors.grey.shade300,
              ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: nodeColor.withOpacity(0.12),
                border: Border.all(color: nodeColor, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: nodeColor,
                  fontSize: 13,
                ),
              ),
            ),
            if (index != total - 1)
              Container(
                width: 3,
                height: 40,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 18, color: nodeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Уровень ${level.levelIndex}: ${level.title}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  level.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (level.targetGrammar.isNotEmpty)
                      _CoursePill(
                        icon: Icons.rule_folder_outlined,
                        label: 'Grammar: ${level.targetGrammar.join(', ')}',
                        color: look.accentColor,
                      ),
                    if (level.targetVocab.isNotEmpty)
                      _CoursePill(
                        icon: Icons.auto_stories_outlined,
                        label: 'Vocab: ${level.targetVocab.join(', ')}',
                        color: look.primaryColor,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    for (int i = 0; i < level.lessons.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: (() {
                          final lesson = level.lessons[i];
                          final lessonKey = '${level.title}-${lesson.title}';
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LessonScreen(
                                    language: widget.language,
                                    level: widget.level,
                                    lesson: lesson,
                                    grammarTopics: lesson.grammarTopics,
                                    vocabTopics: lesson.vocabTopics,
                                    userInterests: _userInterests,
                                    onComplete: (total, done) {
                                      setState(() {
                                        _completedLessons.add(lessonKey);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: completedLessons.contains(lessonKey)
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.grey.shade50,
                                border: Border.all(
                                  color: completedLessons.contains(lessonKey)
                                      ? Colors.green
                                      : nodeColor.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: nodeColor.withOpacity(0.12),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: nodeColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lesson.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          lesson.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    completedLessons.contains(lessonKey)
                                        ? Icons.check_circle
                                        : Icons.play_arrow_rounded,
                                    color: completedLessons.contains(lessonKey)
                                        ? Colors.green
                                        : nodeColor,
                                  ),
                                ],
                              ),
                            ),
                          );
                        })(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterAvatar() {
    final look = _characterLook;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CharacterAvatar(look: look, size: 56),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: look.accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                look.badgeText,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CoursePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: darken(color, 0.18)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: darken(color, 0.18),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class CharacterBackgroundPainter extends CustomPainter {
  final CharacterLook look;

  CharacterBackgroundPainter(this.look);

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lighten(look.primaryColor, 0.3),
          Colors.white,
          lighten(look.accentColor, 0.25),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    final sunRect = Rect.fromCircle(
      center: Offset(size.width * 0.18, size.height * 0.2),
      radius: size.width * 0.25,
    );
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.85),
          lighten(look.accentColor, 0.35).withOpacity(0.25),
          Colors.transparent,
        ],
      ).createShader(sunRect);
    canvas.drawCircle(sunRect.center, sunRect.width / 2, sunPaint);

    final hillPaint = Paint()..color = look.accentColor.withOpacity(0.12);
    final hillPath = Path()
      ..moveTo(0, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.6,
        size.width * 0.45,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.92,
        size.width,
        size.height * 0.78,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    final dotsPaint = Paint()..color = look.accentColor.withOpacity(0.18);
    for (int i = 0; i < 12; i++) {
      final dx = (i.isEven ? size.width * 0.15 : size.width * 0.33) + i * 20;
      final dy = size.height * 0.15 + (i % 4) * 30;
      canvas.drawCircle(Offset(dx % size.width, dy), 6, dotsPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CharacterBackgroundPainter oldDelegate) =>
      oldDelegate.look != look;
}
