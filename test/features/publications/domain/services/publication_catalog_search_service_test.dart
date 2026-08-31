import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/publication_repository.dart';
import 'package:request_manager_app/features/publications/domain/services/publication_catalog_search_service.dart';

class FakePublicationRepository implements PublicationRepository {
  List<Publication> activePublications = [];
  List<Publication> codeSearchResults = [];
  List<Publication> nameSearchResults = [];

  bool getActivePublicationsCalled = false;
  bool searchByCodeCalled = false;
  bool searchByNameCalled = false;

  @override
  Future<List<Publication>> getActivePublications() async {
    getActivePublicationsCalled = true;
    return activePublications;
  }

  @override
  Future<List<Publication>> searchByCode(String query, {int limit = 20}) async {
    searchByCodeCalled = true;
    return codeSearchResults;
  }

  @override
  Future<List<Publication>> searchByName(String query, {int limit = 20}) async {
    searchByNameCalled = true;
    return nameSearchResults;
  }

  @override
  Future<Publication> create(Publication publication) async => publication;

  @override
  Future<List<Publication>> getAll() async => activePublications;

  @override
  Future<Publication?> getById(int id) async => null;

  @override
  Future<Publication?> findByExactCode(String code) async => null;

  @override
  Future<List<Publication>> findActiveByName(String name) async => [];
}

void main() {
  late FakePublicationRepository repository;
  late PublicationCatalogSearchService service;

  setUp(() {
    repository = FakePublicationRepository();
    service = PublicationCatalogSearchService(repository);
  });

  group('PublicationCatalogSearchService Tests', () {
    test('Empty or whitespace query returns getActivePublications()', () async {
      repository.activePublications = [
        Publication(id: 1, name: 'Biblia 1', isActive: true),
        Publication(id: 2, name: 'Biblia 2', isActive: true),
      ];

      final res1 = await service.search('');
      final res2 = await service.search('   ');

      expect(res1.length, 2);
      expect(res2.length, 2);
      expect(repository.getActivePublicationsCalled, isTrue);
      expect(repository.searchByCodeCalled, isFalse);
      expect(repository.searchByNameCalled, isFalse);
    });

    test('Code matches are prioritized over name matches', () async {
      final codePub1 = Publication(id: 10, code: 'RBI-1', name: 'Alpha');
      final codePub2 = Publication(id: 20, code: 'RBI-2', name: 'Beta');
      final namePub1 = Publication(id: 30, code: 'XYZ-1', name: 'RBI Gamma');
      final namePub2 = Publication(id: 40, code: 'XYZ-2', name: 'RBI Delta');

      repository.codeSearchResults = [codePub1, codePub2];
      repository.nameSearchResults = [namePub1, namePub2];

      final results = await service.search('RBI');

      expect(results.length, 4);
      expect(results[0].id, 10);
      expect(results[1].id, 20);
      expect(results[2].id, 30);
      expect(results[3].id, 40);
    });

    test('Deduplicates publications by Publication.id preserving code priority',
        () async {
      final pubA = Publication(id: 1, code: 'RBI-8', name: 'Biblia RBI');
      final pubB = Publication(id: 2, code: 'RBI-9', name: 'Biblia 2');
      final pubC = Publication(id: 3, code: 'ABC-1', name: 'Biblia RBI 3');

      // pubB and pubA are present in name results too
      repository.codeSearchResults = [pubA, pubB];
      repository.nameSearchResults = [pubB, pubA, pubC];

      final results = await service.search('RBI');

      expect(results.length, 3);
      expect(results[0].id, 1);
      expect(results[1].id, 2);
      expect(results[2].id, 3);
    });

    test('Limits final combined results to maximum of 20', () async {
      final codeList = List.generate(
        15,
        (i) => Publication(id: i + 1, code: 'CODE-$i', name: 'Pub $i'),
      );
      final nameList = List.generate(
        15,
        (i) => Publication(id: i + 100, code: 'NAME-$i', name: 'Pub $i'),
      );

      repository.codeSearchResults = codeList;
      repository.nameSearchResults = nameList;

      final results = await service.search('Pub');

      expect(results.length, 20);
      expect(results.first.id, 1);
      expect(results[14].id, 15);
      expect(results[15].id, 100);
      expect(results[19].id, 104);
    });
  });
}
