// lib/presentation/design/components/app_dialogs.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'app_button.dart';
import 'app_chips.dart';

/// Confirmation dialog. Resolves true on confirm, false on cancel/dismiss.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.style(20, 700, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppText.body.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    kind: AppButtonKind.tonal,
                    size: AppButtonSize.medium,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    kind: destructive
                        ? AppButtonKind.danger
                        : AppButtonKind.primary,
                    size: AppButtonSize.medium,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Prompt for a line of text (rejection reason, note...). Null when cancelled.
Future<String?> showAppTextPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String hint = '',
  String confirmLabel = 'Submit',
  bool required = true,
  int maxLines = 3,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      message: message,
      hint: hint,
      confirmLabel: confirmLabel,
      required: required,
      maxLines: maxLines,
    ),
  );
}

/// Owns its controller so it is disposed only after the dialog has left the
/// screen (disposing it right after `showDialog` returns breaks the exit
/// animation).
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.message,
    required this.hint,
    required this.confirmLabel,
    required this.required,
    required this.maxLines,
  });

  final String title;
  final String? message;
  final String hint;
  final String confirmLabel;
  final bool required;
  final int maxLines;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: AppText.style(20, 700, letterSpacing: -0.3)),
            if (widget.message != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.message!,
                style: AppText.body.copyWith(color: AppColors.inkSoft),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: widget.maxLines,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: widget.hint),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    kind: AppButtonKind.tonal,
                    size: AppButtonSize.medium,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: widget.confirmLabel,
                    size: AppButtonSize.medium,
                    onPressed: widget.required && _controller.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_controller.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with the app's rounded top, drag handle and safe-area padding.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.38),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      reverseDuration: Duration(milliseconds: 260),
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (ctx) {
      final bottom =
          MediaQuery.viewPaddingOf(ctx).bottom +
          MediaQuery.viewInsetsOf(ctx).bottom;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DCDB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: AppText.style(20, 800, letterSpacing: -0.4)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.rowSubtitle),
            ],
            const SizedBox(height: 14),
            if (scrollable) Flexible(child: builder(ctx)) else builder(ctx),
          ],
        ),
      );
    },
  );
}

/// Floating toast above the nav bar. Replaces any toast already showing.
void showAppToast(
  BuildContext context,
  String message, {
  AppTone tone = AppTone.neutral,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final bg = switch (tone) {
    AppTone.danger => AppColors.dangerInk,
    AppTone.success => AppColors.greenDeep,
    _ => AppColors.card,
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bg,
        duration: const Duration(seconds: 3),
      ),
    );
}

/// A tappable row for choice sheets (sort, filter...). Shows a check when
/// [selected].
class AppSheetOption extends StatelessWidget {
  const AppSheetOption({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.rowTitle.copyWith(
                      color: selected ? AppColors.green : AppColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: AppText.rowSubtitle),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: AppColors.green, size: 22),
          ],
        ),
      ),
    );
  }
}
