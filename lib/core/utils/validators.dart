class Validators {
  static final RegExp _name = RegExp(
    r'^[\p{L}]+(?: [\p{L}]+)*$',
    unicode: true,
  );
  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );
  static final RegExp _phone = RegExp(r'^\+?[0-9]{10,14}$');

  static String cleanName(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? name(String? v) {
    final s = cleanName(v ?? '');
    if (s.isEmpty) return 'Enter your full name';
    if (s.length < 2) return 'Name is too short';
    if (s.length > 50) return 'Name is too long';
    if (!_name.hasMatch(s)) return 'Letters only (no numbers or symbols)';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your email';
    if (s.length > 254 || !_email.hasMatch(s)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Optional phone number (Pakistan: 03001234567 or +923001234567).
  static String? phoneOptional(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (s.isEmpty) return null;
    if (!_phone.hasMatch(s)) return 'Enter a valid phone number';
    return null;
  }

  static String? newPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Enter a password';
    if (s.length < 8) return 'Min. 8 characters';
    if (s.length > 72) return 'Password is too long';
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'[0-9]').hasMatch(s)) {
      return 'Use letters and at least one number';
    }
    return null;
  }

  static String? Function(String?) sameAs(String Function() other) =>
      (String? v) => v == other() ? null : 'Passwords do not match';

  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Enter your password';
    return null;
  }

  /// 0 (empty) .. 4 (strong), shown as the strength bar on reset / signup.
  static int strength(String s) {
    if (s.isEmpty) return 0;
    var n = 0;
    if (s.length >= 8) n++;
    if (RegExp(r'[A-Z]').hasMatch(s) && RegExp(r'[a-z]').hasMatch(s)) n++;
    if (RegExp(r'[0-9]').hasMatch(s)) n++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(s) || s.length >= 12) n++;
    return n;
  }
}
