// lib/presentation/views/tenants/add_tenant_wizard.dart
import 'dart:io';

import 'package:firebase_services/services/tenant_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../app/actions.dart';
import '../../../app/business_shell.dart';
import '../../../app/refresh_signals.dart';
import '../../../data/providers/business_state_provider.dart';
import '../../../utils/permissions.dart';
import '../../design/components/biz_button.dart';
import '../../design/components/biz_chips.dart';
import '../../design/components/biz_dialogs.dart';
import '../../design/components/biz_header.dart';
import '../../design/components/biz_list_row.dart';
import '../../design/components/biz_states.dart';
import '../../design/components/biz_step_pills.dart';
import '../../design/tokens.dart';
import '../../view_models/tenant_wizard/assignment_data_source.dart';
import '../../view_models/tenant_wizard/draft_store.dart';
import '../../view_models/tenant_wizard/wizard_viewmodel.dart';
import '../qr_scanner_screen.dart';
import '../widgets/floating_nav_bar.dart';
import 'details_steps.dart';
import 'invitation_submitter.dart';
import 'property_step.dart';

/// The Tenants tab: a five-step wizard that places a tenant in a bed and
/// sends them an invitation (property -> tenant info -> lease -> bill ->
/// personal details).
class AddTenantWizard extends StatefulWidget {
  const AddTenantWizard({
    super.key,
    this.viewModelFactory,
    this.searchTenants,
    this.openScanner,
    this.onFinished,
  });

  /// Overrides for tests; the defaults talk to Firebase.
  final AddTenantWizardViewModel Function(BuildContext context)?
  viewModelFactory;
  final Future<List<TenantSearchResult>> Function(String query)? searchTenants;
  final Future<Map<String, dynamic>?> Function(BuildContext context)?
  openScanner;

  /// Called after the owner dismisses the "Invitation sent" message.
  final void Function(BuildContext context)? onFinished;

  @override
  State<AddTenantWizard> createState() => _AddTenantWizardState();
}

class _AddTenantWizardState extends State<AddTenantWizard> {
  late AddTenantWizardViewModel _vm;
  final ScrollController _scroll = ScrollController();
  int _lastStep = 0;
  late final TenantSearchService _search = TenantSearchService();

  static const _ctaLabels = [
    'Continue to tenant info',
    'Continue to lease',
    'Continue to bill',
    'Continue to personal details',
    'Send invitation',
  ];

  @override
  void initState() {
    super.initState();
    _vm = _createVm();
    _vm.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  AddTenantWizardViewModel _createVm() {
    final factory = widget.viewModelFactory;
    if (factory != null) return factory(context);

    final businessId =
        context.read<BusinessStateProvider>().businessId ?? 'none';
    return AddTenantWizardViewModel(
      assignments: FirestoreAssignmentSource(
        propertyScope: () => context.read<BusinessStateProvider>().propertyScope,
      ),
      submitter: submitInvitation,
      drafts: _LazyFileDraftStore('tenant_wizard_draft_$businessId.json'),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    final id = context.read<BusinessStateProvider>().businessId;
    if (id == null || id.isEmpty) return;
    await _vm.load(id);
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _vm.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (_vm.step != _lastStep) {
      _lastStep = _vm.step;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
    setState(() {});
  }

  // ─── Actions ─────────────────────────────────────────────────────────

  Future<void> _continue() async {
    HapticFeedback.lightImpact();
    if (_vm.isLastStep) {
      final ok = await _vm.submit();
      if (!mounted) return;
      if (ok) await _showSuccess();
      return;
    }
    _vm.next();
  }

  Future<void> _showSuccess() async {
    final name = _vm.mode == TenantEntryMode.search
        ? (_vm.selectedTenant?.name ?? 'The tenant')
        : (_vm.text(WizardField.fullName).trim().isEmpty
              ? 'The tenant'
              : _vm.text(WizardField.fullName).trim());

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BizRadius.hero),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: BizColors.greenTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: BizColors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Invitation sent',
                style: BizText.style(22, 700, letterSpacing: -0.4),
              ),
              const SizedBox(height: 6),
              Text(
                '$name will get a notification to confirm. Once they accept, the bed is theirs.',
                textAlign: TextAlign.center,
                style: BizText.body.copyWith(color: BizColors.inkSoft),
              ),
              const SizedBox(height: 22),
              BizButton(
                label: 'Done',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    _finish();
  }

  void _finish() {
    final custom = widget.onFinished;
    if (custom != null) {
      custom(context);
    } else {
      // The new tenant takes a bed, and the first rent becomes due.
      context.read<RefreshSignals>().changed(tenants: true, properties: true, payments: true);
      context.read<ShellController>().goTo(ShellTab.home);
    }
    // Start the next tenant from a clean form.
    final old = _vm;
    old.removeListener(_onChanged);
    _vm = _createVm()..addListener(_onChanged);
    _lastStep = 0;
    setState(() {});
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _saveDraft() async {
    HapticFeedback.lightImpact();
    await _vm.saveDraft();
    if (mounted) showBizToast(context, 'Draft saved', tone: BizTone.success);
  }

  Future<void> _changeProperty() {
    return showBizSheet<void>(
      context,
      title: 'Choose a property',
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in _vm.properties)
            BizSheetOption(
              label: p.name,
              subtitle: [
                p.address,
                p.city,
              ].where((s) => s.trim().isNotEmpty).join(', '),
              selected: p.id == _vm.property?.id,
              onTap: () {
                Navigator.of(sheet).pop();
                _vm.selectProperty(p);
              },
            ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _scan() async {
    final custom = widget.openScanner;
    if (custom != null) return custom(context);
    return Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    final topInset = MediaQuery.paddingOf(context).top;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomGap = keyboardOpen ? 8.0 : FloatingNavBar.heightFor(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 16),
          child: BizHeader(
            eyebrow: 'Tenants',
            title: 'Add Tenant',
            actions: [
              BizButton(
                label: 'Save draft',
                kind: BizButtonKind.light,
                size: BizButtonSize.medium,
                expand: false,
                onPressed: vm.property == null ? null : _saveDraft,
              ),
            ],
          ),
        ),
        BizStepPills(
          steps: AddTenantWizardViewModel.stepNames,
          current: vm.step,
          onStepTap: vm.goTo,
        ),
        const SizedBox(height: 8),
        Expanded(child: _body(vm)),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomGap),
          child: Row(
            children: [
              if (vm.step > 0) ...[
                BizRoundButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  size: 54,
                  onTap: vm.back,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: BizButton(
                  label: _ctaLabels[vm.step],
                  trailingIcon: vm.isLastStep
                      ? Icons.send_rounded
                      : Icons.arrow_forward_rounded,
                  loading: vm.submitting,
                  onPressed: vm.property == null || vm.loading
                      ? null
                      : _continue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(AddTenantWizardViewModel vm) {
    if (vm.loading && vm.properties.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: BizSkeletonList(count: 2, cardHeight: 150),
      );
    }
    if (vm.loadError != null) {
      return BizErrorState(
        title: "Couldn't load your properties",
        message: vm.loadError!,
        onRetry: _load,
      );
    }
    if (vm.property == null) {
      final canAdd = BusinessPermissions.fromRole(
        context.read<BusinessStateProvider>().role,
      ).canEditRooms;
      return BizEmptyState(
        icon: Icons.apartment_outlined,
        title: 'Add a property first',
        message: canAdd
            ? 'Tenants move into beds, so add a property with rooms and beds to begin.'
            : 'No properties have been assigned to you yet. Ask the owner for access.',
        actionLabel: canAdd ? 'Add property' : null,
        onAction: canAdd
            ? () async {
                await openAddProperty(context);
                if (mounted) _load();
              }
            : null,
      );
    }

    final Widget step = switch (vm.step) {
      0 => PropertyStep(vm: vm, onChangeProperty: _changeProperty),
      1 => TenantInfoStep(
        vm: vm,
        searchTenants: widget.searchTenants ?? _search.searchTenants,
        openScanner: _scan,
      ),
      2 => LeaseStep(vm: vm),
      3 => BillStep(vm: vm),
      _ => PersonalStep(vm: vm),
    };

    return ListView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (vm.draftAvailable && vm.step == 0 && vm.selectedBed == null) ...[
          _DraftBanner(onResume: vm.restoreDraft, onDiscard: vm.discardDraft),
          const SizedBox(height: 16),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(key: ValueKey('step-${vm.step}'), child: step),
        ),
        if (vm.submitError != null && vm.isLastStep) ...[
          const SizedBox(height: 16),
          Text(
            vm.submitError!,
            style: BizText.style(14, 600, color: BizColors.dangerInk),
          ),
        ],
      ],
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.onResume, required this.onDiscard});

  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BizRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BizIconTile(
                icon: Icons.edit_note_rounded,
                color: BizColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have an unfinished tenant',
                      style: BizText.rowTitle,
                    ),
                    Text(
                      'Pick up where you left off',
                      style: BizText.rowSubtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BizButton(
                  label: 'Resume',
                  size: BizButtonSize.compact,
                  onPressed: onResume,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BizButton(
                  label: 'Discard',
                  kind: BizButtonKind.tonal,
                  size: BizButtonSize.compact,
                  onPressed: onDiscard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A draft file in the app's documents folder, resolved on first use.
class _LazyFileDraftStore implements WizardDraftStore {
  _LazyFileDraftStore(this.name);

  final String name;
  FileDraftStore? _store;

  Future<FileDraftStore> _resolve() async {
    final existing = _store;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    return _store = FileDraftStore(File('${dir.path}/$name'));
  }

  @override
  Future<Map<String, dynamic>?> read() async => (await _resolve()).read();

  @override
  Future<void> write(Map<String, dynamic> draft) async =>
      (await _resolve()).write(draft);

  @override
  Future<void> clear() async => (await _resolve()).clear();
}
