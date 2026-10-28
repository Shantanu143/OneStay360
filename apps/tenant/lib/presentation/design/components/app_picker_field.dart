// lib/presentation/design/components/app_picker_field.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

/// A field that opens a picker (date, day of month...) instead of a keyboard.
/// Looks like [AppTextField]: label above, white rounded box, optional error.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
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
          child: Text(label, style: AppText.fieldLabel),
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
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(
                color: error != null ? AppColors.badge : AppColors.fieldBorder,
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
                        ? AppText.input
                        : AppText.input.copyWith(
                            color: AppColors.inkSoft.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w400,
                          ),
                  ),
                ),
                Icon(icon, size: 20, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              error!,
              style: AppText.caption.copyWith(color: AppColors.dangerInk),
            ),
          ),
      ],
    );
  }
}
