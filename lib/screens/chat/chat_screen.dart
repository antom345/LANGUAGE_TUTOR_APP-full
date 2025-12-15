import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/models/message.dart';
import 'package:language_tutor_app/screens/chat/chat_controller.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:language_tutor_app/ui/widgets/app_scaffold.dart';
import 'package:language_tutor_app/widgets/character_avatar.dart';
import 'package:language_tutor_app/services/character_service.dart';

class ChatViewController {
  _ChatViewState? _state;
  VoidCallback? onAttached;

  bool get isReady => _state != null;

  Future<void> startRecording() async {
    await _state?._startRecording();
  }

  Future<void> stopRecordingAndSend({bool autoStop = false}) async {
    await _state?._stopRecordingAndSend(autoStop: autoStop);
  }

  Future<void> cancelRecording() async {
    await _state?._cancelRecording();
  }

  void _attach(_ChatViewState state) {
    _state = state;
    onAttached?.call();
  }

  void _detach(_ChatViewState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

class ChatHistoryScreenArgs {
  final String learningLanguage;
  final String partnerLanguage;
  final String level;
  final String topic;
  final String userGender;
  final int? userAge;
  final String partnerGender;

  ChatHistoryScreenArgs({
    required this.learningLanguage,
    required this.partnerLanguage,
    required this.level,
    required this.topic,
    required this.userGender,
    required this.userAge,
    required this.partnerGender,
  });
}

class ChatHistoryScreen extends StatelessWidget {
  final String learningLanguage;
  final String partnerLanguage;
  final String level;
  final String topic;
  final String userGender;
  final int? userAge;
  final String partnerGender;

  const ChatHistoryScreen({
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
  Widget build(BuildContext context) {
    final partnerName = partnerNameForLanguage(partnerLanguage);
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
              '$learningLanguage · level $level',
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
            child: CharacterAvatar(
              look: characterLookFor(partnerLanguage, partnerGender),
              size: 48,
            ),
          ),
        ],
      ),
      body: ChatView(
        learningLanguage: learningLanguage,
        partnerLanguage: partnerLanguage,
        level: level,
        topic: topic,
        userGender: userGender,
        userAge: userAge,
        partnerGender: partnerGender,
        showHeader: false,
      ),
    );
  }
}

class ChatView extends StatefulWidget {
  final String learningLanguage;
  final String partnerLanguage;
  final String level;
  final String topic;
  final String userGender;
  final int? userAge;
  final String partnerGender;
  final ScrollController? scrollController;
  final bool showHeader;
  final ChatViewController? controller;

  const ChatView({
    super.key,
    required this.learningLanguage,
    required this.partnerLanguage,
    required this.level,
    required this.topic,
    required this.userGender,
    required this.userAge,
    required this.partnerGender,
    this.scrollController,
    this.showHeader = true,
    this.controller,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isSending = false;
  final List<SavedWord> _savedWords = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Queue<String> _ttsQueue = Queue<String>();
  bool _isTtsPlaying = false;
  StreamSubscription<void>? _playerCompleteSub;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimeoutTimer;
  DateTime? _recordingStartedAt;
  String? _currentRecordingPath;
  static const Duration _maxRecordingDuration = Duration(seconds: 20);
  static const Duration _minRecordingDuration = Duration(milliseconds: 700);
  static const int _minRecordingBytes = 2000;

  late final ChatController _chatController;
  bool _sentInitialRequest = false;

  CharacterLook get _characterLook =>
      characterLookFor(widget.partnerLanguage, widget.partnerGender);

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _chatController = ChatController(
      language: widget.learningLanguage,
      level: widget.level,
      topic: widget.topic,
      userGender: widget.userGender,
      userAge: widget.userAge,
      partnerGender: widget.partnerGender,
    );
    _playerCompleteSub =
        _audioPlayer.onPlayerComplete.listen((_) => _handlePlaybackComplete());
    _startConversation();
  }

  Future<bool> _playTtsFromUrl(String url) async {
    if (url.isEmpty) {
      debugPrint('TTS: empty url, skip');
      return false;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      return true;
    } catch (e) {
      debugPrint('TTS play error: $e');
      return false;
    }
  }

  void _enqueueTtsUrl(String url) {
    if (url.isEmpty) return;
    _ttsQueue.add(url);
    if (!_isTtsPlaying) {
      unawaited(_playNextQueued());
    }
  }

  Future<void> _playNextQueued() async {
    if (_isTtsPlaying || _ttsQueue.isEmpty) return;
    final nextUrl = _ttsQueue.removeFirst();
    _isTtsPlaying = true;
    final ok = await _playTtsFromUrl(nextUrl);
    if (!ok) {
      _isTtsPlaying = false;
      await _playNextQueued();
    }
  }

  void _handlePlaybackComplete() {
    _isTtsPlaying = false;
    if (_ttsQueue.isNotEmpty) {
      unawaited(_playNextQueued());
    }
  }

  Future<void> _speakAssistantReply(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    try {
      final audioUrl = await _chatController.fetchMessageTtsUrl(normalized);
      if (audioUrl == null || audioUrl.isEmpty) {
        return;
      }

      if (!mounted) return;
      _enqueueTtsUrl(audioUrl);
    } catch (e, st) {
      debugPrint('Auto TTS error: $e\n$st');
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _inputController.dispose();
    _playerCompleteSub?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _recordingTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _startConversation() async {
    if (_sentInitialRequest) return;
    if (_messages.isEmpty) return;
    _sentInitialRequest = true;
    await _sendToBackend(initial: true);
  }

  Future<void> _sendUserMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _inputController.clear();
    });

    await _sendToBackend(initial: false);
  }

  Future<void> _sendRecognizedMessage(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: normalized));
    });

    await _sendToBackend(initial: false);
  }

  Future<void> _sendToBackend({required bool initial}) async {
    setState(() {
      _isSending = true;
    });

    try {
      final data = await _chatController.sendChat(_messages, initial: initial);
      final reply = data.reply;
      final correctionsText = data.correctionsText ?? '';
      String? assistantReplyForTts;

      setState(() {
        final normalizedReply = reply.trim();
        if (normalizedReply.isNotEmpty) {
          _messages.add(ChatMessage(role: 'assistant', text: normalizedReply));
          assistantReplyForTts = normalizedReply;
        }
        final normalizedCorrections = correctionsText.trim();
        if (normalizedCorrections.isNotEmpty) {
          _messages.add(
            ChatMessage(
              role: 'assistant',
              text: normalizedCorrections,
              isCorrections: true,
            ),
          );
        }
      });

      if (assistantReplyForTts != null) {
        unawaited(_speakAssistantReply(assistantReplyForTts!));
      }
    } on FormatException catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            text: 'System: Invalid server response format',
          ),
        );
      });
      debugPrint('CHAT PARSE ERROR: $e');
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

      final cleaned = _cleanRecognizedText(recognized);
      if (cleaned.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось распознать речь')),
          );
        }
        return;
      }

      // Автоматически отправляем распознанное сообщение.
      if (_isSending) {
        // Если что-то уже отправляется, просто покажем текст в поле ввода.
        _inputController.text = cleaned;
      } else {
        await _sendRecognizedMessage(cleaned);
      }
    } catch (e) {
      debugPrint('STT exception: $e');
    }
  }

  String _cleanRecognizedText(String raw) {
    var text = raw.trim();
    // Убираем ведущие таймстампы вида [00:00:00.000 --> 00:00:03.440]
    text = text.replaceFirst(RegExp(r'^\s*\[[^\]]*\]\s*'), '');
    return text.trim();
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
      String? audioUrl = result.audioUrl;

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

                      if (audioUrl?.isEmpty ?? true) {
                        final fetchedUrl =
                            await _chatController.fetchWordAudioUrl(word);

                        if (!context.mounted) return;

                        dialogSetState(() {
                          isAudioLoading = false;
                          audioUrl = fetchedUrl;
                        });

                        if (fetchedUrl?.isEmpty ?? true) {
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

                      _enqueueTtsUrl(audioUrl!);
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
    final partnerName = partnerNameForLanguage(widget.partnerLanguage);
    return SafeArea(
      child: Column(
        children: [
          if (widget.showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  CharacterAvatar(look: _characterLook, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partnerName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
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
                ],
              ),
            ),
          Expanded(child: _buildChatArea()),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
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
                controller: widget.scrollController,
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
      name = partnerNameForLanguage(widget.partnerLanguage);
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
}

String partnerNameForLanguage(String language) {
  switch (language) {
    case 'English':
      return 'Michael';
    case 'German':
      return 'Hans';
    case 'French':
      return 'Jack';
    case 'Spanish':
      return 'Pablo';
    case 'Italian':
      return 'Marco';
    case 'Korean':
      return 'Kim';
    default:
      return 'Michael';
  }
}
