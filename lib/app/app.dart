import 'package:flutter/material.dart';
import 'package:language_tutor_app/app/routes.dart';
import 'package:language_tutor_app/screens/home/home_screen.dart';

class LanguageTutorApp extends StatelessWidget {
  const LanguageTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Language Tutor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4B5BB5)),
        useMaterial3: true,
        fontFamily: 'SF Pro Text',
      ),
      home: const HomeScreen(),
      routes: appRoutes,
    );
  }
}
