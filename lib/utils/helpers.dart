import 'package:flutter/material.dart';

Color lighten(Color color, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(color);
  final lighter = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
  return lighter.toColor();
}

Color darken(Color color, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(color);
  final darker = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return darker.toColor();
}

bool isMobileLayout(BoxConstraints c) => c.maxWidth < 600;
bool isTabletLayout(BoxConstraints c) => c.maxWidth >= 600 && c.maxWidth < 1024;
bool isDesktopLayout(BoxConstraints c) => c.maxWidth >= 1024;

extension NumSizeExtensions on num {
  double w(BuildContext context) =>
      this * MediaQuery.of(context).size.width / 375;

  double h(BuildContext context) =>
      this * MediaQuery.of(context).size.height / 812;
}
