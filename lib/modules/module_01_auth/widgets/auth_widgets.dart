import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

String roleDisplay(String role) => role == 'Expert' ? 'Agri Expert' : role;

/// Green gradient header + rounded light sheet used by all auth screens.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBack)
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      )
                    else
                      const SizedBox(height: 36),
                    const SizedBox(height: 10),
                    Image.asset(
                      'assets/img/2_mark_transparent.png',
                      width: 48,
                      height: 48,
                      cacheWidth: 150,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.eco_outlined, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: child,
                      ),
                    ),
                    if (footer != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18, top: 4),
                        child: footer,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  static OutlineInputBorder _border([Color color = AppColors.border]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: AppColors.muted),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: _border(),
            enabledBorder: _border(),
            focusedBorder: _border(AppColors.primary),
            errorBorder: _border(Colors.redAccent),
            focusedErrorBorder: _border(Colors.redAccent),
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: loading ? null : onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
              )
            else ...[
              Icon(icon, size: 24, color: AppColors.text),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  final String text;
  const OrDivider({super.key, this.text = 'or'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;

  const AuthFooterLink({
    super.key,
    required this.text,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}