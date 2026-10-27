// lib/presentation/maintenance/maintenance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../common/format.dart';
import '../design/components/app_banner.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_list_row.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_states.dart';
import '../design/components/app_text_field.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../home/activity_feed.dart';
import 'maintenance_form.dart';

/// Maintenance requests: what is open, what was fixed, and raising a new one.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, this.startNew = false});

  /// Open the "new request" sheet straight away.
  final bool startNew;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.startNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showRaiseMaintenanceSheet(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityFeed>();
    final hasStay = context.select<TenantSession, bool>((s) => s.hasStay);
    final active = activity.maintenance.where((m) => m.status.isActive).toList();
    final past = activity.maintenance.where((m) => !m.status.isActive).toList();
    final list = _tab == 0 ? active : past;

    return AppScaffold(
      title: 'Maintenance',
      eyebrow: 'Requests to your owner',
      bottomBar: hasStay
          ? AppButton(label: 'New request', icon: Icons.add_rounded, onPressed: () => showRaiseMaintenanceSheet(context))
          : null,
      belowHeader: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppFilterChips(
          chips: [AppChipData('Open', count: active.length), AppChipData('Past', count: past.length)],
          selectedIndex: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
      ),
      body: SmoothSwitch(
        child: list.isEmpty
            ? AppEmptyState(
                key: ValueKey('empty$_tab'),
                icon: _tab == 0 ? Icons.handyman_outlined : Icons.history_rounded,
                title: _tab == 0 ? 'Nothing needs fixing' : 'No past requests',
                message: _tab == 0
                    ? (hasStay
                        ? 'Something broken or not working? Tell your owner here and follow it until it is fixed.'
                        : 'You can raise requests once you live in a PG.')
                    : 'Fixed and cancelled requests show up here.',
              )
            : ListView.separated(
                key: ValueKey('list$_tab'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                physics: const BouncingScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => EntranceFade(
                  delay: Duration(milliseconds: i < 8 ? 40 * i : 0),
                  child: _RequestCard(request: list[i]),
                ),
              ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final MaintenanceRequest request;

  Future<void> _cancel(BuildContext context) async {
    final ok = await showAppConfirm(
      context,
      title: 'Cancel this request?',
      message: 'Your owner will see it as cancelled.',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<TenantBackend>().cancelMaintenance(request.id);
      if (context.mounted) showAppToast(context, 'Request cancelled');
    } catch (_) {
      if (context.mounted) showAppToast(context, "Couldn't cancel it. Try again.", tone: AppTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = request;
    final tone = switch (m.status) {
      MaintenanceStatus.open => AppTone.warning,
      MaintenanceStatus.inProgress => AppTone.info,
      MaintenanceStatus.resolved => AppTone.success,
      MaintenanceStatus.cancelled => AppTone.neutral,
    };
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconTile(icon: m.category.icon, color: m.urgent ? AppColors.badge : AppColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: AppText.rowTitle),
                    Text(
                      [m.category.label, if (m.urgent) 'Urgent', if (m.createdAt != null) agoLabel(m.createdAt!, DateTime.now())]
                          .join(' · '),
                      style: AppText.rowSubtitle,
                    ),
                  ],
                ),
              ),
              AppStatusPill(m.status.label, tone: tone),
            ],
          ),
          if (m.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(m.description, style: AppText.body.copyWith(color: AppColors.inkSoft)),
          ],
          if (m.ownerNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.page, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.forum_rounded, size: 18, color: AppColors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Owner: ${m.ownerNote}', style: AppText.style(14, 500))),
                ],
              ),
            ),
          ],
          if (m.canCancel) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _cancel(context), child: const Text('Cancel request')),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showRaiseMaintenanceSheet(BuildContext context) async {
  final session = context.read<TenantSession>();
  final stay = session.stay;
  final account = session.account;
  if (stay == null || account == null) {
    showAppToast(context, 'You can raise requests once you live in a PG.');
    return;
  }
  final form = MaintenanceForm(source: context.read<TenantBackend>(), account: account, stay: stay);
  final title = TextEditingController();
  final sent = await showAppSheet<bool>(
    context,
    title: 'New request',
    subtitle: '${stay.propertyName} · ${stay.roomLabel}',
    builder: (ctx) => ListenableBuilder(
      listenable: form,
      builder: (ctx, _) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (form.error != null) ...[
              AppBanner(message: form.error!, tone: AppTone.danger),
              const SizedBox(height: 12),
            ],
            Text('What is it about?', style: AppText.fieldLabel),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
              children: [
                for (final c in MaintenanceCategory.values)
                  Pressable(
                    scale: 0.94,
                    semanticLabel: c.label,
                    onTap: () => form.setCategory(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: form.category == c ? AppColors.greenTint : AppColors.page,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: form.category == c ? AppColors.green : Colors.transparent, width: 1.6),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(c.icon, color: form.category == c ? AppColors.green : AppColors.ink, size: 22),
                          const SizedBox(height: 6),
                          Text(c.label, style: AppText.style(12, 600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (form.categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(form.categoryError!, style: AppText.caption.copyWith(color: AppColors.dangerInk)),
              ),
            if (form.suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in form.suggestions)
                    ActionChip(
                      label: Text(s),
                      onPressed: () {
                        title.text = s;
                        form.setTitle(s);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(
              label: 'Title',
              fieldKey: const Key('maintenance-title'),
              controller: title,
              hint: 'Fan not working',
              maxLength: MaintenanceForm.maxTitle,
              textCapitalization: TextCapitalization.sentences,
              onChanged: form.setTitle,
              errorText: form.titleError,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Details (optional)',
              fieldKey: const Key('maintenance-details'),
              hint: 'Where it is, since when, anything that helps',
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: form.setDescription,
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              value: form.urgent,
              onChanged: form.setUrgent,
              title: Text('Urgent', style: AppText.rowTitle),
              subtitle: Text('Water leak, no power, safety issue', style: AppText.rowSubtitle),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Send to owner',
              icon: Icons.send_rounded,
              loading: form.busy,
              onPressed: () async {
                if (await form.submit() && ctx.mounted) Navigator.of(ctx).pop(true);
              },
            ),
          ],
        ),
      ),
    ),
  );
  form.dispose();
  WidgetsBinding.instance.addPostFrameCallback((_) => title.dispose());
  if (sent == true && context.mounted) showAppToast(context, 'Sent to your owner', tone: AppTone.success);
}
