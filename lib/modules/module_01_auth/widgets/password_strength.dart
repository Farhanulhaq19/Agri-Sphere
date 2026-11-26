import 'package:flutter/material.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/core/utils/validators.dart';

/// Four-segment bar under a "new password" field.
class PasswordStrength extends StatelessWidget {
  final String password;
  const PasswordStrength(this.password, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = Validators.strength(password);
    const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      AppColors.border,
      Colors.red,
      Colors.orange,
      Colors.lightGreen,
      AppColors.primary,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          ...List.generate(
            4,
            (i) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                decoration: BoxDecoration(
                  color: i < s ? colors[s] : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(
              labels[s],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors[s],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
