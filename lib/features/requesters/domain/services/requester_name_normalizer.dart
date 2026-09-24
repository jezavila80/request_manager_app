import 'requester_name_cleaner.dart';

class RequesterNameNormalizer {
  RequesterNameNormalizer._();

  static const Map<String, String> _diacriticsMap = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
  };

  /// Computes the deterministic comparison key for a requester name.
  ///
  /// Rules:
  /// - Cleans whitespace (trim and internal multiple spaces collapsed).
  /// - Case-insensitive: converts to lowercase.
  /// - Accent-insensitive for vowels (á, é, í, ó, ú, ü, etc.).
  /// - Semantically preserves 'ñ': 'ñ' is kept as 'ñ' (and 'Ñ' becomes 'ñ'),
  ///   ensuring 'ñ' is not conflated with 'n' (e.g. 'peña' != 'pena').
  static String normalize(String name) {
    final cleaned = RequesterNameCleaner.clean(name).toLowerCase();
    if (cleaned.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      buffer.write(_diacriticsMap[char] ?? char);
    }
    return buffer.toString();
  }
}
