// lib/presentation/profile/kyc_screen.dart
import 'package:flutter/material.dart';

import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/components/biz_text_field.dart';
import '../design/tokens.dart';
import 'firestore_kyc_source.dart';
import 'kyc_viewmodel.dart';

/// GSTIN, PAN, registered address and compliance documents (owner only).
class KycScreen extends StatefulWidget {
  const KycScreen({
    super.key,
    required this.businessId,
    this.source,
    this.picker,
  });

  final String businessId;
  final KycSource? source;
  final DocumentPicker? picker;

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  late final KycViewModel _vm;
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _address = TextEditingController();

  static const _documents = {
    'incorporation': 'Incorporation certificate',
    'gst': 'GST certificate',
  };

  @override
  void initState() {
    super.initState();
    _vm = KycViewModel(
      businessId: widget.businessId,
      source: widget.source ?? FirestoreKycSource(),
      picker: widget.picker ?? GalleryDocumentPicker(),
    );
    _load();
  }

  Future<void> _load() async {
    await _vm.load();
    if (!mounted) return;
    _gstin.text = _vm.kyc.gstin;
    _pan.text = _vm.kyc.pan;
    _address.text = _vm.kyc.address;
  }

  @override
  void dispose() {
    _gstin.dispose();
    _pan.dispose();
    _address.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (await _vm.save()) {
      if (!mounted) return;
      // Show the normalised values (upper case, trimmed).
      _gstin.text = _vm.kyc.gstin;
      _pan.text = _vm.kyc.pan;
      showBizToast(context, 'KYC details saved.', tone: BizTone.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
        return BizScaffold(
          title: 'KYC & documents',
          eyebrow: 'Business',
          showBack: true,
          bottomBar: _vm.loading
              ? null
              : BizButton(
                  label: 'Save',
                  loading: _vm.saving,
                  onPressed: _vm.saving ? null : _save,
                ),
          body: _vm.loading
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: BizSkeletonList(count: 2, cardHeight: 160),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (_vm.error != null) ...[
                      BizBanner(message: _vm.error!, tone: BizTone.danger),
                      const SizedBox(height: 12),
                    ],
                    BizCard(
                      child: Column(
                        children: [
                          BizTextField(
                            label: 'GSTIN',
                            fieldKey: const Key('gstin'),
                            controller: _gstin,
                            hint: '22ABCDE1234F1Z5',
                            errorText: _vm.gstinError,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: _vm.setGstin,
                          ),
                          const SizedBox(height: 14),
                          BizTextField(
                            label: 'PAN (company)',
                            fieldKey: const Key('pan'),
                            controller: _pan,
                            hint: 'ABCDE1234F',
                            errorText: _vm.panError,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: _vm.setPan,
                          ),
                          const SizedBox(height: 14),
                          BizTextField(
                            label: 'Registered address',
                            fieldKey: const Key('address'),
                            controller: _address,
                            maxLines: 3,
                            onChanged: _vm.setAddress,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const BizSectionLabel('Compliance documents'),
                    for (final entry in _documents.entries) ...[
                      _DocumentRow(
                        label: entry.value,
                        uploaded: _vm.hasDocument(entry.key),
                        busy: _vm.uploading == entry.key,
                        onTap: _vm.uploading != null
                            ? null
                            : () => _vm.upload(entry.key),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Upload a clear photo of each certificate. Only you can see them.',
                        style: BizText.caption,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.label,
    required this.uploaded,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool uploaded;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BizCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BizText.rowTitle),
                if (uploaded) ...[
                  const SizedBox(height: 6),
                  const BizStatusPill('Uploaded', tone: BizTone.success),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: BizButton(
              label: uploaded ? 'Replace' : 'Upload',
              kind: BizButtonKind.tonal,
              size: BizButtonSize.small,
              loading: busy,
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }
}
