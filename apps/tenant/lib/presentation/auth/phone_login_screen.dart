// lib/presentation/auth/phone_login_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/components/app_banner.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_text_field.dart';
import '../design/tokens.dart';
import 'phone_login_viewmodel.dart';

/// Sign in with a phone number and a text-message code.
///
/// Pops with `true` when [returnToCaller] (the invitation flow continues once
/// the phone is verified); otherwise it just uncovers the auth gate, which
/// has already noticed the new user.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    this.initialPhone,
    this.returnToCaller = false,
    this.lockPhone = false,
    this.actions,
    this.clock,
  });

  final String? initialPhone;
  final bool returnToCaller;

  /// The number is fixed (an invitation was sent to it), not editable.
  final bool lockPhone;

  /// Test hooks.
  final PhoneAuthActions? actions;
  final DateTime Function()? clock;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  late final PhoneLoginViewModel _vm = PhoneLoginViewModel(
    actions: widget.actions ?? FirebasePhoneAuthActions(),
    initialPhone: widget.initialPhone,
    clock: widget.clock,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone ?? '',
  );
  final _code = TextEditingController();
  Timer? _tick;
  bool _left = false;

  /// The countdown as last painted, so the tick repaints exactly when it changes.
  int _shownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onChanged);
    // The resend countdown is derived from the clock; this just repaints it.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          _vm.step == PhoneStep.code &&
          _vm.secondsUntilResend != _shownSeconds) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _vm.removeListener(_onChanged);
    _vm.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_vm.signedIn && !_left && mounted) {
      _left = true;
      final nav = Navigator.of(context);
      if (widget.returnToCaller) {
        nav.pop(true);
      } else {
        nav.popUntil((route) => route.isFirst);
      }
    }
    if (_code.text != _vm.code) _code.text = _vm.code;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => AppScaffold(
        title: 'Sign in with phone',
        eyebrow: widget.returnToCaller ? 'Your invitation' : 'OneStay360',
        showBack: true,
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (_vm.error != null) ...[
              AppBanner(message: _vm.error!, tone: AppTone.danger),
              const SizedBox(height: 14),
            ],
            AppCard(
              padding: const EdgeInsets.all(18),
              child: _vm.step == PhoneStep.number ? _numberStep() : _codeStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.lockPhone
              ? 'Your PG owner invited this number. We will text it a code to confirm it is you.'
              : "We'll text you a 6-digit code to sign in. New here? We'll create your account.",
          style: AppText.rowSubtitle.copyWith(fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Mobile number',
          fieldKey: const Key('phone-number'),
          controller: _phone,
          hint: '98111 00001',
          keyboardType: TextInputType.phone,
          enabled: !widget.lockPhone && !_vm.busy,
          readOnly: widget.lockPhone,
          onChanged: _vm.setPhone,
          errorText: _vm.phoneError,
          autofocus: !widget.lockPhone,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Send code',
          loading: _vm.busy,
          onPressed: _vm.busy ? null : _vm.sendCode,
        ),
      ],
    );
  }

  Widget _codeStep() {
    final seconds = _shownSeconds = _vm.secondsUntilResend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter the code', style: AppText.cardTitle),
        const SizedBox(height: 4),
        Text(
          'We texted a 6-digit code to ${_vm.maskedPhone}.',
          style: AppText.rowSubtitle.copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('phone-code'),
          controller: _code,
          autofocus: true,
          enabled: !_vm.busy,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: AppText.style(28, 700, letterSpacing: 10),
          cursorColor: AppColors.green,
          onChanged: (v) {
            _vm.setCode(v);
            if (_vm.code.length == 6) _vm.verify();
          },
          decoration: InputDecoration(
            hintText: '••••••',
            hintStyle: AppText.style(
              28,
              700,
              color: AppColors.chevron,
              letterSpacing: 10,
            ),
            counterText: '',
            errorText: _vm.codeError,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: _border(AppColors.fieldBorder),
            disabledBorder: _border(AppColors.fieldBorder),
            focusedBorder: _border(AppColors.green, width: 1.6),
            errorBorder: _border(AppColors.badge),
            focusedErrorBorder: _border(AppColors.badge, width: 1.6),
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Verify',
          loading: _vm.busy,
          onPressed: _vm.busy ? null : _vm.verify,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!widget.lockPhone)
              TextButton(
                key: const Key('phone-change'),
                onPressed: _vm.busy ? null : _vm.changeNumber,
                child: Text('Change number', style: AppText.link),
              )
            else
              const SizedBox.shrink(),
            TextButton(
              key: const Key('phone-resend'),
              onPressed: _vm.canResend ? _vm.resend : null,
              child: Text(
                seconds > 0
                    ? 'Resend in 0:${seconds.toString().padLeft(2, '0')}'
                    : 'Resend code',
                style: AppText.link.copyWith(
                  color: _vm.canResend ? AppColors.green : AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );
}
