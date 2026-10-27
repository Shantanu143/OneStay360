// lib/presentation/pinboard/pinboard_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../common/device_actions.dart';
import '../common/format.dart';
import '../common/widgets.dart';
import '../design/components/app_button.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_text_field.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'pin_form.dart';

/// The house pinboard: 48-hour notes everyone at the property sees.
class PinboardSection extends StatefulWidget {
  const PinboardSection({super.key, required this.propertyId});

  final String propertyId;

  @override
  State<PinboardSection> createState() => _PinboardSectionState();
}

class _PinboardSectionState extends State<PinboardSection> {
  late Stream<List<PinNote>> _pins = context.read<TenantBackend>().watchPins(widget.propertyId);

  @override
  void didUpdateWidget(PinboardSection old) {
    super.didUpdateWidget(old);
    if (old.propertyId != widget.propertyId) {
      _pins = context.read<TenantBackend>().watchPins(widget.propertyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('House pinboard', action: 'Pin a note', onAction: () => showAddPinSheet(context, widget.propertyId)),
        StreamBuilder<List<PinNote>>(
          stream: _pins,
          builder: (context, snap) {
            final notes = snap.data ?? const <PinNote>[];
            return SmoothSwitch(
              child: !snap.hasData && !snap.hasError
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 132,
                      child: Row(children: [
                        Skeleton.onLight(width: 220, height: 132, radius: AppRadius.card),
                        SizedBox(width: 12),
                        Skeleton.onLight(width: 110, height: 132, radius: AppRadius.card),
                      ]),
                    )
                  : notes.isEmpty
                      ? _Empty(key: const ValueKey('empty'), onPin: () => showAddPinSheet(context, widget.propertyId))
                      : SizedBox(
                          key: const ValueKey('notes'),
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            physics: const BouncingScrollPhysics(),
                            itemCount: notes.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (_, i) => _NoteCard(note: notes[i]),
                          ),
                        ),
            );
          },
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.onPin});

  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPin,
      scale: 0.98,
      semanticLabel: 'Pin a note',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Row(
          children: [
            const Text('📌', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nothing pinned yet', style: AppText.rowTitle),
                  Text('Plan a match, sell a cycle or find lost keys.', style: AppText.rowSubtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _tint(PinCategory c) => switch (c) {
      PinCategory.social => const Color(0xFFFFF4DB),
      PinCategory.sports => const Color(0xFFE3F0FF),
      PinCategory.lostFound => const Color(0xFFF1E8FF),
      PinCategory.marketplace => AppColors.greenTint,
    };

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final PinNote note;

  @override
  Widget build(BuildContext context) {
    final mine = note.authorId == context.read<TenantSession>().uid;
    return Pressable(
      scale: 0.97,
      semanticLabel: note.content,
      onTap: () => _openNote(context, note, mine),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _tint(note.category), borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(note.category.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(note.category.label, style: AppText.style(12, 700, color: AppColors.inkSoft)),
                const Spacer(),
                if (note.createdAt != null) Text(agoLabel(note.createdAt!, DateTime.now()), style: AppText.caption),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(note.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.style(15, 500, height: 1.3)),
            ),
            Text(mine ? 'You' : note.authorName, style: AppText.style(12, 600, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

Future<void> _openNote(BuildContext context, PinNote note, bool mine) async {
  if (mine) {
    final ok = await showAppConfirm(
      context,
      title: 'Remove your note?',
      message: 'It will disappear from the pinboard for everyone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<TenantBackend>().deletePin(note.id);
      if (context.mounted) showAppToast(context, 'Note removed');
    } catch (_) {
      if (context.mounted) showAppToast(context, "Couldn't remove the note.", tone: AppTone.danger);
    }
    return;
  }
  if (note.authorPhone.isEmpty) {
    showAppToast(context, '${note.authorName} has not shared a number.');
    return;
  }
  await openWhatsApp(context, note.authorPhone, message: 'Hi ${note.authorName}, about your pinboard note: "${note.content}"');
}

Future<void> showAddPinSheet(BuildContext context, String propertyId) async {
  final account = context.read<TenantSession>().account;
  if (account == null) return;
  final form = PinForm(source: context.read<TenantBackend>(), account: account, propertyId: propertyId);
  final pinned = await showAppSheet<bool>(
    context,
    title: 'Pin a note',
    subtitle: 'Everyone in your PG sees it for 48 hours.',
    builder: (ctx) => ListenableBuilder(
      listenable: form,
      builder: (ctx, _) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppChoiceWrap<PinCategory>(
              options: PinCategory.values,
              selected: form.category,
              labelOf: (c) => '${c.emoji} ${c.label}',
              onChanged: form.setCategory,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Your note',
              fieldKey: const Key('pin-text'),
              hint: 'Anyone up for badminton at 7?',
              maxLines: 4,
              maxLength: PinForm.maxLength,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: form.setContent,
              errorText: form.error,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Pin it',
              icon: Icons.push_pin_rounded,
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
  if (pinned == true && context.mounted) showAppToast(context, 'Pinned for 48 hours', tone: AppTone.success);
}
