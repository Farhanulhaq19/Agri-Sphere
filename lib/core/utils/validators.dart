class Validators {
  static final RegExp _name = RegExp(r'^[\p{L}]+(?: [\p{L}]+)*$', unicode: true);
  static final RegExp _email =
      RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');

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
    if (s.length > 254 || !_email.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? newPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Enter a password';
    if (s.length < 8) return 'Min. 8 characters';
    if (s.length > 72) return 'Password is too long';
    return null;
  }

  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Enter your password';
    return null;
  }
}