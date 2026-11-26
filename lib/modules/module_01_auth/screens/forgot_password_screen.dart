import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:flutter/services.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/utils/validators.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/auth_widgets.dart';
import 'package:agrisphere/modules/module_01_auth/screens/reset_password_screen.dart';

/// Step 1 of "Forgot password": ask for the email and send a 6-digit code.
class ForgotPasswordScreen extends StatefulWidget {
  final String email;
  const ForgotPasswordScreen({super.key, this.email = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(msg))));
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _emailCtrl.text.trim().toLowerCase();
    final res = await ApiService.instance.forgotPassword(email);
    if (!mounted) return;
    setState(() => _loading = false);
    _toast(res.message);
    if (res.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr('Forgot password?'),
      subtitle: tr('Enter your email and we will send you a 6-digit reset code.'),
      child: Form(
        key: _formKey,
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
            const SizedBox(height: 20),
            PrimaryButton(
              label: tr('Send reset code'),
              icon: Icons.send_outlined,
              loading: _loading,
              onPressed: _send,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: Text(tr('Back to login')),
            ),
          ],
        ),
      ),
    );
  }
}
