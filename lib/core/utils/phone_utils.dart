class PhoneUtils {
  const PhoneUtils._();

  static String normalizeIndiaMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    return raw.trim();
  }
}
