// lib/presentation/team/invite_sheet.dart
import 'package:flutter/material.dart';

import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_text_field.dart';
import '../design/tokens.dart';
import 'invite_form_viewmodel.dart';
import 'team_actions.dart';
import 'team_models.dart';
import 'team_viewmodel.dart';

/// Role words shown to the owner. Manager and staff can do the same things in
/// the app today, so one line describes both.
const roleHint = "Can add and update tenants and beds in the properties you choose. "
    "Billing, rooms and the team stay with you.";

/// The invite form, and once it is sent, the link to share.
class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key, required this.team, required this.actions});

  final TeamViewModel team;
  final TeamActions actions;

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  late final InviteFormViewModel _form = InviteFormViewModel(properties: widget.team.properties);
  final _phone = TextEditingController();
  final _email = TextEditingController();
  InviteResult? _sent;
  InviteRequest? _sentRequest;

  @override
  void dispose() {
    _form.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_form.validate()) return;
    final request = _form.build();
    final result = await widget.team.invite(request);
    if (!mounted || result == null) return;
    setState(() {
      _sent = result;
      _sentRequest = request;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sent;
    if (sent != null) return _Sent(result: sent, request: _sentRequest!, actions: widget.actions);

    return ListenableBuilder(
      listenable: Listenable.merge([_form, widget.team]),
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.team.inviteError != null) ...[
              BizBanner(message: widget.team.inviteError!, tone: BizTone.danger),
              const SizedBox(height: 14),
            ],
            BizTextField(
              label: 'Mobile number',
              fieldKey: const Key('invite-phone'),
              controller: _phone,
              hint: '98111 00001',
              keyboardType: TextInputType.phone,
              onChanged: _form.setPhone,
              errorText: _form.phoneError,
              helper: 'They sign in with this number.',
            ),
            const SizedBox(height: 14),
            BizTextField(
              label: 'Email (optional)',
              fieldKey: const Key('invite-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: _form.setEmail,
              errorText: _form.emailError,
            ),
            const SizedBox(height: 18),
            const BizSectionLabel('Role'),
            BizChoiceWrap<String>(
              options: InviteFormViewModel.roles,
              selected: _form.role,
              labelOf: (r) => r == 'manager' ? 'Manager' : 'Staff',
              onChanged: _form.setRole,
              onCard: true,
            ),
            const SizedBox(height: 8),
            Text(roleHint, style: BizText.rowSubtitle.copyWith(height: 1.4)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: BizSectionLabel('Properties')),
                if (widget.team.properties.length > 1)
                  GestureDetector(
                    key: const Key('invite-select-all'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _form.toggleAll,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 4, 5),
                      child: Text(_form.allSelected ? 'Clear all' : 'Select all', style: BizText.link),
                    ),
                  ),
              ],
            ),
            PropertyChecklist(
              properties: widget.team.properties,
              selected: _form.selected,
              onToggle: _form.toggleProperty,
            ),
            if (_form.propertiesError != null) ...[
              const SizedBox(height: 6),
              Text(_form.propertiesError!, style: BizText.caption.copyWith(color: BizColors.dangerInk)),
            ],
            const SizedBox(height: 20),
            BizButton(
              label: 'Send invitation',
              loading: widget.team.isInviting,
              onPressed: widget.team.isInviting ? null : _send,
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// "Invitation sent" with the link to copy or send on WhatsApp.
class _Sent extends StatelessWidget {
  const _Sent({required this.result, required this.request, required this.actions});

  final InviteResult result;
  final InviteRequest request;
  final TeamActions actions;

  @override
  Widget build(BuildContext context) {
    return InviteLinkPanel(
      heading: 'Invitation sent',
      detail: "We'll text the link to ${request.phone}${request.email == null ? '' : ' and email it to ${request.email}'}. "
          'You can also send it yourself.',
      phone: request.phone,
      link: result.link,
      actions: actions,
      onDone: () => Navigator.of(context).maybePop(),
    );
  }
}

/// A link with Copy and WhatsApp buttons; used right after inviting and for
/// invitations that are still waiting.
class InviteLinkPanel extends StatelessWidget {
  const InviteLinkPanel({
    super.key,
    required this.heading,
    required this.detail,
    required this.phone,
    required this.link,
    required this.actions,
    this.onDone,
  });

  final String heading;
  final String detail;
  final String phone;
  final String link;
  final TeamActions actions;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: BizText.sectionTitle),
        const SizedBox(height: 6),
        Text(detail, style: BizText.rowSubtitle.copyWith(height: 1.4)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BizColors.page,
            borderRadius: BorderRadius.circular(BizRadius.field),
          ),
          child: SelectableText(link, style: BizText.caption.copyWith(color: BizColors.ink)),
        ),
        const SizedBox(height: 14),
        BizButton(
          label: 'Share on WhatsApp',
          icon: Icons.share_rounded,
          onPressed: () => actions.openUrl(context, whatsappInviteLink(phone, link)),
        ),
        const SizedBox(height: 10),
        BizButton(
          label: 'Copy link',
          icon: Icons.copy_rounded,
          kind: BizButtonKind.outline,
          onPressed: () => actions.copy(context, link, message: 'Link copied'),
        ),
        if (onDone != null) ...[
          const SizedBox(height: 10),
          BizButton(label: 'Done', kind: BizButtonKind.ghost, onPressed: onDone),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Properties as tick rows.
class PropertyChecklist extends StatelessWidget {
  const PropertyChecklist({
    super.key,
    required this.properties,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
  });

  final List<TeamProperty> properties;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return Text('No properties yet.', style: BizText.rowSubtitle);
    }
    return Column(
      children: [
        for (final p in properties)
          _CheckRow(
            key: Key('property-${p.id}'),
            label: p.name,
            checked: selected.contains(p.id),
            onTap: enabled ? () => onToggle(p.id) : null,
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({super.key, required this.label, required this.checked, required this.onTap});

  final String label;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: checked ? BizColors.green : Colors.transparent,
                  border: Border.all(color: checked ? BizColors.green : BizColors.chevron, width: 1.6),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: checked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: BizText.rowTitle.copyWith(color: onTap == null ? BizColors.inkSoft : BizColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
