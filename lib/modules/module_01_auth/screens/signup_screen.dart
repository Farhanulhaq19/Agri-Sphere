import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'verify_email_screen.dart';

class SignupScreen extends StatefulWidget {
  final String role;
  const SignupScreen({super.key, this.role = 'Farmer'});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _agree = true;
  bool _hidePass = true;
  bool _loading = false;
  bool _gLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openProfile(Map<String, dynamic>? d) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          name: (d?['name'] ?? 'User').toString(),
          role: (d?['role'] ?? widget.role).toString(),
        ),
      ),
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
      role: widget.role,
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
    final res = await ApiService.instance.googleSignIn(signup: true, role: widget.role);
    if (!mounted) return;
    setState(() => _gLoading = false);
    if (res.success) {
      _openProfile(res.data);
    } else {
      _toast(res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Join AgriSphere in less than a minute.',
      footer: AuthFooterLink(
        text: 'Already registered?',
        action: 'Login',
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      ),
      child: Form(
        key: _formKey,
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
                  const Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Registering as ',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  Text(roleDisplay(widget.role),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Change',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Full name',
              hint: 'Ali Khan',
              icon: Icons.person_outline,
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\p{L} ]', unicode: true)),
                LengthLimitingTextInputFormatter(50),
              ],
              validator: Validators.name,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Email',
              hint: 'ali.khan@email.com',
              icon: Icons.mail_outline,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Password',
              hint: 'Min. 8 characters',
              icon: Icons.lock_outline,
              controller: _passCtrl,
              obscure: _hidePass,
              suffix: IconButton(
                icon: Icon(
                  _hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _hidePass = !_hidePass),
              ),
              validator: Validators.newPassword,
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
                const Expanded(
                  child: Text(
                    'I agree to the Terms of Service and Privacy Policy',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Create account',
              icon: Icons.chevron_right,
              loading: _loading,
              onPressed: _signup,
            ),
            const SizedBox(height: 16),
            const OrDivider(text: 'or sign up with'),
            const SizedBox(height: 14),
            SocialButton(
              label: 'Continue with Google',
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