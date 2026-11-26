import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:flutter/services.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/core/utils/validators.dart';
import 'package:agrisphere/modules/module_01_auth/roles.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/auth_widgets.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/password_strength.dart';
import 'package:agrisphere/modules/module_01_auth/screens/login_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/role_gate_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/role_picker_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/verify_email_screen.dart';

class SignupScreen extends StatefulWidget {
  final List<String> roles;
  const SignupScreen({super.key, this.roles = const ['Farmer']});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _agree = true;
  bool _hidePass = true;
  bool _loading = false;
  bool _gLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(msg))));
  }

  void _afterGoogle(Map<String, dynamic>? d) {
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

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      _toast('Please accept the Terms of Service');
      return;
    }
    setState(() => _loading = true);
    final email = _emailCtrl.text.trim().toLowerCase();
    final res = await ApiService.instance.signup(
      name: Validators.cleanName(_nameCtrl.text),
      email: email,
      password: _passCtrl.text,
      roles: widget.roles,
      phone: _phoneCtrl.text.replaceAll(RegExp(r'[\s-]'), ''),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    _toast(res.message);
    if (res.success) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email)),
      );
    }
  }

  Future<void> _google() async {
    setState(() => _gLoading = true);
    final res = await ApiService.instance.googleSignIn(
      signup: true,
      roles: widget.roles,
    );
    if (!mounted) return;
    setState(() => _gLoading = false);
    if (res.success) {
      _afterGoogle(res.data);
    } else {
      _toast(res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('Create account'),
      subtitle: tr('Join AgriSphere in less than a minute.'),
      footer: AuthFooterLink(
        text: tr('Already registered?'),
        action: 'Login',
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.roles.map(roleName).join(' + '),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      tr('Change'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: tr('Full name'),
              hint: tr('Ali Khan'),
              icon: Icons.person_outline,
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[\p{L} ]', unicode: true),
                ),
                LengthLimitingTextInputFormatter(50),
              ],
              validator: Validators.name,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            AppTextField(
              label: tr('Phone (optional)'),
              hint: tr('03001234567'),
              icon: Icons.phone_outlined,
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]')),
                LengthLimitingTextInputFormatter(16),
              ],
              validator: Validators.phoneOptional,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: tr('Password'),
              hint: tr('Min. 8 characters, with a number'),
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
              validator: Validators.newPassword,
            ),
            AnimatedBuilder(
              animation: _passCtrl,
              builder: (context, child) => PasswordStrength(_passCtrl.text),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: tr('Confirm password'),
              hint: tr('Type the password again'),
              icon: Icons.lock_outline,
              controller: _confirmCtrl,
              obscure: _hidePass,
              validator: Validators.sameAs(() => _passCtrl.text),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agree,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('I agree to the Terms of Service and Privacy Policy'),
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: tr('Create account'),
              icon: Icons.chevron_right,
              loading: _loading,
              onPressed: _signup,
            ),
            const SizedBox(height: 16),
            OrDivider(text: tr('or sign up with')),
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
