abstract final class AppDateTime {
  /// Normalizes any [DateTime] to UTC, preserving the exact instant.
  static DateTime normalizeUtc(DateTime value) => value.toUtc();

  /// Converts a [DateTime] into a canonical ISO-8601 UTC string with 'Z' suffix
  /// suitable for SQLite storage.
  static String toStorage(DateTime value) => value.toUtc().toIso8601String();

  /// Deserializes a stored ISO-8601 string into a UTC [DateTime] ([isUtc] == true).
  ///
  /// Supports both canonical UTC strings (with 'Z') and legacy/local strings,
  /// guaranteeing that the resulting [DateTime] is in UTC.
  static DateTime fromStorage(String value) => DateTime.parse(value).toUtc();

  /// Converts a UTC [DateTime] into local time for presentation.
  static DateTime toLocal(DateTime value) => value.toLocal();

  /// Formats a [DateTime] into a human-readable Spanish date string (e.g. "24 sep 2026")
  /// after converting it to local time.
  static String formatShortDate(DateTime value) {
    final local = toLocal(value);
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
