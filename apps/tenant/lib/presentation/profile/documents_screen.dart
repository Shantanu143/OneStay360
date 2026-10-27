// lib/presentation/profile/documents_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:models/tenant/tenant_document_model.dart';
import 'package:provider/provider.dart';

import '../../data/tenant_session.dart';
import '../common/device_actions.dart';
import '../common/format.dart';
import '../design/components/app_banner.dart';
import '../design/components/app_button.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_list_row.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_states.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'profile_viewmodel.dart';

String documentLabel(DocumentType t) => switch (t) {
      DocumentType.aadhar => 'Aadhaar card',
      DocumentType.pan => 'PAN card',
      DocumentType.rentalAgreement => 'Rental agreement',
      DocumentType.other => 'Other document',
    };

/// ID documents the owner can see: upload, view, delete.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.viewModel});

  final ProfileViewModel? viewModel;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late final ProfileViewModel _vm = widget.viewModel ??
      ProfileViewModel(
        firestore: FirebaseFirestore.instance,
        uid: context.read<TenantSession>().uid ?? '',
        email: context.read<TenantSession>().account?.email ?? '',
      );

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final type = await showAppSheet<DocumentType>(
      context,
      title: 'What are you uploading?',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final t in DocumentType.values)
            AppSheetOption(label: documentLabel(t), onTap: () => Navigator.of(ctx).pop(t)),
        ],
      ),
    );
    if (type == null || !mounted) return;
    final source = await showAppSheet<ImageSource>(
      context,
      title: documentLabel(type),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          AppSheetOption(label: 'Take a photo', onTap: () => Navigator.of(ctx).pop(ImageSource.camera)),
          AppSheetOption(label: 'Choose from gallery', onTap: () => Navigator.of(ctx).pop(ImageSource.gallery)),
        ],
      ),
    );
    if (source == null) return;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 2200);
    } catch (_) {
      if (mounted) showAppToast(context, "Couldn't open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.", tone: AppTone.danger);
      return;
    }
    if (file == null) return;
    if (await _vm.uploadDocument(type, file) && mounted) {
      showAppToast(context, '${documentLabel(type)} uploaded', tone: AppTone.success);
    }
  }

  Future<void> _delete(TenantDocument doc) async {
    final ok = await showAppConfirm(
      context,
      title: 'Delete ${documentLabel(doc.type).toLowerCase()}?',
      message: 'Your owner will no longer see it.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok && await _vm.deleteDocument(doc) && mounted) showAppToast(context, 'Deleted');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return AppScaffold(
          title: 'ID documents',
          eyebrow: 'Profile',
          bottomBar: _vm.canUploadDocuments
              ? AppButton(label: 'Upload a document', icon: Icons.upload_rounded, loading: _vm.uploading, onPressed: _upload)
              : null,
          body: SmoothSwitch(
            child: _vm.loading
                ? const Padding(key: ValueKey('loading'), padding: EdgeInsets.all(16), child: AppSkeletonList(count: 2, cardHeight: 96))
                : !_vm.canUploadDocuments
                    ? const AppEmptyState(
                        key: ValueKey('none'),
                        icon: Icons.folder_off_outlined,
                        title: 'Not available yet',
                        message: 'Finish setting up your account to upload documents.',
                      )
                    : _vm.documents.isEmpty
                        ? Column(
                            key: const ValueKey('empty'),
                            children: [
                              if (_vm.error != null)
                                Padding(padding: const EdgeInsets.all(16), child: AppBanner(message: _vm.error!, tone: AppTone.danger)),
                              const Expanded(
                                child: AppEmptyState(
                                  icon: Icons.badge_outlined,
                                  title: 'No documents yet',
                                  message: 'Owners usually ask for Aadhaar before move-in. Upload it once and you are set.',
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            key: const ValueKey('list'),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: [
                              if (_vm.error != null) ...[
                                AppBanner(message: _vm.error!, tone: AppTone.danger),
                                const SizedBox(height: 12),
                              ],
                              for (final d in _vm.documents) ...[
                                AppListRow(
                                  icon: d.type == DocumentType.rentalAgreement ? Icons.description_rounded : Icons.badge_rounded,
                                  color: AppColors.blue,
                                  title: documentLabel(d.type),
                                  subtitle: 'Uploaded ${formatDay(d.uploadedAt)}',
                                  onTap: () => openExternal(context, Uri.parse(d.documentUrl)),
                                  trailing: IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerInk),
                                    onPressed: () => _delete(d),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
          ),
        );
      },
    );
  }
}
