import '../requester.dart';
import '../requester_repository.dart';
import 'requester_name_cleaner.dart';
import 'requester_name_normalizer.dart';

sealed class RequesterCheckResult {
  const RequesterCheckResult();
}

final class RequesterExactDuplicateResult extends RequesterCheckResult {
  final Requester existing;
  const RequesterExactDuplicateResult(this.existing);
}

final class RequesterPossibleDuplicateResult extends RequesterCheckResult {
  final List<Requester> matches;
  const RequesterPossibleDuplicateResult(this.matches);
}

final class RequesterNoDuplicateResult extends RequesterCheckResult {
  const RequesterNoDuplicateResult();
}

class RequesterDuplicateChecker {
  final RequesterRepository _repository;

  /// Similarity threshold above which a candidate is considered a possible match.
  static const double similarityThreshold = 0.80;

  RequesterDuplicateChecker(this._repository);

  /// Checks if a candidate raw name conflicts with existing requesters.
  ///
  /// Priority:
  /// 1. Exact normalized match: hard block, returns [RequesterExactDuplicateResult].
  /// 2. Reasonable similarity (Levenshtein similarity >= 0.80 or edit distance <= 2):
  ///    warning, returns [RequesterPossibleDuplicateResult].
  /// 3. No match: returns [RequesterNoDuplicateResult].
  Future<RequesterCheckResult> check(String candidateName) async {
    final cleaned = RequesterNameCleaner.clean(candidateName);
    final normalized = RequesterNameNormalizer.normalize(cleaned);

    if (normalized.isEmpty) {
      return const RequesterNoDuplicateResult();
    }

    // 1. Exact normalized match across all requesters (active or inactive)
    final exact = await _repository.findByNormalizedName(normalized);
    if (exact != null) {
      return RequesterExactDuplicateResult(exact);
    }

    // 2. Fetch all requesters to check similarity
    final allRequesters = await _repository.getAll();
    final List<Requester> matches = [];

    for (final existing in allRequesters) {
      if (isSimilar(normalized, existing.normalizedName)) {
        matches.add(existing);
      }
    }

    if (matches.isNotEmpty) {
      return RequesterPossibleDuplicateResult(matches);
    }

    return const RequesterNoDuplicateResult();
  }

  /// Calculates Levenshtein distance between two strings.
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List.generate(s2.length + 1, (i) => i);
    List<int> curr = List.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[s2.length];
  }

  /// Calculates similarity ratio between 0.0 (completely different) and 1.0 (identical).
  static double similarity(String s1, String s2) {
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    if (maxLen == 0) return 1.0;
    final dist = levenshteinDistance(s1, s2);
    return 1.0 - (dist / maxLen);
  }

  /// Determines if two normalized strings have reasonable similarity to warrant a warning.
  static bool isSimilar(String norm1, String norm2) {
    if (norm1 == norm2) return true;
    final dist = levenshteinDistance(norm1, norm2);
    final sim = similarity(norm1, norm2);

    // Matches if similarity ratio >= 0.80 or if edit distance <= 2 for strings with length >= 6
    if (sim >= similarityThreshold) return true;
    if (norm1.length >= 6 && norm2.length >= 6 && dist <= 2) return true;

    return false;
  }
}
