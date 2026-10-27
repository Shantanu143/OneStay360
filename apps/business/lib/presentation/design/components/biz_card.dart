// lib/presentation/design/components/biz_card.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

/// White rounded surface. Pass [onTap] to make the whole card pressable.
class BizCard extends StatelessWidget {
  const BizCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = BizRadius.card,
    this.color = Colors.white,
    this.onTap,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;

  /// Clip children to the rounded corners (photos, dividers).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget card = Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(color: color, borderRadius: shape),
      child: child,
    );
    if (onTap != null) {
      card = Pressable(scale: 0.985, onTap: onTap, child: card);
    }
    return card;
  }
}
