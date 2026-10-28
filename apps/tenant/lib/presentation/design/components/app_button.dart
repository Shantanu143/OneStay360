// lib/presentation/design/components/app_button.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

enum AppButtonKind { primary, mint, tonal, outline, light, danger, ghost }

enum AppButtonSize { large, medium, compact, small }

/// The app's pill button. `primary` (green, soft glow) is the main call to
/// action, `mint` is for dark surfaces, `tonal` is the quiet secondary.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Shows a spinner in place of the content and ignores taps.
  final bool loading;

  /// Fill the available width (default) or hug the content.
  final bool expand;

  bool get _enabled => onPressed != null && !loading;

  ({Color bg, Color fg, Color? glow, BorderSide? border}) get _palette {
    switch (kind) {
      case AppButtonKind.primary:
        return (
          bg: AppColors.green,
          fg: Colors.white,
          glow: AppColors.green.withValues(alpha: 0.28),
          border: null,
        );
      case AppButtonKind.mint:
        return (
          bg: AppColors.mint,
          fg: AppColors.onMint,
          glow: null,
          border: null,
        );
      case AppButtonKind.tonal:
        return (
          bg: AppColors.page,
          fg: AppColors.ink,
          glow: null,
          border: null,
        );
      case AppButtonKind.outline:
        return (
          bg: Colors.white,
          fg: AppColors.green,
          glow: null,
          border: const BorderSide(color: AppColors.green, width: 1.5),
        );
      case AppButtonKind.light:
        return (
          bg: Colors.white,
          fg: AppColors.green,
          glow: null,
          border: null,
        );
      case AppButtonKind.danger:
        return (
          bg: AppColors.dangerTint,
          fg: AppColors.dangerInk,
          glow: null,
          border: null,
        );
      case AppButtonKind.ghost:
        return (
          bg: Colors.transparent,
          fg: AppColors.green,
          glow: null,
          border: null,
        );
    }
  }

  double get _height => switch (size) {
    AppButtonSize.large => 54,
    AppButtonSize.medium => 44,
    AppButtonSize.compact => 40,
    AppButtonSize.small => 36,
  };

  TextStyle get _textStyle => switch (size) {
    AppButtonSize.large => AppText.cta,
    AppButtonSize.medium => AppText.style(15, 700, letterSpacing: -0.1),
    AppButtonSize.compact => AppText.style(14, 700, letterSpacing: -0.1),
    AppButtonSize.small => AppText.style(14, 600),
  };

  double get _iconSize => switch (size) {
    AppButtonSize.large => 22,
    AppButtonSize.medium => 19,
    AppButtonSize.compact => 18,
    AppButtonSize.small => 17,
  };

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final style = _textStyle.copyWith(color: p.fg);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _iconSize, color: p.fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: _iconSize, color: p.fg),
        ],
      ],
    );

    final body = Container(
      height: _height,
      padding: EdgeInsets.symmetric(
        horizontal:
            (size == AppButtonSize.small || size == AppButtonSize.compact)
            ? 16
            : 22,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(_height / 2),
        border: p.border == null ? null : Border.fromBorderSide(p.border!),
        boxShadow: _enabled && p.glow != null && size == AppButtonSize.large
            ? [
                BoxShadow(
                  color: p.glow!,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: loading ? 0 : 1, child: content),
          if (loading)
            SizedBox(
              width: _iconSize - 2,
              height: _iconSize - 2,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: p.fg),
            ),
        ],
      ),
    );

    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Pressable(
        onTap: _enabled ? onPressed : null,
        scale: 0.97,
        semanticLabel: label,
        child: expand ? SizedBox(width: double.infinity, child: body) : body,
      ),
    );
  }
}
