// lib/presentation/profile/my_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/business_state_provider.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_text_field.dart';
import 'my_details_source.dart';
import 'my_details_viewmodel.dart';

/// "Edit my details". Pops with `true` once saved.
class MyDetailsScreen extends StatefulWidget {
  const MyDetailsScreen({
    super.key,
    required this.businessId,
    required this.uid,
    required this.role,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.source,
    this.reloadSession,
  });

  final String businessId;
  final String uid;
  final String role;
  final String name;
  final String email;
  final String phone;

  /// Test hooks. Defaults use Firestore and the signed-in session.
  final MyDetailsSource? source;
  final Future<void> Function()? reloadSession;

  @override
  State<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

class _MyDetailsScreenState extends State<MyDetailsScreen> {
  late final MyDetailsViewModel _vm = MyDetailsViewModel(
    source: widget.source ?? FirestoreMyDetailsSource(),
    businessId: widget.businessId,
    uid: widget.uid,
    name: widget.name,
    email: widget.email,
    phone: widget.phone,
    reloadSession: widget.reloadSession ?? () => context.read<BusinessStateProvider>().loadUserData(),
  );
  late final _name = TextEditingController(text: widget.name);
  late final _email = TextEditingController(text: widget.email);
  late final _phone = TextEditingController(text: widget.phone);

  @override
  void dispose() {
    _vm.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (await _vm.submit() && mounted) {
      showBizToast(context, 'Details saved.', tone: BizTone.success);
      Navigator.of(context).pop(true);
    }
  }

  String get _roleLabel => switch (widget.role) {
        'owner' => 'Owner',
        'manager' => 'Manager',
        _ => 'Staff',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => BizScaffold(
        title: 'My details',
        eyebrow: _roleLabel,
        bottomBar: BizButton(
          label: 'Save changes',
          loading: _vm.busy,
          onPressed: _vm.isDirty && !_vm.busy ? _save : null,
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (_vm.error != null) ...[
              BizBanner(message: _vm.error!, tone: BizTone.danger),
              const SizedBox(height: 14),
            ],
            BizCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BizTextField(
                    label: 'Name',
                    fieldKey: const Key('my-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    enabled: !_vm.busy,
                    onChanged: _vm.setName,
                    errorText: _vm.nameError,
                    helper: 'Shown on Home and to your team.',
                  ),
                  const SizedBox(height: 14),
                  BizTextField(
                    label: 'Email (optional)',
                    fieldKey: const Key('my-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_vm.busy,
                    onChanged: _vm.setEmail,
                    errorText: _vm.emailError,
                  ),
                  const SizedBox(height: 14),
                  BizTextField(
                    label: 'Phone (optional)',
                    fieldKey: const Key('my-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    enabled: !_vm.busy,
                    onChanged: _vm.setPhone,
                    errorText: _vm.phoneError,
                    helper: "For your team to reach you. It doesn't change the number you sign in with.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
