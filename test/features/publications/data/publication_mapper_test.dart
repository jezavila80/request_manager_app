import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/publications/data/publication_mapper.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';

void main() {
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
      );

      final map = PublicationMapper.toMap(publication);
      expect(map['id'], isNull);
      expect(map['code'], isNull);
      expect(map['name'], 'Biblia Draft');
      expect(map['description'], isNull);
      expect(map['type'], isNull);
      expect(map['size_state'], 'undefined');
      expect(map['size_value'], isNull);
      expect(map['version_state'], 'undefined');
      expect(map['version_value'], isNull);
      expect(map['is_active'], 1);
      expect(map['created_at'], publication.createdAt.toIso8601String());
      expect(map['updated_at'], publication.updatedAt.toIso8601String());

      final converted = PublicationMapper.fromMap(map);
      expect(converted.id, isNull);
      expect(converted.code, isNull);
      expect(converted.name, 'Biblia Draft');
      expect(converted.description, isNull);
      expect(converted.type, isNull);
      expect(converted.size, const TriStateValue<String>.sinDefinir());
      expect(converted.version, const TriStateValue<String>.sinDefinir());
      expect(converted.isActive, isTrue);
      expect(
          converted.createdAt.isAtSameMomentAs(publication.createdAt), isTrue);
      // Wait, updatedAt is updated to DateTime.now() in copyWith but in fromMap it parses the stored updatedAt
      expect(
          converted.updatedAt.isAtSameMomentAs(publication.updatedAt), isTrue);
    });

    test('Round-trip convert a Complete publication with values and id', () {
      final now = DateTime.now();
      final publication = Publication(
        id: 42,
        name: 'Biblia Letra Grande',
        code: 'RBI-8',
        description: 'Edición de lujo',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = PublicationMapper.toMap(publication);
      expect(map['id'], 42);
      expect(map['code'], 'RBI-8');
      expect(map['name'], 'Biblia Letra Grande');
      expect(map['description'], 'Edición de lujo');
      expect(map['type'], 'Libro');
      expect(map['size_state'], 'value');
      expect(map['size_value'], 'Grande');
      expect(map['version_state'], 'value');
      expect(map['version_value'], 'Reina Valera');
      expect(map['is_active'], 0);
      expect(map['created_at'], now.toIso8601String());
      expect(map['updated_at'], now.toIso8601String());

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
      expect(converted.createdAt.isAtSameMomentAs(now), isTrue);
      expect(converted.updatedAt.isAtSameMomentAs(now), isTrue);
    });

    test('Round-trip convert with size and version not_applicable', () {
      final publication = Publication(
        name: 'Tratado Breve',
        size: const TriStateValue.noAplica(),
        version: const TriStateValue.noAplica(),
      );

      final map = PublicationMapper.toMap(publication);
      expect(map['size_state'], 'not_applicable');
      expect(map['size_value'], isNull);
      expect(map['version_state'], 'not_applicable');
      expect(map['version_value'], isNull);

      final converted = PublicationMapper.fromMap(map);
      expect(converted.size, const TriStateValue<String>.noAplica());
      expect(converted.version, const TriStateValue<String>.noAplica());
    });
  });
}
