class Validators {
  const Validators._();

  static String? requiredName(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'Enter a valid name';
    }
    return null;
  }

  static String? indianMobile(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return 'Enter a 10 digit mobile number';
    }
    return null;
  }

  static String partySizeBand(int partySize) {
    if (partySize <= 2) return '1-2';
    if (partySize <= 4) return '3-4';
    if (partySize <= 6) return '5-6';
    return '7+';
  }
}
