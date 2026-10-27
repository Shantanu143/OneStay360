// lib/presentation/design/components/biz_search_field.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Rounded grey search box with a debounced [onChanged] and a clear button.
class BizSearchField extends StatefulWidget {
  const BizSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.debounce = const Duration(milliseconds: 250),
    this.onSubmitted,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  /// How long typing must pause before [onChanged] fires.
  final Duration debounce;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<BizSearchField> createState() => _BizSearchFieldState();
}

class _BizSearchFieldState extends State<BizSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onText);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  String _lastText = '';

  void _onText() {
    // Rebuild for the clear button; only react to actual text changes.
    setState(() {});
    final text = _controller.text;
    if (text == _lastText) return;
    _lastText = text;
    _timer?.cancel();
    if (widget.debounce == Duration.zero) {
      widget.onChanged(text);
    } else {
      _timer = Timer(widget.debounce, () => widget.onChanged(text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: BizColors.searchField,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, size: 22, color: BizColors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmitted,
              style: BizText.style(17, 400),
              cursorColor: BizColors.green,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: BizText.style(
                  17,
                  400,
                  color: BizColors.inkSoft.withValues(alpha: 0.75),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: BizColors.inkSoft,
              ),
              onPressed: _controller.clear,
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
