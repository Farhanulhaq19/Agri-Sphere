import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';

/// Small pill that switches the app between English and Urdu.
class LangButton extends StatelessWidget {
  final bool onDark;
  const LangButton({super.key, this.onDark = true});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLang.urdu,
      builder: (context, ur, _) {
        final fg = onDark ? Colors.white : const Color(0xFF16803C);
        final bg = onDark
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFE8F5EC);
        return Material(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: AppLang.toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    ur ? 'English' : 'اردو',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
