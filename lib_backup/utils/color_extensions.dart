import 'package:flutter/material.dart';

extension ColorWithValues on Color {
  /// Provides a stable replacement for usages that previously used `withOpacity`.
  ///
  /// Example: `color.withValues(opacity: 0.5)`
  Color withValues({int? alpha, int? red, int? green, int? blue, double? opacity}) {
    if (opacity != null) {
      final int a = (opacity * 255).round();
      final int aClamped = a < 0 ? 0 : (a > 255 ? 255 : a);
      return withAlpha(aClamped);
    }

    return Color.fromARGB(
      alpha ?? this.alpha,
      red ?? this.red,
      green ?? this.green,
      blue ?? this.blue,
    );
  }
}
