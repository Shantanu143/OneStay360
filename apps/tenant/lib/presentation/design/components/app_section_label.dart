// lib/presentation/design/components/app_section_label.dart
import 'package:flutter/material.dart';

import '../tokens.dart';

/// "FLOOR                    6 of 19 beds free"
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(
    this.label, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 5),
  });

  final String label;
  final String? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label.toUpperCase(), style: AppText.sectionLabel),
          if (trailing != null)
            Flexible(
              child: Text(
                trailing!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.style(14, 500, color: AppColors.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}
