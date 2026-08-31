import '../publication.dart';
import '../publication_repository.dart';

/// Orchestrates publication catalog searching with combined logic:
/// 1. Empty or whitespace query returns active publications.
/// 2. Code matches are queried first and placed at the top of results.
/// 3. Name matches are queried second and appended after code matches.
/// 4. Duplicates are removed strictly by [Publication.id].
/// 5. Final list is capped at 20 publications max.
class PublicationCatalogSearchService {
  final PublicationRepository _repository;

  PublicationCatalogSearchService(this._repository);

  Future<List<Publication>> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return _repository.getActivePublications();
    }

    final codeResults = await _repository.searchByCode(trimmedQuery, limit: 20);
    final nameResults = await _repository.searchByName(trimmedQuery, limit: 20);

    final seenIds = <int>{};
    final combined = <Publication>[];

    for (final pub in codeResults) {
      if (pub.id != null && !seenIds.contains(pub.id!)) {
        seenIds.add(pub.id!);
        combined.add(pub);
      }
    }

    for (final pub in nameResults) {
      if (pub.id != null && !seenIds.contains(pub.id!)) {
        seenIds.add(pub.id!);
        combined.add(pub);
      }
    }

    if (combined.length > 20) {
      return combined.sublist(0, 20);
    }

    return combined;
  }
}
