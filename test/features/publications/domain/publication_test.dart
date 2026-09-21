import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/publication_status.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';

void main() {
  final tCreatedAt = DateTime.utc(2026, 8, 20, 10, 0);
  final tUpdatedAt = DateTime.utc(2026, 8, 20, 10, 0);

  group('TriStateValue Tests', () {
    test('Representación correcta de SIN DEFINIR', () {
      const val = TriStateValue<String>.sinDefinir();
      expect(val.isSinDefinir, isTrue);
      expect(val.isNoAplica, isFalse);
      expect(val.isConValor, isFalse);
      expect(val.toString(), equals('SIN DEFINIR'));
    });

    test('Representación correcta de NO APLICA', () {
      const val = TriStateValue<String>.noAplica();
      expect(val.isSinDefinir, isFalse);
      expect(val.isNoAplica, isTrue);
      expect(val.isConValor, isFalse);
      expect(val.toString(), equals('NO APLICA'));
    });

    test('Representación correcta de CON VALOR', () {
      final val = TriStateValue<String>.conValor('Grande');
      expect(val.isSinDefinir, isFalse);
      expect(val.isNoAplica, isFalse);
      expect(val.isConValor, isTrue);
      expect(val.value, equals('Grande'));
      expect(val.toString(), equals('Grande'));
    });

    test('Valores vacíos o con espacios para conValor lanzan ArgumentError',
        () {
      expect(() => TriStateValue<String>.conValor(''), throwsArgumentError);
      expect(() => TriStateValue<String>.conValor('   '), throwsArgumentError);
    });
  });

  group('Publication Domain Model Tests', () {
    test('Nombre obligatorio - lanza error si es vacío o espacios', () {
      expect(
        () => Publication(
          name: '',
          createdAt: tCreatedAt,
          updatedAt: tUpdatedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => Publication(
          name: '   ',
          createdAt: tCreatedAt,
          updatedAt: tUpdatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('Draft sin código tiene status DRAFT', () {
      final pub = Publication(
        name: 'Biblia',
        type: 'Libro',
        code: null,
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );
      expect(pub.status, equals(PublicationStatus.draft));
    });

    test('Draft sin tipo tiene status DRAFT', () {
      final pub = Publication(
        name: 'Biblia',
        type: null,
        code: 'RBI-8',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );
      expect(pub.status, equals(PublicationStatus.draft));
    });

    test(
        'Complete tiene status COMPLETE cuando code, name y type están presentes',
        () {
      final pub = Publication(
        name: 'Biblia',
        type: 'Libro',
        code: 'RBI-8',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );
      expect(pub.status, equals(PublicationStatus.complete));
    });

    test('COMPLETE con tamaño/versión sin definir sigue siendo COMPLETE', () {
      final pub = Publication(
        name: 'Biblia',
        type: 'Libro',
        code: 'RBI-8',
        size: const TriStateValue.sinDefinir(),
        version: const TriStateValue.sinDefinir(),
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );
      expect(pub.status, equals(PublicationStatus.complete));
    });

    test('Evolución de Draft a Complete con copyWith mantiene el mismo id', () {
      final draft = Publication(
        id: 15,
        name: 'Biblia',
        description: 'Biblia Grande Version Lujo...',
        code: null,
        type: null,
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      expect(draft.status, equals(PublicationStatus.draft));
      expect(draft.id, equals(15));

      final complete = draft.copyWith(
        code: () => 'RBI-8',
        name: 'Biblia Letra Grande Revisada 2012',
        type: () => 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
      );

      expect(complete.id, equals(15));
      expect(complete.status, equals(PublicationStatus.complete));
      expect(complete.code, equals('RBI-8'));
      expect(complete.name, equals('Biblia Letra Grande Revisada 2012'));
      expect(complete.type, equals('Libro'));
      expect(complete.size, equals(TriStateValue.conValor('Grande')));
      expect(complete.version, equals(TriStateValue.conValor('Reina Valera')));
      expect(complete.createdAt, equals(tCreatedAt));
      expect(complete.updatedAt, equals(tUpdatedAt));
    });

    test('isActive tiene valor predeterminado true y se puede desactivar', () {
      final pub = Publication(
        name: 'Libro A',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );
      expect(pub.isActive, isTrue);

      final inactivePub = pub.copyWith(isActive: false);
      expect(inactivePub.isActive, isFalse);
    });

    test(
        'Normalización de strings: code, type y description vacíos se convierten en null',
        () {
      final pub = Publication(
        name: '  Manual de Literatura  ',
        code: '   ',
        type: '',
        description: ' \n  ',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      expect(pub.name, equals('Manual de Literatura'));
      expect(pub.code, isNull);
      expect(pub.type, isNull);
      expect(pub.description, isNull);
    });

    test('Normalización de fechas a UTC garantizada en factory', () {
      final customCreatedAtLocal = DateTime(2026, 8, 20, 10, 0);
      final customUpdatedAtLocal = DateTime(2026, 8, 20, 12, 0);

      final pub = Publication(
        name: 'Libro A',
        createdAt: customCreatedAtLocal,
        updatedAt: customUpdatedAtLocal,
      );

      expect(pub.createdAt.isUtc, isTrue);
      expect(pub.updatedAt.isUtc, isTrue);
      expect(pub.createdAt, equals(customCreatedAtLocal.toUtc()));
      expect(pub.updatedAt, equals(customUpdatedAtLocal.toUtc()));
    });

    test('copyWith preserva createdAt y updatedAt por defecto', () {
      final pub = Publication(
        id: 7,
        name: 'Revista Semanal',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      final modified = pub.copyWith(name: 'Revista Mensual');

      expect(modified.name, equals('Revista Mensual'));
      expect(modified.createdAt, equals(tCreatedAt));
      expect(modified.updatedAt, equals(tUpdatedAt));
      expect(modified.createdAt.isUtc, isTrue);
      expect(modified.updatedAt.isUtc, isTrue);
    });

    test('copyWith respeta updatedAt explícito y lo normaliza a UTC', () {
      final pub = Publication(
        id: 7,
        name: 'Revista Semanal',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      final newUpdatedAtLocal = DateTime(2026, 8, 22, 16, 0);
      final modified = pub.copyWith(updatedAt: newUpdatedAtLocal);

      expect(modified.updatedAt.isUtc, isTrue);
      expect(modified.updatedAt, equals(newUpdatedAtLocal.toUtc()));
      expect(modified.createdAt, equals(tCreatedAt));
    });

    test(
        'Regla especial de Draft rápido (quickDraft) con descripción obligatoria y timestamps UTC',
        () {
      final draftCreatedAtLocal = DateTime(2026, 8, 21, 9, 30);
      final draftUpdatedAtLocal = DateTime(2026, 8, 21, 9, 30);

      // Caso exitoso
      final draft = Publication.quickDraft(
        name: 'Biblia',
        description: 'Biblia Grande Version Lujo de letra grande...',
        createdAt: draftCreatedAtLocal,
        updatedAt: draftUpdatedAtLocal,
      );

      expect(draft.name, equals('Biblia'));
      expect(draft.description,
          equals('Biblia Grande Version Lujo de letra grande...'));
      expect(draft.code, isNull);
      expect(draft.type, isNull);
      expect(draft.status, equals(PublicationStatus.draft));
      expect(draft.createdAt.isUtc, isTrue);
      expect(draft.updatedAt.isUtc, isTrue);
      expect(draft.createdAt, equals(draftCreatedAtLocal.toUtc()));
      expect(draft.updatedAt, equals(draftUpdatedAtLocal.toUtc()));

      // Casos inválidos
      expect(
        () => Publication.quickDraft(
          name: 'Biblia',
          description: '',
          createdAt: tCreatedAt,
          updatedAt: tUpdatedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => Publication.quickDraft(
          name: 'Biblia',
          description: '   ',
          createdAt: tCreatedAt,
          updatedAt: tUpdatedAt,
        ),
        throwsArgumentError,
      );
    });
  });
}
