import 'publication.dart';

enum DuplicateCheckStatus {
  none,
  possibleDuplicate,
  duplicateCode,
}

class DuplicateCheckResult {
  final DuplicateCheckStatus status;
  final List<Publication> matches;

  const DuplicateCheckResult({
    required this.status,
    required this.matches,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuplicateCheckResult &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          _listEquals(matches, other.matches);

  @override
  int get hashCode => status.hashCode ^ matches.hashCode;

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'DuplicateCheckResult(status: $status, matches: $matches)';
}
