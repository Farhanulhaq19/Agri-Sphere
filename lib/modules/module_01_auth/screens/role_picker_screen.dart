import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/modules/module_01_auth/roles.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/auth_widgets.dart';
import 'package:agrisphere/modules/module_01_auth/screens/role_gate_screen.dart';

/// Shown after login when the account has more than one role:
/// "Continue as Farmer / Machinery Owner / ...".
class RolePickerScreen extends StatefulWidget {
  const RolePickerScreen({super.key});

  @override
  State<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends State<RolePickerScreen> {
  AuthSession? _s;
  String? _busy;

  @override
  void initState() {
    super.initState();
    ApiService.instance.session().then((s) {
      if (!mounted) return;
      if (s == null || s.roles.length < 2) {
        _go();
      } else {
        setState(() => _s = s);
      }
    });
  }

  void _go() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  Future<void> _pick(String role) async {
    if (_busy != null) return;
    setState(() => _busy = role);
    final active = _s!.role;
    if (normalizeRole(active) == normalizeRole(role)) {
      _go();
      return;
    }
    final res = await ApiService.instance.switchRole(role);
    if (!mounted) return;
    if (res.success) {
      _go();
    } else {
      setState(() => _busy = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return AuthScaffold(
      title: tr('Continue as...'),
      subtitle: 'Hi ${s.name.split(' ').first}, pick how you want to use AgriSphere right now.',
      showBack: false,
      child: Column(
        children: s.roles.map((r) {
          final info = roleInfo(r);
          final isLast = normalizeRole(r) == normalizeRole(s.role);
          return GestureDetector(
            onTap: () => _pick(r),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLast ? AppColors.primary : AppColors.border,
                  width: isLast ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  RoleBadge(info.value, size: 58),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLast ? 'Last used' : info.desc,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _busy == info.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
