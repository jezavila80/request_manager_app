import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/publication_status.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';

void main() {
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
        () => Publication(name: ''),
        throwsArgumentError,
      );
      expect(
        () => Publication(name: '   '),
        throwsArgumentError,
      );
    });

    test('Draft sin código tiene status DRAFT', () {
      final pub = Publication(
        name: 'Biblia',
        type: 'Libro',
        code: null,
      );
      expect(pub.status, equals(PublicationStatus.draft));
    });

    test('Draft sin tipo tiene status DRAFT', () {
      final pub = Publication(
        name: 'Biblia',
        type: null,
        code: 'RBI-8',
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
    });

    test('isActive tiene valor predeterminado true y se puede desactivar', () {
      final pub = Publication(name: 'Libro A');
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
      );

      expect(pub.name, equals('Manual de Literatura'));
      expect(pub.code, isNull);
      expect(pub.type, isNull);
      expect(pub.description, isNull);
    });

    test('Conservación de fechas createdAt y updatedAt', () {
      final customCreatedAt = DateTime(2026, 8, 20, 10, 0);
      final customUpdatedAt = DateTime(2026, 8, 20, 12, 0);

      final pub = Publication(
        name: 'Libro A',
        createdAt: customCreatedAt,
        updatedAt: customUpdatedAt,
      );

      expect(pub.createdAt, equals(customCreatedAt));
      expect(pub.updatedAt, equals(customUpdatedAt));
    });

    test(
        'Regla especial de Draft rápido (quickDraft) con descripción obligatoria',
        () {
      // Caso exitoso
      final draft = Publication.quickDraft(
        name: 'Biblia',
        description: 'Biblia Grande Version Lujo de letra grande...',
      );

      expect(draft.name, equals('Biblia'));
      expect(draft.description,
          equals('Biblia Grande Version Lujo de letra grande...'));
      expect(draft.code, isNull);
      expect(draft.type, isNull);
      expect(draft.status, equals(PublicationStatus.draft));

      // Casos inválidos
      expect(
        () => Publication.quickDraft(name: 'Biblia', description: ''),
        throwsArgumentError,
      );
      expect(
        () => Publication.quickDraft(name: 'Biblia', description: '   '),
        throwsArgumentError,
      );
    });
  });
}
