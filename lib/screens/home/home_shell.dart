import 'package:flutter/material.dart';
import 'package:language_tutor_app/screens/chat/character_conversation_screen.dart';
import 'package:language_tutor_app/screens/home/learning_language_select_screen.dart';
import 'package:language_tutor_app/pages/courses/tabs/courses_tab.dart';
import 'package:language_tutor_app/pages/courses/tabs/skills_tab.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:language_tutor_app/ui/widgets/app_scaffold.dart';
import 'package:language_tutor_app/ui/widgets/buttons.dart';
import 'package:language_tutor_app/ui/widgets/gradient_card.dart';

class HomeShell extends StatefulWidget {
  final int userAge;
  final String userGender;
  final List<String> userInterests;
  final String learningLanguage;

  const HomeShell({
    super.key,
    required this.userAge,
    required this.userGender,
    this.userInterests = const [],
    required this.learningLanguage,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late String _learningLanguage;
  static const _defaultLevel = 'B2';

  @override
  void initState() {
    super.initState();
    _learningLanguage = widget.learningLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _index,
        children: [
          CharacterConversationScreen(
            learningLanguage: _learningLanguage,
            partnerLanguage: _learningLanguage,
            level: _defaultLevel,
            topic: 'General conversation',
            userGender: widget.userGender,
            userAge: widget.userAge,
            partnerGender: 'male',
          ),
          MapTab(
            learningLanguage: _learningLanguage,
            userLevel: _defaultLevel,
            userAge: widget.userAge,
            userGender: widget.userGender,
            userInterests: widget.userInterests,
          ),
          ProfileScreen(
            age: widget.userAge,
            gender: widget.userGender,
            interests: widget.userInterests,
            learningLanguage: _learningLanguage,
            onChangeLanguage: (lang) {
              setState(() {
                _learningLanguage = lang;
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Диалог',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Карта',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    switch (_index) {
      case 1:
        return AppBar(
          title: const Text('Карта курсов'),
          centerTitle: true,
        );
      case 2:
        return AppBar(
          title: const Text('Профиль'),
          centerTitle: true,
        );
      case 0:
      default:
        return AppBar(
          title: const Text('Диалог'),
          centerTitle: true,
        );
    }
  }
}

class MapTab extends StatefulWidget {
  final String learningLanguage;
  final String userLevel;
  final int userAge;
  final String userGender;
  final List<String> userInterests;

  const MapTab({
    super.key,
    required this.learningLanguage,
    required this.userLevel,
    required this.userAge,
    required this.userGender,
    required this.userInterests,
  });

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(text: 'Темы'),
              Tab(text: 'Навыки'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                CoursesTab(
                  learningLanguage: widget.learningLanguage,
                  userLevel: widget.userLevel,
                  userAge: widget.userAge,
                  userGender: widget.userGender,
                  userInterests: widget.userInterests,
                ),
                SkillsTab(
                  learningLanguage: widget.learningLanguage,
                  userLevel: widget.userLevel,
                  userAge: widget.userAge,
                  userGender: widget.userGender,
                  userInterests: widget.userInterests,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class ProfileScreen extends StatelessWidget {
  final int age;
  final String gender;
  final List<String> interests;
  final String learningLanguage;
  final ValueChanged<String> onChangeLanguage;

  const ProfileScreen({
    super.key,
    required this.age,
    required this.gender,
    required this.interests,
    required this.learningLanguage,
    required this.onChangeLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.colorPrimary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.colorPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ваш аккаунт',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Возраст: $age · Пол: $gender',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Изучаемый язык: $learningLanguage',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: const Text('Цель: говорить свободно'),
                        backgroundColor:
                            AppColors.colorAccentBlue.withOpacity(0.14),
                      ),
                      Chip(
                        label: const Text('Уровень: B2'),
                        backgroundColor:
                            AppColors.colorAccentGreen.withOpacity(0.18),
                      ),
                      if (interests.isNotEmpty)
                        Chip(
                          label: Text('Интересы: ${interests.join(", ")}'),
                          backgroundColor:
                              AppColors.colorPrimary.withOpacity(0.12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Изменить язык',
                          expand: true,
                          onPressed: () async {
                            final lang = await Navigator.of(context).push(
                              MaterialPageRoute<String>(
                                builder: (_) => LearningLanguageSelectScreen(
                                  initialLanguage: learningLanguage,
                                  returnSelectionOnly: true,
                                ),
                              ),
                            );
                            if (lang is String && lang.isNotEmpty) {
                              onChangeLanguage(lang);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Изменить цель',
                          expand: true,
                          onPressed: () => _showStub(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Выйти',
                          expand: true,
                          onPressed: () => _showStub(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStub(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Скоро добавим действие'),
      ),
    );
  }
}
