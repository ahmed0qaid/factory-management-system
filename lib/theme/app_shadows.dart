import 'package:flutter/material.dart';

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> subtle(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: .06),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ];
}
