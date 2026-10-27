// lib/presentation/onboarding/create_business_screen.dart
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
import '../design/tokens.dart';
import 'create_business_viewmodel.dart';

/// First step for a new owner. Pops when the business exists; the auth gate
/// then loads it and shows the app.
class CreateBusinessScreen extends StatefulWidget {
  const CreateBusinessScreen({super.key, this.creator, this.reloadSession});

  /// Test hooks. Defaults use Firebase and the signed-in session.
  final BusinessCreator? creator;
  final Future<void> Function()? reloadSession;

  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  late final CreateBusinessViewModel _vm = CreateBusinessViewModel(
    creator: widget.creator ?? FirebaseBusinessCreator(),
    reloadSession: widget.reloadSession ?? () => context.read<BusinessStateProvider>().loadUserData(),
  );
  final _name = TextEditingController();

  @override
  void dispose() {
    _vm.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    if (await _vm.submit() && mounted) {
      showBizToast(context, 'Your business is ready.', tone: BizTone.success);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => BizScaffold(
        title: 'Set up your business',
        eyebrow: 'Welcome to OneStay360',
        bottomBar: BizButton(label: 'Create business', loading: _vm.busy, onPressed: _vm.busy ? null : _create),
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
                  Text(
                    "You'll be the owner. Add your PGs and invite managers next.",
                    style: BizText.rowSubtitle.copyWith(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  BizTextField(
                    label: 'Business name',
                    fieldKey: const Key('business-name'),
                    controller: _name,
                    hint: 'e.g. Sunrise Stays',
                    helper: 'Tenants and your team will see this name.',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    enabled: !_vm.busy,
                    autofocus: true,
                    onChanged: _vm.setName,
                    errorText: _vm.nameError,
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
