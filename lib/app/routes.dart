import 'package:flutter/material.dart';
import 'package:language_tutor_app/screens/chat/chat_screen.dart';
import 'package:language_tutor_app/screens/home/home_screen.dart';
import 'package:language_tutor_app/screens/map/map_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/home': (_) => const HomeScreen(),
  '/map': (context) {
    final args = ModalRoute.of(context)?.settings.arguments as MapScreenArgs?;
    if (args == null) return const HomeScreen();
    return MapScreen(
      language: args.language,
      userLevel: args.userLevel,
      plan: args.plan,
      look: args.look,
      lessons: args.lessons,
      completedLessons: args.completedLessons,
      userInterests: args.userInterests,
      onLessonCompleted: args.onLessonCompleted,
    );
  },
  '/chat': (context) {
    final args = ModalRoute.of(context)?.settings.arguments as ChatScreenArgs?;
    if (args == null) return const HomeScreen();
    return ChatScreen(
      language: args.language,
      level: args.level,
      topic: args.topic,
      userGender: args.userGender,
      userAge: args.userAge,
      partnerGender: args.partnerGender,
    );
  },
};
