// lib/presentation/design/components/biz_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Form field with its label above the input (not floating), matching the
/// rest of the design. Wraps [TextFormField] so it works inside a [Form].
class BizTextField extends StatelessWidget {
  const BizTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onTap,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.prefix,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.fieldKey,
    this.errorText,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final Widget? prefix;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  /// Key for the inner [TextFormField] (tests, scrolling to a field).
  final Key? fieldKey;

  /// Shown under the field (use when state lives outside a [Form]).
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: BizText.fieldLabel),
        ),
        TextFormField(
          key: fieldKey,
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          onTap: onTap,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          style: BizText.input,
          cursorColor: BizColors.green,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            errorText: errorText,
            helperStyle: BizText.caption,
            counterText: '',
            prefixIcon: prefix,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
