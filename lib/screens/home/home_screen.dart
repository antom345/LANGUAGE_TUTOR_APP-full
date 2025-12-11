import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/models/lesson.dart';
import 'package:language_tutor_app/screens/chat/character_conversation_screen.dart';
import 'package:language_tutor_app/screens/home/home_shell.dart';
import 'package:language_tutor_app/screens/home/learning_language_select_screen.dart';
import 'package:language_tutor_app/services/character_service.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:language_tutor_app/ui/widgets/app_scaffold.dart';
import 'package:language_tutor_app/ui/widgets/buttons.dart';
import 'package:language_tutor_app/ui/widgets/gradient_card.dart';
import 'package:language_tutor_app/ui/widgets/segmented_control.dart';
import 'package:language_tutor_app/utils/helpers.dart';
import 'package:language_tutor_app/widgets/character_avatar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgeScreen();
  }
}

class AgeScreen extends StatefulWidget {
  const AgeScreen({super.key});

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  double _age = 24;

  void _continue() {
    final age = _age.round();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GenderScreen(userAge: age)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = !isMobileLayout(constraints);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 480 : constraints.maxWidth - 32,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сколько вам лет?',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Укажите возраст ползунком — так быстрее и удобнее.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      GradientCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Возраст',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Slider(
                                    value: _age,
                                    min: 5,
                                    max: 80,
                                    divisions: 75,
                                    label: '${_age.round()}',
                                    activeColor: AppColors.colorPrimary,
                                    onChanged: (v) => setState(() => _age = v),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text('5'),
                                      Text('80'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                    AppRadius.radiusLarge),
                                border:
                                    Border.all(color: AppColors.colorDivider),
                                boxShadow: AppShadows.card,
                              ),
                              child: Column(
                                children: [
                                  _ageActionButton(
                                    icon: Icons.remove,
                                    onTap: () => setState(
                                      () => _age = (_age - 1).clamp(5, 80),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.colorPrimary
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.radiusMedium,
                                      ),
                                    ),
                                    child: Text(
                                      '${_age.round()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: AppColors.colorPrimaryDark,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _ageActionButton(
                                    icon: Icons.add,
                                    onTap: () => setState(
                                      () => _age = (_age + 1).clamp(5, 80),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _languageAvatarStrip(),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child:
                            PrimaryButton(label: 'Далее', onPressed: _continue),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _ageActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
          ),
          backgroundColor: AppColors.colorPrimary.withOpacity(0.14),
          foregroundColor: AppColors.colorPrimary,
          elevation: 0,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _languageAvatarStrip() {
    final samples = [
      characterLookFor('English', 'female'),
      characterLookFor('German', 'male'),
      characterLookFor('French', 'female'),
      characterLookFor('Spanish', 'male'),
      characterLookFor('Italian', 'male'),
      characterLookFor('Korean', 'female'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final look in samples)
          CharacterAvatar(
            look: look,
            size: 56,
          ),
      ],
    );
  }
}

class InterestsScreen extends StatefulWidget {
  final int userAge;
  final String userGender;

  const InterestsScreen({
    super.key,
    required this.userAge,
    required this.userGender,
  });

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  static const _options = [
    'Путешествия',
    'Работа / Карьера',
    'Учёба',
    'Фильмы и сериалы',
    'Музыка',
    'Спорт',
    'Технологии и IT',
    'Еда и кулинария',
    'Отношения',
    'Игры',
  ];

  final Set<String> _selected = {};

  void _toggle(String option) {
    setState(() {
      if (_selected.contains(option)) {
        _selected.remove(option);
      } else {
        _selected.add(option);
      }
    });
  }

  void _finish(List<String> interests) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LearningLanguageSelectScreen(
          userAge: widget.userAge,
          userGender: widget.userGender,
          userInterests: interests,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = !isMobileLayout(constraints);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 520 : constraints.maxWidth - 24,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Что вам интересно?',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Мы будем подбирать темы диалогов по вашим интересам.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      GradientCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final option in _options)
                                  ChoiceChip(
                                    label: Text(option),
                                    selected: _selected.contains(option),
                                    onSelected: (_) => _toggle(option),
                                    selectedColor: AppColors.colorPrimary
                                        .withOpacity(0.16),
                                    labelStyle: TextStyle(
                                      color: _selected.contains(option)
                                          ? AppColors.colorPrimaryDark
                                          : AppColors.colorTextPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: AppColors.colorDivider,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _finish(const []),
                            child: const Text('Пропустить'),
                          ),
                          const Spacer(),
                          Expanded(
                            flex: 2,
                            child: PrimaryButton(
                              label: 'Сохранить',
                              onPressed: () => _finish(_selected.toList()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GenderScreen extends StatefulWidget {
  final int userAge;
  const GenderScreen({super.key, required this.userAge});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  String _gender = 'unspecified';

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            InterestsScreen(userAge: widget.userAge, userGender: _gender),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = !isMobileLayout(constraints);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 480 : constraints.maxWidth - 32,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Укажите ваш пол',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Возраст: ${widget.userAge} · Это поможет подобрать обращение.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      GradientCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Выбор',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            SegmentedControl<String>(
                              value: _gender,
                              onChanged: (value) =>
                                  setState(() => _gender = value),
                              items: [
                                SegmentedControlItem(
                                  label: 'Не важно',
                                  value: 'unspecified',
                                ),
                                SegmentedControlItem(
                                  label: 'Мужской',
                                  value: 'male',
                                ),
                                SegmentedControlItem(
                                  label: 'Женский',
                                  value: 'female',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _languageAvatarStrip(),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Далее',
                          onPressed: _continue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _languageAvatarStrip() {
    final samples = [
      characterLookFor('English', 'female'),
      characterLookFor('German', 'male'),
      characterLookFor('French', 'female'),
      characterLookFor('Spanish', 'female'),
      characterLookFor('Italian', 'male'),
      characterLookFor('Korean', 'female'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final look in samples)
          CharacterAvatar(
            look: look,
            size: 56,
          ),
      ],
    );
  }
}

class PlacementTestScreen extends StatefulWidget {
  final String language;

  const PlacementTestScreen({super.key, required this.language});

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen> {
  late final List<PlacementQuestion> _questions;
  final Map<int, int> _answers = {}; // вопрос -> выбранный вариант

  @override
  void initState() {
    super.initState();
    _questions =
        kPlacementTests[widget.language] ?? kPlacementTests['English']!;
  }

  Future<void> _finishTest() async {
    int correct = 0;
    for (var i = 0; i < _questions.length; i++) {
      final answer = _answers[i];
      if (answer != null && answer == _questions[i].correctIndex) {
        correct++;
      }
    }

    final score = correct / _questions.length;
    String level;
    if (score < 0.3) {
      level = 'A1';
    } else if (score < 0.6) {
      level = 'A2';
    } else if (score < 0.8) {
      level = 'B1';
    } else {
      level = 'B2';
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Результаты теста'),
        content: Text(
          'Вы ответили правильно на $correct из ${_questions.length} вопросов.\n'
          'Рекомендованный уровень: $level.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );

    Navigator.pop(context, level);
  }

  Widget _buildHeaderProgress(BuildContext context) {
    final total = _questions.length;
    final answered = _answers.length;
    final progress = total == 0 ? 0.0 : answered / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Прогресс теста',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < total; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < answered ? Icons.star : Icons.star_border,
                  size: 18,
                  color: i < answered
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                ),
              ),
            const Spacer(),
            Text(
              '$answered / $total отвечено',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionCard({
    required BuildContext context,
    required int index,
    required PlacementQuestion question,
    required int? selectedIndex,
  }) {
    final questionNumber = index + 1;
    final total = _questions.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Вопрос $questionNumber из $total',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    selectedIndex == null
                        ? Icons.help_outline
                        : Icons.check_circle_outline,
                    size: 20,
                    color: selectedIndex == null
                        ? Colors.grey.shade400
                        : Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                question.question,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Column(
                children: List.generate(question.options.length, (optionIndex) {
                  final optionText = question.options[optionIndex];
                  final isSelected = selectedIndex == optionIndex;
                  final letter =
                      String.fromCharCode(65 + optionIndex); // 'A', 'B', 'C'...

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _answers[index] = optionIndex;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.12)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 1.6 : 1,
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
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade400,
                                ),
                              ),
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                optionText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allAnswered = _answers.length == _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вводный тест'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.08),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeaderProgress(context),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final question = _questions[index];
                      final selectedIndex = _answers[index];
                      return _buildQuestionCard(
                        context: context,
                        index: index,
                        question: question,
                        selectedIndex: selectedIndex,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: allAnswered ? _finishTest : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      allAnswered
                          ? 'Закончить тест и посмотреть результат'
                          : 'Ответьте на все вопросы',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final Map<String, List<PlacementQuestion>> kPlacementTests = {
  'English': [
    PlacementQuestion(
      question: 'Choose the correct sentence (Present Simple):',
      options: [
        'He go to school every day.',
        'He goes to school every day.',
        'He going to school every day.',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Translate: "Я люблю читать книги."',
      options: [
        'I love to reading books.',
        'I like reading books.',
        'I am loving read books.',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Gap-fill: "Yesterday I ___ to the cinema."',
      options: [
        'go',
        'went',
        'gone',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Which word is NOT a verb?',
      options: [
        'run',
        'happy',
        'sleep',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Choose the correct preposition: "I am interested ___ music."',
      options: [
        'in',
        'on',
        'about',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Choose the closest in meaning to "rapid":',
      options: [
        'slow',
        'fast',
        'boring',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Similar sounding: "I left my book over ___."',
      options: [
        'their',
        'there',
        "they're",
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Phrasal verb: "to look up" in a dictionary means…',
      options: [
        'to admire someone',
        'to search for information',
        'to visit someone',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question:
          'Choose the correct phrasal verb: "He finally ___ smoking last year."',
      options: [
        'gave up',
        'gave in',
        'gave out',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Conditional: "If I ___ time, I will call you."',
      options: [
        'will have',
        'have',
        'had',
      ],
      correctIndex: 1,
    ),
  ],
  'German': [
    PlacementQuestion(
      question: 'Wähle den richtigen Satz (Präsens):',
      options: [
        'Er gehen jeden Tag zur Schule.',
        'Er geht jeden Tag zur Schule.',
        'Er geht jeden Tag zu Schule.',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Lücke ausfüllen: "Gestern ___ ich ins Kino."',
      options: [
        'gehe',
        'ging',
        'gegangen',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Welcher Artikel passt? "___ Tisch ist neu."',
      options: [
        'Der',
        'Die',
        'Das',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Welche Form ist richtig? "Ich ___ nach Hause gegangen."',
      options: [
        'bin',
        'habe',
        'werde',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Wähle das Wort, das NICHT zum Verb "sprechen" passt:',
      options: [
        'mit Freunden',
        'laut',
        'leise',
        'schnell',
      ],
      correctIndex: 3,
    ),
    PlacementQuestion(
      question: 'Präposition: "Ich warte ___ den Bus."',
      options: [
        'auf',
        'für',
        'an',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question:
          'Ähnliche Bedeutung: Welches Wort ist am nächsten zu "traurig"?',
      options: [
        'glücklich',
        'froh',
        'unglücklich',
      ],
      correctIndex: 2,
    ),
    PlacementQuestion(
      question: 'Trennbares Verb: "Ich ___ morgen früh ___." (aufstehen)',
      options: [
        'aufstehe auf',
        'stehe morgen auf',
        'stehe auf morgen',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Lücke: "Kannst du mir bitte ___?"',
      options: [
        'hilfen',
        'helfen',
        'geholfen',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Welche Form ist korrekt? "Wir ___ gestern Fußball."',
      options: [
        'spielen',
        'spielten',
        'gespielt',
      ],
      correctIndex: 1,
    ),
  ],
  'French': [
    PlacementQuestion(
      question: 'Choisis la phrase correcte (présent):',
      options: [
        'Il va à l\'école tous les jours.',
        'Il allez à l\'école tous les jours.',
        'Il aller à l\'école tous les jours.',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Complète: "Hier, je ___ au cinéma."',
      options: [
        'vais',
        'suis allé',
        'allé',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Quel mot est un adjectif ?',
      options: [
        'manger',
        'heureux',
        'vite',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Préposition: "Je pense ___ toi."',
      options: [
        'à',
        'de',
        'sur',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Choisis le mot le plus proche de "rapide":',
      options: [
        'lent',
        'vite',
        'triste',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Complète: "Si j\'ai le temps, je ___."',
      options: [
        'viens',
        'viendrai',
        'viendrais',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Quel mot n\'a PAS le même son initial que les autres ?',
      options: [
        'gare',
        'gros',
        'chat',
      ],
      correctIndex: 2,
    ),
    PlacementQuestion(
      question: 'Choisis la bonne forme de "être": "Nous ___ contents."',
      options: [
        'sommes',
        'êtes',
        'sont',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Complète: "Je ___ français depuis trois ans."',
      options: [
        'apprends',
        'appris',
        'apprendre',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Quel est le contraire de "grand" ?',
      options: [
        'petit',
        'fort',
        'joli',
      ],
      correctIndex: 0,
    ),
  ],
  'Spanish': [
    PlacementQuestion(
      question: 'Elige la frase correcta:',
      options: [
        'Yo va a la escuela.',
        'Yo voy a la escuela.',
        'Yo voy a escuela.',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Completa: "Ayer ___ al cine."',
      options: [
        'voy',
        'fui',
        'iba',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: '¿Cuál palabra NO es un verbo?',
      options: [
        'correr',
        'feliz',
        'leer',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Preposición: "Pienso ___ ti."',
      options: [
        'en',
        'a',
        'de',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Palabra parecida: ¿Qué palabra suena diferente?',
      options: [
        'casa',
        'caza',
        'cosa',
      ],
      correctIndex: 2,
    ),
    PlacementQuestion(
      question: 'Completa: "Si tengo tiempo, te ___."',
      options: [
        'llamé',
        'llamaré',
        'llamo',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Escoge el sinónimo de "rápido":',
      options: [
        'lento',
        ' veloz',
        'triste',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Completa: "He ___ español durante dos años."',
      options: [
        'estudiado',
        'estudiar',
        'estudio',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: '¿Cuál forma es correcta? "Nosotros ___ fútbol ayer."',
      options: [
        'jugamos',
        'jugaron',
        'jugué',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: '¿Cuál es el contrario de "grande"?',
      options: [
        'pequeño',
        'rápido',
        'alto',
      ],
      correctIndex: 0,
    ),
  ],
  'Italian': [
    PlacementQuestion(
      question: 'Scegli la frase corretta:',
      options: [
        'Io vado a scuola ogni giorno.',
        'Io va a scuola ogni giorno.',
        'Io andare a scuola ogni giorno.',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Completa: "Ieri ___ al cinema."',
      options: [
        'vado',
        'sono andato',
        'andato',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Quale parola NON è un verbo?',
      options: [
        'correre',
        'felice',
        'leggere',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Preposizione: "Penso ___ te."',
      options: [
        'a',
        'di',
        'su',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Scegli il sinonimo di "veloce":',
      options: [
        'lento',
        'rapido',
        'triste',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Completa: "Se ho tempo, ti ___."',
      options: [
        'chiamo',
        'chiamerò',
        'chiamato',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Quale parola suona diversa?',
      options: [
        'cane',
        'casa',
        'cava',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Completa: "Studio italiano ___ tre anni."',
      options: [
        'da',
        'per',
        'in',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: 'Qual è la forma corretta? "Noi ___ calcio ieri."',
      options: [
        'giochiamo',
        'abbiamo giocato',
        'giocato',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: 'Contrario di "grande":',
      options: [
        'piccolo',
        'alto',
        'forte',
      ],
      correctIndex: 0,
    ),
  ],
  'Korean': [
    PlacementQuestion(
      question: '어느 문장이 맞습니까?',
      options: [
        '저는 학교를 가요.',
        '저는 학교에 가요.',
        '저는 학교 가요에.',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: '빈칸 채우기: "어제 영화를 ___."',
      options: [
        '가요',
        '봤어요',
        '봤다',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: '어느 단어가 형용사입니까?',
      options: [
        '먹다',
        '예쁘다',
        '읽다',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: '비슷한 발음: 다른 단어는?',
      options: [
        '눈 (eye)',
        '눈 (snow)',
        '문 (door)',
      ],
      correctIndex: 2,
    ),
    PlacementQuestion(
      question: '조사: "학교___ 가요."',
      options: [
        '가',
        '에',
        '을',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: '빈칸 채우기: "시간이 ___ 도와줄게."',
      options: [
        '있으면',
        '있어서',
        '있다',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: '어느 단어가 동사가 아닙니까?',
      options: [
        '가다',
        '작다',
        '오다',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: '알맞은 표현: "만나서 ___."',
      options: [
        '고마워요',
        '반가워요',
        '주세요',
      ],
      correctIndex: 1,
    ),
    PlacementQuestion(
      question: '문장을 완성하세요: "한국어를 ___ 있어요."',
      options: [
        '공부해',
        '공부하고',
        '공부할',
      ],
      correctIndex: 0,
    ),
    PlacementQuestion(
      question: '반대말: "크다"의 반대는?',
      options: [
        '작다',
        '많다',
        '빠르다',
      ],
      correctIndex: 0,
    ),
  ],
};
