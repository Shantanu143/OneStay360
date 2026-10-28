// lib/presentation/auth/login_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../common/device_actions.dart';
import '../design/components/biz_brand_logo.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_button.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_text_field.dart';
import '../design/tokens.dart';
import 'auth_actions.dart';
import 'login_viewmodel.dart';
import 'phone_login_screen.dart';

const termsUrl = 'https://onestay360.brandedpatil.in/terms';
const privacyUrl = 'https://onestay360.brandedpatil.in/privacy';

/// Where signed-out owners and staff arrive. Signing in only signs in: the
/// auth gate notices and swaps this screen for the app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth, this.onOpenPhone, this.onOpenUrl});

  /// Test hooks. Defaults use Firebase and the real phone screen.
  final AuthActions? auth;
  final VoidCallback? onOpenPhone;
  final void Function(BuildContext context, Uri uri)? onOpenUrl;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _vm = LoginViewModel(auth: widget.auth ?? FirebaseAuthActions());
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _vm.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _openPhone() {
    final custom = widget.onOpenPhone;
    if (custom != null) return custom();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhoneLoginScreen()));
  }

  void _openUrl(String url) {
    final custom = widget.onOpenUrl;
    final uri = Uri.parse(url);
    if (custom != null) return custom(context, uri);
    openExternal(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BizColors.page,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final signUp = _vm.isSignUp;
            final busy = _vm.busy;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 28, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BizBrandLogo(height: 52),
                  const SizedBox(height: 22),
                  Text(signUp ? 'Create your account' : 'Welcome back', style: BizText.pageTitle),
                  const SizedBox(height: 8),
                  Text(
                    signUp
                        ? 'Set up your business in a few minutes.'
                        : 'Sign in to manage your properties, tenants and rent.',
                    style: BizText.rowSubtitle.copyWith(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (_vm.message != null) ...[
                    BizBanner(
                      message: _vm.message!.text,
                      tone: _vm.message!.isError ? BizTone.danger : BizTone.success,
                    ),
                    const SizedBox(height: 14),
                  ],
                  BizCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BizTextField(
                          label: 'Email',
                          fieldKey: const Key('login-email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !busy,
                          onChanged: _vm.setEmail,
                          errorText: _vm.emailError,
                        ),
                        const SizedBox(height: 14),
                        BizTextField(
                          label: 'Password',
                          fieldKey: const Key('login-password'),
                          controller: _password,
                          obscureText: !_showPassword,
                          textInputAction: signUp ? TextInputAction.next : TextInputAction.done,
                          enabled: !busy,
                          onChanged: _vm.setPassword,
                          errorText: _vm.passwordError,
                          suffix: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            icon: Icon(
                              _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                              color: BizColors.inkSoft,
                            ),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        if (signUp) ...[
                          const SizedBox(height: 14),
                          BizTextField(
                            label: 'Confirm password',
                            fieldKey: const Key('login-confirm'),
                            controller: _confirm,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.done,
                            enabled: !busy,
                            onChanged: _vm.setConfirm,
                            errorText: _vm.confirmError,
                          ),
                        ] else
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key('login-forgot'),
                              onPressed: busy ? null : _vm.forgotPassword,
                              child: Text('Forgot password?', style: BizText.link),
                            ),
                          ),
                        const SizedBox(height: 10),
                        BizButton(
                          label: signUp ? 'Create account' : 'Sign in',
                          loading: busy,
                          onPressed: busy ? null : _vm.submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: BizColors.track, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: BizText.rowSubtitle),
                      ),
                      const Expanded(child: Divider(color: BizColors.track, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  BizButton(
                    label: 'Continue with phone',
                    icon: Icons.phone_iphone_rounded,
                    kind: BizButtonKind.outline,
                    onPressed: busy ? null : _openPhone,
                  ),
                  const SizedBox(height: 10),
                  BizButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata_rounded,
                    kind: BizButtonKind.outline,
                    onPressed: busy ? null : _vm.google,
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(signUp ? 'Already have an account?' : 'New to OneStay360?', style: BizText.rowSubtitle),
                        TextButton(
                          key: const Key('login-toggle'),
                          onPressed: busy
                              ? null
                              : () {
                                  _confirm.clear();
                                  _vm.toggleMode();
                                },
                          child: Text(signUp ? 'Sign in' : 'Create an account', style: BizText.link),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: BizText.caption.copyWith(height: 1.5),
                        children: [
                          const TextSpan(text: 'By continuing you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: BizText.caption.copyWith(color: BizColors.green, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()..onTap = () => _openUrl(termsUrl),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: BizText.caption.copyWith(color: BizColors.green, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()..onTap = () => _openUrl(privacyUrl),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
