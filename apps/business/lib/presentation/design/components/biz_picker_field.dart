// lib/presentation/design/components/biz_picker_field.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

/// A field that opens a picker (date, day of month...) instead of a keyboard.
/// Looks like [BizTextField]: label above, white rounded box, optional error.
class BizPickerField extends StatelessWidget {
  const BizPickerField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.onTap,
    this.value,
    this.icon = Icons.calendar_today_outlined,
    this.error,
  });

  final String label;
  final String placeholder;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: BizText.fieldLabel),
        ),
        Pressable(
          scale: 0.99,
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(BizRadius.field),
              border: Border.all(
                color: error != null ? BizColors.badge : BizColors.fieldBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value! : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hasValue
                        ? BizText.input
                        : BizText.input.copyWith(
                            color: BizColors.inkSoft.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w400,
                          ),
                  ),
                ),
                Icon(icon, size: 20, color: BizColors.inkSoft),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              error!,
              style: BizText.caption.copyWith(color: BizColors.dangerInk),
            ),
          ),
      ],
    );
  }
}
