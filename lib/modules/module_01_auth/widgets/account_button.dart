import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/lang_button.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/modules/module_01_auth/screens/account_screen.dart';

/// Language switch + round avatar button for green headers.
/// The avatar opens the Account page (switch role, profile, password, logout).
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const LangButton(),
      const SizedBox(width: 6),
      CircleBtn(icon: Icons.format_size, onTap: () => showTextSizeSheet(context)),
      const SizedBox(width: 6),
      CircleBtn(
        icon: Icons.account_circle_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        ),
      ),
    ],
  );
}
