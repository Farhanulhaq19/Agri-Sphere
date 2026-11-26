import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrisphere/core/i18n/ur.dart';

/// Tiny built-in translator (English <-> Urdu). No extra packages needed.
///
/// Usage: `Text(tr('Add machine'))`. If a phrase is missing from [kUrdu]
/// the English text is shown, so nothing ever breaks.
class AppLang {
  static final ValueNotifier<bool> urdu = ValueNotifier<bool>(false);
  static bool get isUrdu => urdu.value;
  static const _key = 'app_lang_urdu';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      urdu.value = p.getBool(_key) ?? false;
    } catch (_) {}
  }

  static Future<void> set(bool ur) async {
    if (urdu.value == ur) return;
    urdu.value = ur;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, ur);
    } catch (_) {}
    // Rebuild every screen that is currently open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      final root = WidgetsBinding.instance.rootElement;
      if (root != null) mark(root);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  static Future<void> toggle() => set(!urdu.value);
}

/// Translate [en] when the app is in Urdu mode.
String tr(String en) {
  if (!AppLang.urdu.value) return en;
  return kUrdu[en] ?? kUrdu[en.trim()] ?? en;
}

/// Wraps the whole app so it flips to right-to-left in Urdu.
Widget langDirection(BuildContext context, Widget? child) {
  return ValueListenableBuilder<bool>(
    valueListenable: AppLang.urdu,
    builder: (context, ur, _) => Directionality(
      textDirection: ur ? TextDirection.rtl : TextDirection.ltr,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
