// lib/presentation/views/add_property_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_step_pills.dart';
import '../design/tokens.dart';
import '../view_models/add_property_viewmodel.dart';
import 'property_form/property_form_steps.dart';

/// Listing a new property, one step at a time: basics, photos, pricing,
/// rooms, amenities and rules. Pops `true` once it is saved.
class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.businessPhone,
  });

  final String businessId;
  final String businessName;
  final String businessPhone;

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  int _step = 0;
  String? _problem;
  final _scroll = ScrollController();

  static const _steps = PropertyFormStep.values;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _problem = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _next(AddPropertyViewModel vm) async {
    FocusScope.of(context).unfocus();
    final problem = vm.problemAt(_steps[_step]);
    if (problem != null) {
      HapticFeedback.mediumImpact();
      setState(() => _problem = problem);
      return;
    }
    if (_step < _steps.length - 1) {
      HapticFeedback.selectionClick();
      _goTo(_step + 1);
      return;
    }
    // Last step: everything is checked again before saving.
    for (var i = 0; i < _steps.length; i++) {
      final p = vm.problemAt(_steps[i]);
      if (p != null) {
        _goTo(i);
        setState(() => _problem = p);
        return;
      }
    }
    try {
      await vm.addProperty(widget.businessId, widget.businessName, widget.businessPhone, context);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      // The view model already told the owner what went wrong.
    }
  }

  Future<bool> _confirmLeave() async {
    return showBizConfirm(
      context,
      title: 'Discard this property?',
      message: 'What you entered will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AddPropertyViewModel>();
    final last = _step == _steps.length - 1;
    final busy = vm.isLoading || vm.isUploadingImages;

    final body = switch (_steps[_step]) {
      PropertyFormStep.basics => BasicsStep(vm: vm),
      PropertyFormStep.photos => PhotosStep(vm: vm),
      PropertyFormStep.pricing => PricingStep(vm: vm),
      PropertyFormStep.rooms => RoomsStep(vm: vm),
      PropertyFormStep.amenities => AmenitiesStep(vm: vm),
      PropertyFormStep.rules => RulesStep(vm: vm),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy) return;
        if (_step > 0) return _goTo(_step - 1);
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop(false);
      },
      child: BizScaffold(
        title: 'Add property',
        eyebrow: widget.businessName.isEmpty ? null : widget.businessName,
        onBack: () => Navigator.of(context).maybePop(),
        belowHeader: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BizStepPills(
            steps: [for (final s in _steps) s.label],
            current: _step,
            onStepTap: busy ? null : _goTo,
          ),
        ),
        bottomBar: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: BizButton(
                  label: 'Back',
                  kind: BizButtonKind.tonal,
                  onPressed: busy ? null : () => _goTo(_step - 1),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: BizButton(
                label: last ? 'Add property' : 'Continue',
                icon: last ? Icons.check_rounded : null,
                trailingIcon: last ? null : Icons.arrow_forward_rounded,
                loading: busy,
                onPressed: () => _next(vm),
              ),
            ),
          ],
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (_problem != null) ...[
              BizBanner(message: _problem!, tone: BizTone.danger),
              const SizedBox(height: 14),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_step), child: body),
            ),
            if (busy) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  vm.isUploadingImages ? 'Uploading photos…' : 'Saving your property…',
                  style: BizText.caption,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
