import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import 'signup_screen.dart';

class _RoleItem {
  final String value;
  final String name;
  final String desc;
  final IconData icon;
  const _RoleItem(this.value, this.name, this.desc, this.icon);
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  static const List<_RoleItem> _roles = [
    _RoleItem('Farmer', 'Farmer', 'Manage crops, sell produce, ask experts', Icons.grass),
    _RoleItem('Buyer', 'Buyer', 'Browse the marketplace and order fresh', Icons.shopping_basket_outlined),
    _RoleItem('Expert', 'Agri Expert', 'Answer queries and publish advisories', Icons.eco_outlined),
    _RoleItem('Supplier', 'Supplier', 'List seeds, fertiliser and equipment', Icons.inventory_2_outlined),
    _RoleItem('Admin', 'Admin', 'Manage users, approvals and reports', Icons.shield_outlined),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choose your role',
      subtitle: 'Pick how you will use AgriSphere.',
      child: Column(
        children: [
          ...List.generate(_roles.length, (i) {
            final r = _roles[i];
            final sel = i == _selected;
            return GestureDetector(
              onTap: () => setState(() => _selected = i),
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
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : const Color(0xFFE4F2E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(r.icon,
                          size: 22, color: sel ? Colors.white : AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.text)),
                          const SizedBox(height: 2),
                          Text(r.desc,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Icon(
                      sel ? Icons.check_circle : Icons.circle_outlined,
                      color: sel ? AppColors.primary : AppColors.border,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Continue as ${_roles[_selected].name}',
            icon: Icons.chevron_right,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SignupScreen(role: _roles[_selected].value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}