import 'package:flutter/material.dart';
import 'package:language_tutor_app/app/routes.dart';
import 'package:language_tutor_app/providers/situation_provider.dart';
import 'package:language_tutor_app/screens/home/home_screen.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:provider/provider.dart';

class LanguageTutorApp extends StatelessWidget {
  const LanguageTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SituationProvider()),
      ],
      child: MaterialApp(
        title: 'Language Tutor',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
        routes: appRoutes,
      ),
    );
  }
}
