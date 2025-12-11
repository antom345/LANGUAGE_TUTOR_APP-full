import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/character.dart';
import 'package:language_tutor_app/screens/chat/character_conversation_screen.dart';
import 'package:language_tutor_app/screens/home/home_screen.dart';
import 'package:language_tutor_app/services/character_service.dart';
import 'package:language_tutor_app/ui/widgets/gradient_card.dart';
import 'package:language_tutor_app/ui/widgets/language_character_card.dart';
import 'package:language_tutor_app/ui/widgets/language_chip.dart';
import 'package:language_tutor_app/utils/helpers.dart';
import 'package:language_tutor_app/widgets/character_avatar.dart';

class CharacterSelectScreen extends StatefulWidget {
  final int userAge;
  final String userGender;
  final String learningLanguage;

  const CharacterSelectScreen({
    super.key,
    required this.userAge,
    required this.userGender,
    required this.learningLanguage,
  });

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  final List<Map<String, Object>> _chats = [
    {
      'name': 'Michael',
      'language': 'English',
      'partnerGender': 'male',
      'color': const Color(0xFF6C63FF),
    },
    {
      'name': 'Hans',
      'language': 'German',
      'partnerGender': 'male',
      'color': const Color(0xFF00BFA6),
    },
    {
      'name': 'Jack',
      'language': 'French',
      'partnerGender': 'male',
      'color': const Color(0xFFFF6584),
    },
    {
      'name': 'Pablo',
      'language': 'Spanish',
      'partnerGender': 'male',
      'color': const Color(0xFFFFB300),
    },
    {
      'name': 'Marco',
      'language': 'Italian',
      'partnerGender': 'male',
      'color': const Color(0xFF29B6F6),
    },
    {
      'name': 'Kim',
      'language': 'Korean',
      'partnerGender': 'male',
      'color': const Color(0xFF8E24AA),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Персонажи',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Выберите персонажа, чтобы начать разговор',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _CharacterList(
                chats: _chats,
                onOpen: _openChat,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(
    BuildContext context,
    String characterLanguage,
    String partnerGender,
  ) async {
    final level = await _pickLevel(context);
    if (level == null || !mounted) return;

    final chosenLevel =
        await _offerPlacementChoice(context, widget.learningLanguage, level);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CharacterConversationScreen(
          learningLanguage: widget.learningLanguage,
          partnerLanguage: characterLanguage,
          level: chosenLevel,
          topic: 'General conversation',
          userGender: widget.userGender,
          userAge: widget.userAge,
          partnerGender: partnerGender,
        ),
      ),
    );
  }

  Future<String?> _pickLevel(BuildContext context) {
    const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    return showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final accent = theme.colorScheme.primary;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.emoji_objects_outlined,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Выберите уровень языка',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          splashRadius: 20,
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final lvl in levels)
                          _LevelChip(
                            label: lvl,
                            accent: accent,
                            onTap: () => Navigator.of(context).pop(lvl),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _offerPlacementChoice(
      BuildContext context, String language, String currentLevel) async {
    String? action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Хотите пройти короткий тест?'),
        content: const Text(
          'Это займет пару минут и поможет точнее подобрать курс. Можно пропустить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('skip'),
            child: const Text('Пропустить'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('test'),
            child: const Text('Пройти тест'),
          ),
        ],
      ),
    );

    if (action == 'test') {
      final testedLevel = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PlacementTestScreen(language: language),
        ),
      );
      return testedLevel ?? currentLevel;
    }

    return currentLevel;
  }
}

class _CharacterList extends StatelessWidget {
  final List<Map<String, Object>> chats;
  final Future<void> Function(BuildContext, String, String) onOpen;

  const _CharacterList({
    required this.chats,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final chat = chats[i];
        final name = chat['name'] as String;
        final lang = chat['language'] as String;
        final partnerGender = chat['partnerGender'] as String;
        final accent = chat['color'] as Color;
        final look = characterLookFor(lang, partnerGender);
        final code = _codeForLanguageValue(lang, look);

        return LanguageCharacterCard(
          name: name,
          language: lang,
          code: code,
          hint: 'Нажмите, чтобы начать диалог с персонажем',
          accent: accent,
          onTap: () => onOpen(context, lang, partnerGender),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              LanguageChip(code: code, size: 50),
              Positioned(
                bottom: -6,
                right: -10,
                child: GradientCard(
                  padding: const EdgeInsets.all(6),
                  margin: EdgeInsets.zero,
                  colors: [
                    accent.withOpacity(0.16),
                    Colors.white,
                  ],
                  child: CharacterAvatar(
                    look: look,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _codeForLanguageValue(String lang, CharacterLook look) {
  if (lang.length >= 2) return lang.substring(0, 2).toUpperCase();
  return look.badgeText;
}

class _LevelChip extends StatefulWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _LevelChip({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_LevelChip> createState() => _LevelChipState();
}

class _LevelChipState extends State<_LevelChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 140),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.accent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accent.withOpacity(0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: darken(widget.accent, 0.24),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
