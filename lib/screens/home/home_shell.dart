import 'package:flutter/material.dart';
import 'package:language_tutor_app/screens/dialogs/dialogs_screen.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:language_tutor_app/ui/widgets/app_scaffold.dart';
import 'package:language_tutor_app/ui/widgets/gradient_card.dart';
import 'package:language_tutor_app/ui/widgets/buttons.dart';

class HomeShell extends StatefulWidget {
  final int userAge;
  final String userGender;
  final List<String> userInterests;

  const HomeShell({
    super.key,
    required this.userAge,
    required this.userGender,
    this.userInterests = const [],
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _index,
        children: [
          DialogsScreen(
            userAge: widget.userAge,
            userGender: widget.userGender,
          ),
          MapPlaceholderScreen(
            onGoDialogs: () => setState(() => _index = 0),
          ),
          ProfileScreen(
            age: widget.userAge,
            gender: widget.userGender,
            interests: widget.userInterests,
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
            label: 'Диалоги',
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
          title: const Text('Диалоги'),
          centerTitle: true,
        );
    }
  }
}

class MapPlaceholderScreen extends StatelessWidget {
  final VoidCallback onGoDialogs;

  const MapPlaceholderScreen({super.key, required this.onGoDialogs});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GradientCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.colorPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_outlined,
                  size: 32,
                  color: AppColors.colorPrimary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Здесь будет ваша пиксельная карта курсов',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Мы готовим приключенческую карту с уроками и квестами. '
                'Пока можно двигаться по диалогам — прогресс сохранится.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Продолжить диалоги',
                expand: false,
                onPressed: onGoDialogs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final int age;
  final String gender;
  final List<String> interests;

  const ProfileScreen({
    super.key,
    required this.age,
    required this.gender,
    required this.interests,
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
                        child: PrimaryButton(
                          label: 'Изменить цель',
                          expand: true,
                          onPressed: () => _showStub(context),
                        ),
                      ),
                      const SizedBox(width: 12),
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
