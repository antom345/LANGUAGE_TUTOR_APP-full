import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/services/lesson_service.dart';
import 'package:language_tutor_app/widgets/custom_button.dart';
import 'package:language_tutor_app/services/ai_check_service.dart';


class LessonScreen extends StatefulWidget {
  final String language;
  final String level;
  final LessonPlan lesson;
  final List<String> grammarTopics;
  final List<String> vocabTopics;
  final List<String> userInterests;
  final void Function(int total, int completed)? onComplete;

  const LessonScreen({
    super.key,
    required this.language,
    required this.level,
    required this.lesson,
    required this.grammarTopics,
    required this.vocabTopics,
    this.userInterests = const [],
    this.onComplete,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  LessonContentModel? _content;
  bool _isLoading = false;
  String? _error;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _finished = false;
  int totalXp = 0;
  String? _aiFeedback; // текст от ИИ для последнего задания
bool _aiChecking = false; // индикатор "идёт проверка ИИ"
final AiCheckService _aiService = AiCheckService();



  /// Для multiple_choice: индекс выбранного варианта
  final Map<int, int> _selectedOption = {};

  /// Для текстовых заданий (translate_sentence, fill_in_blank)
  final Map<int, String> _textAnswers = {};

  /// Для reorder_words: порядок, который выбрал пользователь
  final Map<int, List<int>> _reorderSelected = {};

  /// Какие вопросы уже проверены
  final Set<int> _checked = {};
  final Map<int, bool> _results = {};

  final LessonService _lessonService = LessonService();

  String _normalizeAnswer(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[’']"), "")
        .replaceAll(RegExp(r"[.?!,]"), "")
        .replaceAll(RegExp(r"\s+"), " ")
        .trim();
  }

  String _buildSentenceWithGap(LessonExercise ex) {
    if (ex.sentenceWithGap != null && ex.sentenceWithGap!.trim().isNotEmpty) {
      return ex.sentenceWithGap!;
    }
    final correct = ex.correctAnswer ?? '';
    if (correct.isEmpty) return ex.question;
    final regex =
        RegExp(r"\b" + RegExp.escape(correct) + r"\b", caseSensitive: false);
    return ex.question.replaceFirst(regex, "___");
  }

  String _normalizeSentence(String s) {
    return s
        .trim()
        .replaceAll(RegExp(r"[.?!]$"), "")
        .replaceAll(RegExp(r"\s+"), " ")
        .toLowerCase();
  }

  bool _isAnswerCorrect(LessonExercise ex, int index) {
    switch (ex.type) {
      case 'multiple_choice':
      case 'choose_correct_form':
        final selected = _selectedOption[index];
        return selected != null && selected == ex.correctIndex;
      case 'translate_sentence':
      case 'fill_in_blank':
        final user = _textAnswers[index] ?? '';
        final correct = ex.correctAnswer ?? '';
        if (user.trim().isEmpty || correct.trim().isEmpty) return false;
        return _normalizeAnswer(user) == _normalizeAnswer(correct);
      case 'reorder_words':
      case 'sentence_order':
        final words = ex.reorderWords ?? const <String>[];
        final selectedIdx = _reorderSelected[index] ?? const <int>[];
        if (selectedIdx.isEmpty) return false;
        final userSentence = selectedIdx
            .where((i) => i >= 0 && i < words.length)
            .map((i) => words[i])
            .join(' ');

        String? correctSentence;
        final correctOrder = ex.reorderCorrect ?? const <String>[];
        if (correctOrder.isNotEmpty) {
          correctSentence = correctOrder.join(' ');
        } else if ((ex.correctAnswer ?? '').trim().isNotEmpty) {
          correctSentence = ex.correctAnswer!;
        }
        if (correctSentence == null || correctSentence.trim().isEmpty) {
          return false;
        }

        return _normalizeSentence(userSentence) ==
            _normalizeSentence(correctSentence);
      default:
        return false;
    }
  }

  String? _correctAnswerText(LessonExercise ex) {
    switch (ex.type) {
      case 'multiple_choice':
      case 'choose_correct_form':
        if (ex.correctIndex != null &&
            ex.options != null &&
            ex.correctIndex! >= 0 &&
            ex.correctIndex! < ex.options!.length) {
          return ex.options![ex.correctIndex!];
        }
        return null;
      case 'translate_sentence':
      case 'fill_in_blank':
        return ex.correctAnswer?.trim().isNotEmpty == true
            ? ex.correctAnswer
            : null;
      case 'reorder_words':
      case 'sentence_order':
        final correct = ex.reorderCorrect;
        if (correct == null || correct.isEmpty) return null;
        return correct.join(' ');
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadLesson() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final content = await _lessonService.loadLesson(
        language: widget.language,
        level: widget.level,
        lesson: widget.lesson,
        grammarTopics: widget.grammarTopics,
        vocabTopics: widget.vocabTopics,
        interests: widget.userInterests,
      );
      setState(() {
        _content = content;
      });
    } catch (e) {
      debugPrint('LESSON LOAD ERROR: $e');
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkQuestion(int index) {
    if (_content == null) return;
    final ex = _content!.exercises[index];

    switch (ex.type) {
      case 'multiple_choice':
      case 'choose_correct_form':
        if (_selectedOption[index] == null) return;
        break;
      case 'translate_sentence':
      case 'fill_in_blank':
        final ans = (_textAnswers[index] ?? '').trim();
        if (ans.isEmpty) return;
        break;
      case 'reorder_words':
      case 'sentence_order':
        final order = _reorderSelected[index] ?? const <int>[];
        if (order.isEmpty) return;
        break;
      default:
        return;
    }

    setState(() {
      _checked.add(index);
      _results[index] = _isAnswerCorrect(ex, index);
    });
  }

  Future<void> _checkWithAI(int index) async {
  final ex = _content!.exercises[index];
  final needsTextAnswer = ex.type == 'translate_sentence' ||
      ex.type == 'fill_in_blank' ||
      ex.type == 'open_answer';
  final userAnswer = needsTextAnswer ? (_textAnswers[index] ?? '') : '';

  setState(() {
    _aiChecking = true;
    _aiFeedback = null;
  });

  try {
    final result = await _aiService.checkAnswer(
      exerciseType: ex.type,
      question: ex.question,
      userAnswer: userAnswer,
      correctAnswer: ex.correctAnswer,
      sampleAnswer: ex.sampleAnswer,
      evaluationCriteria: ex.evaluationCriteria,
      language: widget.language,
    );

    setState(() {
      _aiFeedback = result.feedback;
      totalXp += result.score; // начисляем баллы ИИ
      _checked.add(index);
      _results[index] = result.isCorrect;
    });
  } catch (e) {
    debugPrint("AI CHECK FAILED: $e");
    setState(() {
      _aiFeedback = "Не удалось проверить ответ. Попробуйте ещё раз.";
    });
  } finally {
    setState(() {
      _aiChecking = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    final content = _content;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
      ),
      body: _isLoading && content == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && content == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Не удалось загрузить урок. Попробуйте ещё раз.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadLesson,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : content == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            controller: _pageController,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            itemCount: content.exercises.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: _LessonIntroCard(
                                    title: widget.lesson.title,
                                    description: content.description,
                                    level: widget.level,
                                  ),
                                );
                              }

                              final exIndex = index - 1;
                              final ex = content.exercises[exIndex];
                              final selected = _selectedOption[exIndex];
                              final checked = _checked.contains(exIndex);
                              final isCorrect =
                                  checked && (_results[exIndex] ?? false);
                              final theme = Theme.of(context);
                              final cardSurfaceColor =
                                  theme.brightness == Brightness.dark
                                      ? Colors.black.withOpacity(0.55)
                                      : Colors.white.withOpacity(0.92);

                              return AnimatedPadding(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.all(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.06),
                                        Colors.white,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.zero,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      color: cardSurfaceColor,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Упражнение ${exIndex + 1}/${content.exercises.length}',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                              color: Colors.grey.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (ex.instruction != null &&
                                              ex.instruction!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            Text(
                                              ex.instruction!,
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                color: Colors.grey.shade800,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          Text(
                                            ex.question,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (ex.type == 'fill_in_blank' &&
                                              ex.sentenceWithGap != null) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: theme.brightness ==
                                                        Brightness.dark
                                                    ? Colors.black
                                                        .withOpacity(0.25)
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                _buildSentenceWithGap(ex),
                                                style: theme
                                                    .textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          if ((ex.type == 'multiple_choice' ||
                                                  ex.type ==
                                                      'choose_correct_form') &&
                                              ex.options != null) ...[
                                            ...List.generate(
                                              ex.options!.length,
                                              (i) => RadioListTile<int>(
                                                value: i,
                                                groupValue: selected,
                                                activeColor:
                                                    theme.colorScheme.primary,
                                                title: Text(ex.options![i]),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _selectedOption[exIndex] =
                                                        val!;
                                                  });
                                                },
                                              ),
                                            ),
                                          ] else if (ex.type ==
                                              'translate_sentence') ...[
                                            TextFormField(
                                              initialValue:
                                                  _textAnswers[exIndex] ?? '',
                                              maxLines: 3,
                                              decoration:
                                                  const InputDecoration(
                                                hintText: 'Введите перевод',
                                                border: OutlineInputBorder(),
                                                filled: true,
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  _textAnswers[exIndex] =
                                                      value;
                                                });
                                              },
                                            ),
                                          ] else if (ex.type ==
                                              'fill_in_blank') ...[
                                            TextFormField(
                                              initialValue:
                                                  _textAnswers[exIndex] ?? '',
                                              maxLines: 1,
                                              decoration:
                                                  const InputDecoration(
                                                hintText:
                                                    'Введите пропущенное слово',
                                                border: OutlineInputBorder(),
                                                filled: true,
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  _textAnswers[exIndex] =
                                                      value;
                                                });
                                              },
                                            ),
                                            if (ex.explanation
                                                .trim()
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                ex.explanation,
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ] else if (ex.type ==
                                              'open_answer') ...[
                                            TextFormField(
                                              initialValue:
                                                  _textAnswers[exIndex] ?? '',
                                              maxLines: 5,
                                              decoration:
                                                  const InputDecoration(
                                                hintText:
                                                    'Опишите ответ в свободной форме',
                                                border: OutlineInputBorder(),
                                                filled: true,
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  _textAnswers[exIndex] =
                                                      value;
                                                });
                                              },
                                            ),
                                            if (ex.sampleAnswer != null &&
                                                ex.sampleAnswer!
                                                    .trim()
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                'Пример ответа: ${ex.sampleAnswer}',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: Colors.grey.shade700,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ] else if ((ex.type ==
                                                      'reorder_words' ||
                                                  ex.type ==
                                                      'sentence_order') &&
                                              ex.reorderWords != null) ...[
                                            Text(
                                              'Нажмите по словам в нужном порядке:',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: List.generate(
                                                ex.reorderWords!.length,
                                                (i) {
                                                  final current =
                                                      _reorderSelected[
                                                              exIndex] ??
                                                          <int>[];
                                                  final isSelected =
                                                      current.contains(i);
                                                  final word =
                                                      ex.reorderWords![i];

                                                  return ChoiceChip(
                                                    label: Text(word),
                                                    selected: isSelected,
                                                    onSelected: (_) {
                                                      setState(() {
                                                        final updated =
                                                            List<int>.from(
                                                                current);
                                                        if (isSelected) {
                                                          updated.remove(i);
                                                        } else if (!updated
                                                            .contains(i)) {
                                                          updated.add(i);
                                                        }
                                                        _reorderSelected[
                                                                exIndex] =
                                                            updated;
                                                      });
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                            if ((_reorderSelected[exIndex] ??
                                                    const <int>[])
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                (_reorderSelected[exIndex] ??
                                                        const <int>[])
                                                    .map((i) =>
                                                        ex.reorderWords![i])
                                                    .join(' '),
                                                style: theme
                                                    .textTheme.bodyMedium,
                                              ),
                                            ],
                                          ],
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  if (_aiChecking) return;

                                                  if (ex.type ==
                                                          'translate_sentence' ||
                                                      ex.type ==
                                                          'open_answer') {
                                                    if ((_textAnswers[
                                                                    exIndex] ??
                                                                '')
                                                            .trim()
                                                            .isEmpty) {
                                                      return;
                                                    }
                                                    _checkWithAI(exIndex);
                                                    return;
                                                  }

                                                  _checkQuestion(exIndex);

                                                  if (_results[exIndex] ==
                                                      true) {
                                                    setState(
                                                        () => totalXp += 10);
                                                  }
                                                },
                                                icon:
                                                    const Icon(Icons.check),
                                                label:
                                                    const Text('Проверить'),
                                              ),
                                              if (checked)
                                                Icon(
                                                  isCorrect
                                                      ? Icons.check_circle
                                                      : Icons
                                                          .cancel_outlined,
                                                  color: isCorrect
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                            ],
                                          ),
                                          if (_aiFeedback != null) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              _aiFeedback!,
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                color: Colors.blueGrey,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                          if (checked) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              ex.explanation,
                                              style: theme
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            if (!isCorrect) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Правильный ответ: ${_correctAnswerText(ex) ?? '—'}',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color:
                                                      Colors.grey.shade800,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LessonPager(
                                currentPage: _currentPage,
                                totalPages: (content.exercises.length + 1),
                                onNext: _goNextPage,
                                onPrev: _goPrevPage,
                              ),
                              const SizedBox(height: 8),
                              PrimaryCtaButton(
                                label: _currentPage ==
                                        content.exercises.length
                                    ? 'Завершить'
                                    : 'Далее',
                                onTap: _currentPage ==
                                        content.exercises.length
                                    ? _finishLesson
                                    : _goNextPage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  void _goNextPage() {
  final content = _content;
  if (content == null) return;

  final totalPages = content.exercises.length + 1;

  // если это не последняя страница
  if (_currentPage < totalPages - 1) {
    _pageController
        .nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        )
        .then((_) {
      // После перехода страница уже обновится
      final isBossPage = _currentPage == content.exercises.length;

      if (isBossPage) {
        setState(() {
          totalXp = (totalXp * 1.5).round();  // множитель XP
        });
      }
    });
  }
}


  void _goPrevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishLesson() {
    final content = _content;
    if (content == null) return;
    final total = content.exercises.length;
    final completed = _checked.length;
    if (_finished) return;

    setState(() {
      _finished = true;
    });

    widget.onComplete?.call(total, completed);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Отлично!'),
        content: Text(
  'Вы завершили урок.\n'
  'Выполнено: $completed из $total.\n'
  'Получено XP: $totalXp.'
),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LessonIntroCard extends StatelessWidget {
  final String title;
  final String description;
  final String level;

  const _LessonIntroCard({
    required this.title,
    required this.description,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Урок по уровню $level',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Сначала прочитай описание урока, потом листай вправо к заданиям.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonPager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _LessonPager({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: currentPage == 0 ? null : onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (i) {
                final active = i == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 22 : 10,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
          IconButton(
            onPressed: currentPage == totalPages - 1 ? null : onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
