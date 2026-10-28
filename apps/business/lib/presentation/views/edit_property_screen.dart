// lib/presentation/views/edit_property_screen.dart
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_states.dart';
import '../design/components/biz_step_pills.dart';
import '../design/tokens.dart';
import '../view_models/add_property_viewmodel.dart';
import 'property_form/property_form_steps.dart';

/// Editing a listed property: the add-property steps minus rooms (managed on
/// the property itself) and with the city locked. Saved through the
/// `updatePropertyDetails` callable. Pops `true` once saved.
class EditPropertyScreen extends StatefulWidget {
  const EditPropertyScreen({super.key, required this.businessId, required this.propertyId});

  final String businessId;
  final String propertyId;

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  static const _steps = [
    PropertyFormStep.basics,
    PropertyFormStep.photos,
    PropertyFormStep.pricing,
    PropertyFormStep.amenities,
    PropertyFormStep.rules,
  ];

  int _step = 0;
  String? _problem;
  bool _loading = true;
  String? _loadError;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final property = await context.read<PropertyRepository>().getPropertyById(widget.propertyId);
      if (!mounted) return;
      context.read<AddPropertyViewModel>().loadFrom(property);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "Couldn't load this property. Check your connection and try again.";
      });
    }
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _problem = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _save(AddPropertyViewModel vm) async {
    FocusScope.of(context).unfocus();
    for (var i = 0; i < _steps.length; i++) {
      final p = vm.problemAt(_steps[i]);
      if (p != null) {
        HapticFeedback.mediumImpact();
        _goTo(i);
        setState(() => _problem = p);
        return;
      }
    }
    try {
      await vm.saveEdits(businessId: widget.businessId, propertyId: widget.propertyId);
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _problem = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _next(AddPropertyViewModel vm) async {
    final problem = vm.problemAt(_steps[_step]);
    if (problem != null) {
      HapticFeedback.mediumImpact();
      setState(() => _problem = problem);
      return;
    }
    HapticFeedback.selectionClick();
    _goTo(_step + 1);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AddPropertyViewModel>();
    final last = _step == _steps.length - 1;
    final busy = vm.isLoading || vm.isUploadingImages;

    if (_loading || _loadError != null) {
      return BizScaffold(
        title: 'Edit property',
        onBack: () => Navigator.of(context).maybePop(),
        body: _loading
            ? const Padding(padding: EdgeInsets.all(16), child: BizSkeletonList(count: 3, cardHeight: 120))
            : BizErrorState(message: _loadError!, onRetry: _load),
      );
    }

    final body = switch (_steps[_step]) {
      PropertyFormStep.basics => BasicsStep(vm: vm, cityLocked: true),
      PropertyFormStep.photos => PhotosStep(vm: vm, existing: vm.existingImages, onRemoveExisting: vm.removeExistingImage),
      PropertyFormStep.pricing => PricingStep(vm: vm),
      PropertyFormStep.amenities => AmenitiesStep(vm: vm),
      PropertyFormStep.rules => RulesStep(vm: vm),
      PropertyFormStep.rooms => const SizedBox.shrink(),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy) return;
        if (_step > 0) return _goTo(_step - 1);
        final leave = await showBizConfirm(
          context,
          title: 'Discard changes?',
          message: 'Your edits to this property will be lost.',
          confirmLabel: 'Discard',
          cancelLabel: 'Keep editing',
          destructive: true,
        );
        if (leave && context.mounted) Navigator.of(context).pop(false);
      },
      child: BizScaffold(
        title: 'Edit property',
        eyebrow: vm.propertyNameController.text.isEmpty ? null : vm.propertyNameController.text,
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
            Expanded(
              child: BizButton(
                label: last ? 'Back' : 'Save',
                kind: BizButtonKind.tonal,
                onPressed: busy ? null : () => last ? _goTo(_step - 1) : _save(vm),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: BizButton(
                label: last ? 'Save changes' : 'Continue',
                icon: last ? Icons.check_rounded : null,
                trailingIcon: last ? null : Icons.arrow_forward_rounded,
                loading: busy,
                onPressed: () => last ? _save(vm) : _next(vm),
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
                  vm.isUploadingImages ? 'Uploading photos…' : 'Saving changes…',
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
