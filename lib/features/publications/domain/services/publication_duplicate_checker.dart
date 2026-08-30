import '../duplicate_check_result.dart';
import '../publication.dart';
import '../publication_repository.dart';
import '../tri_state_value.dart';

class PublicationDuplicateChecker {
  final PublicationRepository _repository;

  PublicationDuplicateChecker(this._repository);

  /// Checks if a candidate publication has duplicates in active records.
  ///
  /// Priority:
  /// 1. Duplicate code check (case-insensitive, exact). If a match is found,
  ///    returns [DuplicateCheckStatus.duplicateCode] and stops immediately.
  ///    This represents a hard block.
  /// 2. Possible duplicate check (by name, type, size, and version).
  ///    Returns [DuplicateCheckStatus.possibleDuplicate] with all compatible matches.
  ///    This represents a warning where the user can choose to ignore or cancel.
  /// 3. If no matches are found, returns [DuplicateCheckStatus.none].
  Future<DuplicateCheckResult> checkDuplicates(Publication candidate) async {
    // 1. Priority check: Duplicate code (exact match, case-insensitive)
    final candidateCode = candidate.code;
    if (candidateCode != null && candidateCode.trim().isNotEmpty) {
      final existingWithCode =
          await _repository.findActiveByExactCode(candidateCode);
      if (existingWithCode != null) {
        return DuplicateCheckResult(
          status: DuplicateCheckStatus.duplicateCode,
          matches: [existingWithCode],
        );
      }
    }

    // 2. Query candidates by name (case-insensitive, exact)
    final activeByName = await _repository.findActiveByName(candidate.name);

    // 3. Filter candidates by attribute compatibility in memory
    final List<Publication> matches = [];
    for (final existing in activeByName) {
      // Avoid matching itself if candidate already has an ID.
      if (existing.id != null &&
          candidate.id != null &&
          existing.id == candidate.id) {
        continue;
      }

      if (_areCompatible(existing, candidate)) {
        matches.add(existing);
      }
    }

    if (matches.isNotEmpty) {
      return DuplicateCheckResult(
        status: DuplicateCheckStatus.possibleDuplicate,
        matches: matches,
      );
    }

    return const DuplicateCheckResult(
      status: DuplicateCheckStatus.none,
      matches: [],
    );
  }

  /// Evaluates whether two publications are compatible (possible duplicates)
  /// based on their attributes: name, type, size, and version.
  bool _areCompatible(Publication existing, Publication candidate) {
    // Name must be equivalent (case-insensitive, trimmed).
    // (Both name fields are trimmed by Publication constructor, but we trim here as well).
    if (existing.name.trim().toLowerCase() !=
        candidate.name.trim().toLowerCase()) {
      return false;
    }

    // Type compatibility:
    // If defined in both, they must be equivalent (trim, case-insensitive).
    // If undefined in either, they are compatible (treated as missing/unknown info).
    final existingType = existing.type;
    final candidateType = candidate.type;
    if (existingType != null && candidateType != null) {
      if (existingType.trim().toLowerCase() !=
          candidateType.trim().toLowerCase()) {
        return false;
      }
    }

    // Size compatibility (TriStateValue)
    if (!_areTriStateCompatible(existing.size, candidate.size)) {
      return false;
    }

    // Version compatibility (TriStateValue)
    if (!_areTriStateCompatible(existing.version, candidate.version)) {
      return false;
    }

    return true;
  }

  /// Checks compatibility between two TriStateValue fields.
  ///
  /// Rules:
  /// - `undefined` (sinDefinir) is compatible with any value (means "unknown").
  /// - `not_applicable` (noAplica) is ONLY compatible with `not_applicable`.
  /// - `conValor` is compatible with another `conValor` if the string values
  ///   match after trim + case-insensitive comparison.
  bool _areTriStateCompatible(
    TriStateValue<String> existingVal,
    TriStateValue<String> candidateVal,
  ) {
    if (existingVal.isSinDefinir || candidateVal.isSinDefinir) {
      return true;
    }
    if (existingVal.isNoAplica && candidateVal.isNoAplica) {
      return true;
    }
    if (existingVal.isConValor && candidateVal.isConValor) {
      final val1 = existingVal.value ?? '';
      final val2 = candidateVal.value ?? '';
      return val1.trim().toLowerCase() == val2.trim().toLowerCase();
    }
    return false;
  }
}
