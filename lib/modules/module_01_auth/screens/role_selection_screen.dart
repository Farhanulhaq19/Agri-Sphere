import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/modules/module_01_auth/roles.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/auth_widgets.dart';
import 'package:agrisphere/modules/module_01_auth/screens/signup_screen.dart';

/// Pick one or more roles, for example Farmer + Machinery Owner.
/// You can add or switch roles later from the Account page.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final Set<String> _selected = {'Farmer'};

  void _toggle(String v) {
    setState(() {
      if (_selected.contains(v)) {
        if (_selected.length > 1) _selected.remove(v);
      } else {
        _selected.add(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = kRoles.where((r) => _selected.contains(r.value)).toList();
    return AuthScaffold(
      title: tr('Choose your roles'),
      subtitle:
          tr('Pick everything that applies. You can switch between roles any time.'),
      child: Column(
        children: [
          ...kRoles.map((r) {
            final sel = _selected.contains(r.value);
            return GestureDetector(
              onTap: () => _toggle(r.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border,
                    width: sel ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    RoleBadge(r.value, size: 58),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.desc,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      sel ? Icons.check_box : Icons.check_box_outline_blank,
                      color: sel ? AppColors.primary : AppColors.border,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          PrimaryButton(
            label: picked.length == 1
                ? 'Continue as ${picked.first.name}'
                : 'Continue with ${picked.length} roles',
            icon: Icons.chevron_right,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SignupScreen(
                  roles: picked.map((e) => e.value).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
