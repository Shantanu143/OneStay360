// lib/presentation/design/components/biz_button.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

enum BizButtonKind { primary, mint, tonal, outline, light, danger, ghost }

enum BizButtonSize { large, medium, compact, small }

/// The app's pill button. `primary` (green, soft glow) is the main call to
/// action, `mint` is for dark surfaces, `tonal` is the quiet secondary.
class BizButton extends StatelessWidget {
  const BizButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = BizButtonKind.primary,
    this.size = BizButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final BizButtonKind kind;
  final BizButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Shows a spinner in place of the content and ignores taps.
  final bool loading;

  /// Fill the available width (default) or hug the content.
  final bool expand;

  bool get _enabled => onPressed != null && !loading;

  ({Color bg, Color fg, Color? glow, BorderSide? border}) get _palette {
    switch (kind) {
      case BizButtonKind.primary:
        return (
          bg: BizColors.green,
          fg: Colors.white,
          glow: BizColors.green.withValues(alpha: 0.28),
          border: null,
        );
      case BizButtonKind.mint:
        return (
          bg: BizColors.mint,
          fg: BizColors.onMint,
          glow: null,
          border: null,
        );
      case BizButtonKind.tonal:
        return (
          bg: BizColors.page,
          fg: BizColors.ink,
          glow: null,
          border: null,
        );
      case BizButtonKind.outline:
        return (
          bg: Colors.white,
          fg: BizColors.green,
          glow: null,
          border: const BorderSide(color: BizColors.green, width: 1.5),
        );
      case BizButtonKind.light:
        return (
          bg: Colors.white,
          fg: BizColors.green,
          glow: null,
          border: null,
        );
      case BizButtonKind.danger:
        return (
          bg: BizColors.dangerTint,
          fg: BizColors.dangerInk,
          glow: null,
          border: null,
        );
      case BizButtonKind.ghost:
        return (
          bg: Colors.transparent,
          fg: BizColors.green,
          glow: null,
          border: null,
        );
    }
  }

  double get _height => switch (size) {
    BizButtonSize.large => 54,
    BizButtonSize.medium => 44,
    BizButtonSize.compact => 40,
    BizButtonSize.small => 36,
  };

  TextStyle get _textStyle => switch (size) {
    BizButtonSize.large => BizText.cta,
    BizButtonSize.medium => BizText.style(15, 700, letterSpacing: -0.1),
    BizButtonSize.compact => BizText.style(14, 700, letterSpacing: -0.1),
    BizButtonSize.small => BizText.style(14, 600),
  };

  double get _iconSize => switch (size) {
    BizButtonSize.large => 22,
    BizButtonSize.medium => 19,
    BizButtonSize.compact => 18,
    BizButtonSize.small => 17,
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
            (size == BizButtonSize.small || size == BizButtonSize.compact)
            ? 16
            : 22,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(_height / 2),
        border: p.border == null ? null : Border.fromBorderSide(p.border!),
        boxShadow: _enabled && p.glow != null && size == BizButtonSize.large
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
