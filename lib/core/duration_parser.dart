class DurationParser {
  static final RegExp _pattern =
      RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$');

  static Duration parse(Object? value, {String field = 'duration'}) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be like 40s, 3m or 1m30s.');
    }
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      throw FormatException('$field has invalid duration "$value".');
    }
    final h = int.tryParse(match.group(1) ?? '') ?? 0;
    final m = int.tryParse(match.group(2) ?? '') ?? 0;
    final s = int.tryParse(match.group(3) ?? '') ?? 0;
    if (h == 0 && m == 0 && s == 0) {
      throw FormatException('$field must be greater than 0s.');
    }
    return Duration(hours: h, minutes: m, seconds: s);
  }

  static Duration parseAllowZero(Object? value, {String field = 'duration'}) {
    if (value == '0s') return Duration.zero;
    return parse(value, field: field);
  }
}
