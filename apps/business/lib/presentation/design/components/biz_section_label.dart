// lib/presentation/design/components/biz_section_label.dart
import 'package:flutter/material.dart';

import '../tokens.dart';

/// "FLOOR                    6 of 19 beds free"
class BizSectionLabel extends StatelessWidget {
  const BizSectionLabel(
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
          Text(label.toUpperCase(), style: BizText.sectionLabel),
          if (trailing != null)
            Flexible(
              child: Text(
                trailing!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BizText.style(14, 500, color: BizColors.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}
