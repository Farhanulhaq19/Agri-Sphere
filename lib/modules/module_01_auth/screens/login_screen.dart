import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../widgets/auth_widgets.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _remember = true;
  bool _hidePass = true;
  bool _loading = false;
  bool _gLoading = false;

  @override
  void dispose() {
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
          role: (d?['role'] ?? 'Farmer').toString(),
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _emailCtrl.text.trim().toLowerCase();
    final res = await ApiService.instance.login(email: email, password: _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.success) {
      _openProfile(res.data);
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
      _openProfile(res.data);
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
      title: 'Welcome back \u{1F44B}',
      subtitle: 'Sign in to manage your farm, orders and consultations.',
      footer: AuthFooterLink(
        text: 'New to AgriSphere?',
        action: 'Create account',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(
              label: 'Email',
              hint: 'ali.khan@email.com',
              icon: Icons.mail_outline,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Password',
              hint: 'Enter password',
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
                const Text('Remember me',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                const Spacer(),
                TextButton(
                  onPressed: () => _toast('Password reset coming soon'),
                  child: const Text(
                    'Forgot password?',
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
              label: 'Login',
              icon: Icons.lock_outline,
              loading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 16),
            const OrDivider(text: 'or continue with'),
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