import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/widgets/app_status_badge.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';
import 'package:request_manager_app/features/publications/presentation/pages/publication_detail_page.dart';

void main() {
  Widget buildTestWidget(Publication pub) {
    return MaterialApp(
      home: PublicationDetailPage(publication: pub),
    );
  }

  group('PublicationDetailPage Widget Tests', () {
    testWidgets('Renders all fields for complete publication with code',
        (tester) async {
      final pub = Publication(
        id: 1,
        name: 'Biblia de Estudio',
        code: 'RBI-8',
        description: 'Biblia especial con referencias',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera 1960'),
        isActive: true,
      );

      await tester.pumpWidget(buildTestWidget(pub));

      expect(find.text('Detalle de Publicación'), findsOneWidget);
      expect(find.text('Biblia de Estudio'), findsOneWidget);
      expect(find.text('RBI-8'), findsOneWidget);
      expect(find.text('Biblia especial con referencias'), findsOneWidget);
      expect(find.text('Libro'), findsOneWidget);
      expect(find.text('Grande'), findsOneWidget);
      expect(find.text('Reina Valera 1960'), findsOneWidget);
      expect(find.text('Sí (Activa)'), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsOneWidget);
      expect(find.text('COMPLETE'), findsOneWidget);
    });

    testWidgets(
        'Renders -Sin código-, default descriptions and mapped TriState values',
        (tester) async {
      final pub = Publication(
        id: 2,
        name: 'Folleto Informativo',
        code: null,
        description: null,
        type: null,
        size: const TriStateValue.sinDefinir(),
        version: const TriStateValue.noAplica(),
        isActive: false,
      );

      await tester.pumpWidget(buildTestWidget(pub));

      expect(find.text('Folleto Informativo'), findsOneWidget);
      expect(find.text('-Sin código-'), findsOneWidget);
      expect(find.text('Sin descripción'), findsOneWidget);
      expect(find.text('Sin definir'), findsNWidgets(2)); // Type & Size
      expect(find.text('No aplica'), findsOneWidget); // Version
      expect(find.text('No (Inactiva)'), findsOneWidget);
      expect(find.text('DRAFT'), findsOneWidget);
    });
  });
}
