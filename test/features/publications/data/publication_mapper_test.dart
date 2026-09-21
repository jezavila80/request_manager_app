import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/features/publications/data/publication_mapper.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';

void main() {
  final tCreatedAt = DateTime.utc(2026, 8, 20, 10, 0);
  final tUpdatedAt = DateTime.utc(2026, 8, 20, 10, 30);

  group('PublicationMapper Unit Tests', () {
    test('Round-trip convert a Draft publication with nulls/undefined', () {
      final publication = Publication(
        name: 'Biblia Draft',
        code: null,
        description: null,
        type: null,
        size: const TriStateValue.sinDefinir(),
        version: const TriStateValue.sinDefinir(),
        isActive: true,
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      final map = PublicationMapper.toMap(publication);
      expect(map[DatabaseConstants.columnId], isNull);
      expect(map[DatabaseConstants.columnCode], isNull);
      expect(map[DatabaseConstants.columnName], 'Biblia Draft');
      expect(map[DatabaseConstants.columnDescription], isNull);
      expect(map[DatabaseConstants.columnType], isNull);
      expect(map[DatabaseConstants.columnSizeState], 'undefined');
      expect(map[DatabaseConstants.columnSizeValue], isNull);
      expect(map[DatabaseConstants.columnVersionState], 'undefined');
      expect(map[DatabaseConstants.columnVersionValue], isNull);
      expect(map[DatabaseConstants.columnIsActive], 1);
      expect((map[DatabaseConstants.columnCreatedAt] as String).endsWith('Z'),
          isTrue);
      expect((map[DatabaseConstants.columnUpdatedAt] as String).endsWith('Z'),
          isTrue);
      expect(
          map[DatabaseConstants.columnCreatedAt], '2026-08-20T10:00:00.000Z');
      expect(
          map[DatabaseConstants.columnUpdatedAt], '2026-08-20T10:30:00.000Z');

      final converted = PublicationMapper.fromMap(map);
      expect(converted.id, isNull);
      expect(converted.code, isNull);
      expect(converted.name, 'Biblia Draft');
      expect(converted.description, isNull);
      expect(converted.type, isNull);
      expect(converted.size, const TriStateValue<String>.sinDefinir());
      expect(converted.version, const TriStateValue<String>.sinDefinir());
      expect(converted.isActive, isTrue);
      expect(converted.createdAt.isUtc, isTrue);
      expect(converted.updatedAt.isUtc, isTrue);
      expect(converted.createdAt, equals(tCreatedAt));
      expect(converted.updatedAt, equals(tUpdatedAt));
    });

    test(
        'Round-trip convert a Complete publication with values, id, and local input dates',
        () {
      final localCreated = DateTime(2026, 9, 21, 14, 0);
      final localUpdated = DateTime(2026, 9, 21, 15, 0);

      final publication = Publication(
        id: 42,
        name: 'Biblia Letra Grande',
        code: 'RBI-8',
        description: 'Edición de lujo',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: false,
        createdAt: localCreated,
        updatedAt: localUpdated,
      );

      final map = PublicationMapper.toMap(publication);
      expect(map[DatabaseConstants.columnId], 42);
      expect(map[DatabaseConstants.columnCode], 'RBI-8');
      expect(map[DatabaseConstants.columnName], 'Biblia Letra Grande');
      expect(map[DatabaseConstants.columnDescription], 'Edición de lujo');
      expect(map[DatabaseConstants.columnType], 'Libro');
      expect(map[DatabaseConstants.columnSizeState], 'value');
      expect(map[DatabaseConstants.columnSizeValue], 'Grande');
      expect(map[DatabaseConstants.columnVersionState], 'value');
      expect(map[DatabaseConstants.columnVersionValue], 'Reina Valera');
      expect(map[DatabaseConstants.columnIsActive], 0);

      final storedCreated = map[DatabaseConstants.columnCreatedAt] as String;
      final storedUpdated = map[DatabaseConstants.columnUpdatedAt] as String;
      expect(storedCreated.endsWith('Z'), isTrue);
      expect(storedUpdated.endsWith('Z'), isTrue);

      final converted = PublicationMapper.fromMap(map);
      expect(converted.id, 42);
      expect(converted.code, 'RBI-8');
      expect(converted.name, 'Biblia Letra Grande');
      expect(converted.description, 'Edición de lujo');
      expect(converted.type, 'Libro');
      expect(converted.size.state, TriState.conValor);
      expect(converted.size.value, 'Grande');
      expect(converted.version.state, TriState.conValor);
      expect(converted.version.value, 'Reina Valera');
      expect(converted.isActive, isFalse);
      expect(converted.createdAt.isUtc, isTrue);
      expect(converted.updatedAt.isUtc, isTrue);
      expect(converted.createdAt, equals(localCreated.toUtc()));
      expect(converted.updatedAt, equals(localUpdated.toUtc()));
    });

    test('Round-trip convert with size and version not_applicable', () {
      final publication = Publication(
        name: 'Tratado Breve',
        size: const TriStateValue.noAplica(),
        version: const TriStateValue.noAplica(),
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      final map = PublicationMapper.toMap(publication);
      expect(map[DatabaseConstants.columnSizeState], 'not_applicable');
      expect(map[DatabaseConstants.columnSizeValue], isNull);
      expect(map[DatabaseConstants.columnVersionState], 'not_applicable');
      expect(map[DatabaseConstants.columnVersionValue], isNull);

      final converted = PublicationMapper.fromMap(map);
      expect(converted.size, const TriStateValue<String>.noAplica());
      expect(converted.version, const TriStateValue<String>.noAplica());
    });

    test(
        'fromMap throws FormatException when created_at or updated_at is null or empty',
        () {
      final validMap = PublicationMapper.toMap(Publication(
        name: 'Pub Test',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      ));

      final mapMissingCreatedAt = Map<String, Object?>.from(validMap)
        ..remove(DatabaseConstants.columnCreatedAt);
      expect(
        () => PublicationMapper.fromMap(mapMissingCreatedAt),
        throwsA(isA<FormatException>()),
      );

      final mapMissingUpdatedAt = Map<String, Object?>.from(validMap)
        ..remove(DatabaseConstants.columnUpdatedAt);
      expect(
        () => PublicationMapper.fromMap(mapMissingUpdatedAt),
        throwsA(isA<FormatException>()),
      );

      final mapEmptyCreatedAt = Map<String, Object?>.from(validMap)
        ..[DatabaseConstants.columnCreatedAt] = '   ';
      expect(
        () => PublicationMapper.fromMap(mapEmptyCreatedAt),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
