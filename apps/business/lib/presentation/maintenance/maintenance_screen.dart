// lib/presentation/maintenance/maintenance_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/business_state_provider.dart';
import '../common/device_actions.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_list_row.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import 'firestore_maintenance_source.dart';
import 'maintenance_models.dart';
import 'maintenance_source.dart';
import 'maintenance_viewmodel.dart';

/// Maintenance requests tenants raised from the tenant app: start work,
/// leave a note they see, mark fixed.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, this.source, this.uid, this.clock});

  /// Test hooks.
  final MaintenanceSource? source;
  final String? uid;
  final DateTime Function()? clock;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late final BusinessStateProvider _state = context.read<BusinessStateProvider>();
  late final MaintenanceViewModel _vm = MaintenanceViewModel(
    source: widget.source ?? _sourceFrom(context),
    businessId: _state.businessId ?? '',
    uid: widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '',
    scope: () => _state.propertyScope,
  );

  static MaintenanceSource _sourceFrom(BuildContext context) {
    try {
      return context.read<MaintenanceSource>();
    } on ProviderNotFoundException {
      return FirestoreMaintenanceSource();
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _resolve(MaintenanceItem m) async {
    final note = await showBizTextPrompt(
      context,
      title: 'Mark as fixed?',
      message: '${m.tenantName.isEmpty ? 'The tenant' : m.tenantName} gets a notification. Add a note if it helps.',
      hint: 'Replaced the capacitor',
      confirmLabel: 'Mark fixed',
      required: false,
    );
    if (note == null) return;
    if (await _vm.resolve(m, note: note) && mounted) showBizToast(context, 'Marked as fixed', tone: BizTone.success);
  }

  Future<void> _note(MaintenanceItem m) async {
    final note = await showBizTextPrompt(
      context,
      title: 'Note for the tenant',
      hint: 'Electrician coming at 5 pm',
      confirmLabel: 'Save note',
    );
    if (note == null) return;
    if (await _vm.addNote(m, note) && mounted) showBizToast(context, 'Note saved');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final list = _vm.visible;
        return BizScaffold(
          title: 'Maintenance',
          eyebrow: 'Requests from tenants',
          belowHeader: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BizFilterChips(
              chips: [
                BizChipData('To do', count: _vm.activeCount),
                BizChipData('Done', count: _vm.doneCount),
              ],
              selectedIndex: _vm.filter.index,
              onSelected: (i) => _vm.setFilter(MaintenanceFilter.values[i]),
            ),
          ),
          body: _vm.loading
              ? const Padding(padding: EdgeInsets.all(16), child: BizSkeletonList(count: 3, cardHeight: 120))
              : _vm.loadError != null
                  ? BizErrorState(message: _vm.loadError!)
                  : list.isEmpty
                      ? BizEmptyState(
                          icon: _vm.filter == MaintenanceFilter.active ? Icons.handyman_outlined : Icons.history_rounded,
                          title: _vm.filter == MaintenanceFilter.active ? 'Nothing to fix' : 'Nothing done yet',
                          message: _vm.filter == MaintenanceFilter.active
                              ? 'When tenants report a problem in the tenant app, it shows up here.'
                              : 'Fixed and cancelled requests show up here.',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            if (_vm.error != null) ...[
                              BizBanner(message: _vm.error!, tone: BizTone.danger),
                              const SizedBox(height: 12),
                            ],
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _Card(
                                item: list[i],
                                busy: _vm.isBusy(list[i].id),
                                now: (widget.clock ?? DateTime.now)(),
                                onStart: () => _vm.start(list[i]),
                                onResolve: () => _resolve(list[i]),
                                onNote: () => _note(list[i]),
                              ),
                            ],
                          ],
                        ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.item,
    required this.busy,
    required this.now,
    required this.onStart,
    required this.onResolve,
    required this.onNote,
  });

  final MaintenanceItem item;
  final bool busy;
  final DateTime now;
  final VoidCallback onStart;
  final VoidCallback onResolve;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final m = item;
    final tone = switch (m.status) {
      MaintenanceState.open => BizTone.warning,
      MaintenanceState.inProgress => BizTone.info,
      MaintenanceState.resolved => BizTone.success,
      MaintenanceState.cancelled => BizTone.neutral,
    };
    return BizCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BizIconTile(icon: m.icon, color: m.urgent ? BizColors.badge : BizColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: BizText.rowTitle),
                    Text(
                      [m.categoryLabel, if (m.urgent) 'Urgent', if (m.createdAt != null) agoLabel(m.createdAt!, now)].join(' · '),
                      style: BizText.rowSubtitle,
                    ),
                  ],
                ),
              ),
              BizStatusPill(m.status.label, tone: tone),
            ],
          ),
          if (m.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(m.description, style: BizText.body.copyWith(color: BizColors.inkSoft)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: BizColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [if (m.tenantName.isNotEmpty) m.tenantName, if (m.where.isNotEmpty) m.where].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BizText.caption,
                ),
              ),
              if (m.tenantPhone.isNotEmpty)
                IconButton(
                  tooltip: 'Call ${m.tenantName}',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.call_rounded, size: 20, color: BizColors.green),
                  onPressed: () => dialPhone(context, m.tenantPhone),
                ),
            ],
          ),
          if (m.ownerNote != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: BizColors.page, borderRadius: BorderRadius.circular(12)),
              child: Text('Your note: ${m.ownerNote}', style: BizText.style(14, 500)),
            ),
          ],
          if (m.status.isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BizButton(
                    label: 'Note',
                    icon: Icons.edit_note_rounded,
                    kind: BizButtonKind.tonal,
                    size: BizButtonSize.compact,
                    onPressed: busy ? null : onNote,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: m.status == MaintenanceState.open
                      ? BizButton(
                          label: 'Start work',
                          size: BizButtonSize.compact,
                          loading: busy,
                          onPressed: onStart,
                        )
                      : BizButton(
                          label: 'Mark fixed',
                          icon: Icons.check_rounded,
                          size: BizButtonSize.compact,
                          loading: busy,
                          onPressed: onResolve,
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
