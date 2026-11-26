import 'dart:async';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/core/utils/validators.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/auth_widgets.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/password_strength.dart';
import 'package:agrisphere/modules/module_01_auth/screens/login_screen.dart';

/// Step 2 of "Forgot password": enter the code and choose a new password.
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  Timer? _timer;
  int _seconds = 30;
  bool _hide = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_seconds <= 1) {
        t.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(msg))));
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    final res = await ApiService.instance.forgotPassword(widget.email);
    if (!mounted) return;
    _toast(res.message);
    if (res.success) {
      setState(() => _seconds = 30);
      _tick();
    }
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final res = await ApiService.instance.resetPassword(
      email: widget.email,
      code: _codeCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    _toast(res.message);
    if (res.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(email: widget.email)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mm = '00:${_seconds.toString().padLeft(2, '0')}';
    return AuthScaffold(
      title: tr('Reset password'),
      subtitle: 'Enter the code sent to ${widget.email} and a new password.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(
              label: tr('6-digit code'),
              hint: tr('123456'),
              icon: Icons.pin_outlined,
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (v) =>
                  (v ?? '').trim().length == 6 ? null : 'Enter the 6-digit code',
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: tr('New password'),
              hint: tr('Min. 8 characters, with a number'),
              icon: Icons.lock_outline,
              controller: _passCtrl,
              obscure: _hide,
              suffix: IconButton(
                icon: Icon(
                  _hide
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _hide = !_hide),
              ),
              validator: Validators.newPassword,
            ),
            AnimatedBuilder(
              animation: _passCtrl,
              builder: (context, child) => PasswordStrength(_passCtrl.text),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: tr('Confirm new password'),
              hint: tr('Type it again'),
              icon: Icons.lock_outline,
              controller: _confirmCtrl,
              obscure: _hide,
              validator: Validators.sameAs(() => _passCtrl.text),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't get a code?",
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _seconds == 0 ? _resend : null,
                  child: Text(
                    _seconds == 0 ? 'Resend now' : 'Resend in $mm',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          _seconds == 0 ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: tr('Update password'),
              icon: Icons.check,
              loading: _loading,
              onPressed: _reset,
            ),
          ],
        ),
      ),
    );
  }
}
