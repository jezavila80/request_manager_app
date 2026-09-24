import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requesters/domain/services/requester_name_normalizer.dart';

void main() {
  group('RequesterNameNormalizer Tests', () {
    test('Normalizes various casing and diacritics of the same identity', () {
      const expected = 'maria soto';

      expect(RequesterNameNormalizer.normalize('María Soto'), equals(expected));
      expect(RequesterNameNormalizer.normalize('Maria Soto'), equals(expected));
      expect(RequesterNameNormalizer.normalize('maria soto'), equals(expected));
      expect(RequesterNameNormalizer.normalize('MARIA SOTO'), equals(expected));
      expect(RequesterNameNormalizer.normalize('  María   Soto '),
          equals(expected));
    });

    test('Identity comparison ignores case, accents and whitespace', () {
      final key1 = RequesterNameNormalizer.normalize('María Soto');
      final key2 = RequesterNameNormalizer.normalize('Maria Soto');
      final key3 = RequesterNameNormalizer.normalize('maria soto');
      final key4 = RequesterNameNormalizer.normalize('MARÍA SOTO');

      expect(key1, equals(key2));
      expect(key1, equals(key3));
      expect(key1, equals(key4));
    });

    test('Treats ñ explicitly as distinct from n and normalizes Ñ to ñ', () {
      final withEnne = RequesterNameNormalizer.normalize('Peña Nieto');
      final withEn = RequesterNameNormalizer.normalize('Pena Nieto');
      final withUpperEnne = RequesterNameNormalizer.normalize('PEÑA NIETO');

      expect(withEnne, equals('peña nieto'));
      expect(withEn, equals('pena nieto'));
      expect(withUpperEnne, equals('peña nieto'));

      // Crucial requirement: ñ is semantically preserved and distinct from n
      expect(withEnne, isNot(equals(withEn)));
    });

    test('Normalizes all common Spanish vowel diacritics including ü', () {
      expect(RequesterNameNormalizer.normalize('José Ángel'),
          equals('jose angel'));
      expect(RequesterNameNormalizer.normalize('Martín Güemes'),
          equals('martin guemes'));
      expect(RequesterNameNormalizer.normalize('Raúl Gómez'),
          equals('raul gomez'));
    });
  });
}
