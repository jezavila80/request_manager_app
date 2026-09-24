class RequesterNameCleaner {
  RequesterNameCleaner._();

  /// Cleans display name by trimming leading/trailing whitespace and reducing
  /// multiple internal whitespace sequences into a single space.
  /// Preserves accents, diacritics, and original casing.
  static String clean(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Checks if [name] satisfies the domain rule of having at least two
  /// significant words after cleaning whitespace.
  ///
  /// A significant word is a non-empty token containing at least one textual/alphabetic
  /// character (including Spanish letters with diacritics).
  static bool hasAtLeastTwoSignificantWords(String name) {
    final cleaned = clean(name);
    if (cleaned.isEmpty) return false;

    final words = cleaned.split(' ');
    if (words.length < 2) return false;

    // Pattern matching any Unicode letter, including Spanish diacritics (á, é, í, ó, ú, ü, ñ)
    final letterRegex = RegExp(r'[\p{L}]', unicode: true);

    final significantWords = words.where((w) => letterRegex.hasMatch(w));
    return significantWords.length >= 2;
  }
}
