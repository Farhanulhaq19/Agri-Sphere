import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/utils/validators.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/auth_widgets.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/password_strength.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _hide = true;
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final res = await ApiService.instance.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    if (res.success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
      onPressed: () => setState(() => _hide = !_hide),
    );
    return AuthScaffold(
      title: tr('Change password'),
      subtitle: tr('Use at least 8 characters with a number.'),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(
              label: tr('Current password'),
              hint: tr('Your current password'),
              icon: Icons.lock_outline,
              controller: _currentCtrl,
              obscure: _hide,
              suffix: eye,
              validator: Validators.loginPassword,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: tr('New password'),
              hint: tr('New password'),
              icon: Icons.lock_reset,
              controller: _newCtrl,
              obscure: _hide,
              validator: Validators.newPassword,
            ),
            AnimatedBuilder(
              animation: _newCtrl,
              builder: (context, child) => PasswordStrength(_newCtrl.text),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: tr('Confirm new password'),
              hint: tr('Type it again'),
              icon: Icons.lock_reset,
              controller: _confirmCtrl,
              obscure: _hide,
              validator: Validators.sameAs(() => _newCtrl.text),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: tr('Save new password'),
              icon: Icons.check,
              loading: _loading,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
