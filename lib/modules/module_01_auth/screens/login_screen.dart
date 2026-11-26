import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:flutter/services.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/core/utils/validators.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/auth_widgets.dart';
import 'package:agrisphere/modules/module_01_auth/screens/forgot_password_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/role_gate_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/role_picker_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/role_selection_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Pre-filled after a password reset.
  final String? email;
  const LoginScreen({super.key, this.email});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _passCtrl = TextEditingController();
  bool _remember = true;
  bool _hidePass = true;
  bool _loading = false;
  bool _gLoading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.email ?? '');
    ApiService.instance.remembered().then((v) {
      if (mounted) setState(() => _remember = v);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(msg))));
  }

  /// One role goes straight home; several roles ask "continue as ...?" first.
  Future<void> _enter(Map<String, dynamic>? d) async {
    await ApiService.instance.setRemember(_remember);
    if (!mounted) return;
    final roles = (d?['roles'] as List?) ?? const [];
    final next = roles.length > 1
        ? const RolePickerScreen()
        : const RoleGateScreen();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _emailCtrl.text.trim().toLowerCase();
    final res = await ApiService.instance.login(
      email: email,
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.success) {
      await _enter(res.data);
    } else if (res.data?['needsVerification'] == true) {
      _toast(res.message);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
      );
    } else {
      _toast(res.message);
    }
  }

  Future<void> _google() async {
    setState(() => _gLoading = true);
    final res = await ApiService.instance.googleSignIn(signup: false);
    if (!mounted) return;
    setState(() => _gLoading = false);
    if (res.success) {
      await _enter(res.data);
    } else if (res.data?['noAccount'] == true) {
      _toast(res.message);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
    } else {
      _toast(res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('Welcome back \u{1F44B}'),
      subtitle: tr('Sign in to manage your farm, machinery, storage and orders.'),
      footer: AuthFooterLink(
        text: tr('New to AgriSphere?'),
        action: 'Create account',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        ),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            AppTextField(
              label: tr('Email'),
              hint: tr('ali.khan@email.com'),
              icon: Icons.mail_outline,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: tr('Password'),
              hint: tr('Enter password'),
              icon: Icons.lock_outline,
              controller: _passCtrl,
              obscure: _hidePass,
              suffix: IconButton(
                icon: Icon(
                  _hidePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _hidePass = !_hidePass),
              ),
              validator: Validators.loginPassword,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _remember,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _remember = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('Remember me'),
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(
                        email: _emailCtrl.text.trim(),
                      ),
                    ),
                  ),
                  child: Text(
                    tr('Forgot password?'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: tr('Login'),
              icon: Icons.lock_outline,
              loading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 16),
            OrDivider(text: tr('or continue with')),
            const SizedBox(height: 14),
            SocialButton(
              label: tr('Continue with Google'),
              icon: Icons.g_mobiledata,
              loading: _gLoading,
              onTap: _google,
            ),
          ],
        ),
      ),
    );
  }
}
