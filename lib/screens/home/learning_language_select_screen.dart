import 'package:flutter/material.dart';
import 'package:language_tutor_app/screens/home/home_shell.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:language_tutor_app/ui/widgets/app_scaffold.dart';
import 'package:language_tutor_app/ui/widgets/buttons.dart';
import 'package:language_tutor_app/ui/widgets/gradient_card.dart';
import 'package:language_tutor_app/ui/widgets/language_chip.dart';

class LearningLanguageSelectScreen extends StatefulWidget {
  final int? userAge;
  final String? userGender;
  final List<String> userInterests;
  final String? initialLanguage;
  final bool returnSelectionOnly;

  const LearningLanguageSelectScreen({
    super.key,
    this.userAge,
    this.userGender,
    this.userInterests = const [],
    this.initialLanguage,
    this.returnSelectionOnly = false,
  });

  @override
  State<LearningLanguageSelectScreen> createState() =>
      _LearningLanguageSelectScreenState();
}

class _LearningLanguageSelectScreenState
    extends State<LearningLanguageSelectScreen> {
  final _languages = const [
    {'code': 'EN', 'label': 'English'},
    {'code': 'DE', 'label': 'German'},
    {'code': 'FR', 'label': 'French'},
    {'code': 'ES', 'label': 'Spanish'},
    {'code': 'IT', 'label': 'Italian'},
    {'code': 'KR', 'label': 'Korean'},
  ];

  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выберите язык, который хотите изучать',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Вы всегда сможете его сменить в профиле',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final lang in _languages)
                        _LanguageBadge(
                          code: lang['code']!,
                          label: lang['label']!,
                          selected: _selected == lang['label'],
                          onTap: () =>
                              setState(() => _selected = lang['label']!),
                        ),
                    ],
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Продолжить',
                onPressed: _selected == null ? null : _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finish() {
    final chosen = _selected!;
    if (widget.returnSelectionOnly) {
      Navigator.of(context).pop(chosen);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeShell(
          userAge: widget.userAge ?? 18,
          userGender: widget.userGender ?? 'unspecified',
          userInterests: widget.userInterests,
          learningLanguage: chosen,
        ),
      ),
      (route) => false,
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageBadge({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.colorPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : AppColors.colorDivider,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
          color: Colors.white.withOpacity(0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientCard(
              padding: const EdgeInsets.all(10),
              margin: EdgeInsets.zero,
              colors: [
                accent.withOpacity(0.14),
                Colors.white,
              ],
              child: LanguageChip(
                code: code,
                size: 60,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
