import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requesters/domain/requester.dart';
import 'package:request_manager_app/features/requesters/domain/requester_repository.dart';
import 'package:request_manager_app/features/requesters/domain/services/requester_duplicate_checker.dart';

class MockRequesterRepository implements RequesterRepository {
  final List<Requester> items = [];

  @override
  Future<Requester> create(Requester requester) async {
    final created = requester.copyWith(id: items.length + 1);
    items.add(created);
    return created;
  }

  @override
  Future<Requester?> getById(int id) async => items
      .cast<Requester?>()
      .firstWhere((r) => r?.id == id, orElse: () => null);

  @override
  Future<Requester?> findByNormalizedName(String normalizedName) async =>
      items.cast<Requester?>().firstWhere(
            (r) => r?.normalizedName == normalizedName,
            orElse: () => null,
          );

  @override
  Future<List<Requester>> searchActiveByName(String query,
          {int limit = 20}) async =>
      items
          .where((r) => r.isActive && r.normalizedName.contains(query))
          .toList();

  @override
  Future<List<Requester>> getAll() async => items;
}

void main() {
  group('RequesterDuplicateChecker Tests', () {
    late MockRequesterRepository repository;
    late RequesterDuplicateChecker checker;

    final t0 = DateTime.utc(2026, 9, 22, 10, 0);

    setUp(() {
      repository = MockRequesterRepository();
      checker = RequesterDuplicateChecker(repository);
    });

    test(
        'Exact normalized duplicate blocks creation (María Soto vs Maria Soto / MARIA SOTO)',
        () async {
      final existing = Requester(
        id: 1,
        name: 'María Soto',
        createdAt: t0,
        updatedAt: t0,
      );
      repository.items.add(existing);

      // Check case 1: 'Maria Soto' (without accent)
      final res1 = await checker.check('Maria Soto');
      expect(res1, isA<RequesterExactDuplicateResult>());
      expect((res1 as RequesterExactDuplicateResult).existing.name,
          equals('María Soto'));

      // Check case 2: 'MARIA SOTO' (uppercase)
      final res2 = await checker.check('MARIA SOTO');
      expect(res2, isA<RequesterExactDuplicateResult>());
      expect((res2 as RequesterExactDuplicateResult).existing.name,
          equals('María Soto'));

      // Check case 3: '  María   Soto ' (extra spaces)
      final res3 = await checker.check('  María   Soto ');
      expect(res3, isA<RequesterExactDuplicateResult>());
    });

    test(
        'Possible match (Levenshtein similarity) triggers warning (Maria Soto vs Mari Soto)',
        () async {
      final existing = Requester(
        id: 1,
        name: 'Maria Soto',
        createdAt: t0,
        updatedAt: t0,
      );
      repository.items.add(existing);

      // 'Mari Soto' differs by 1 letter (90% similarity) -> warning
      final result = await checker.check('Mari Soto');
      expect(result, isA<RequesterPossibleDuplicateResult>());
      final matches = (result as RequesterPossibleDuplicateResult).matches;
      expect(matches.length, equals(1));
      expect(matches.first.name, equals('Maria Soto'));
    });

    test('Distinct names return NoDuplicateResult', () async {
      final existing = Requester(
        id: 1,
        name: 'Maria Soto',
        createdAt: t0,
        updatedAt: t0,
      );
      repository.items.add(existing);

      final result = await checker.check('Carlos Pérez');
      expect(result, isA<RequesterNoDuplicateResult>());
    });
  });
}
