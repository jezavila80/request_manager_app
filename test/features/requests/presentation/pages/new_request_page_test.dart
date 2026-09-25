import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:request_manager_app/core/widgets/app_buttons.dart';
import 'package:request_manager_app/core/widgets/app_status_badge.dart';
import 'package:request_manager_app/features/design_system_preview/presentation/pages/design_system_preview_page.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/publication_status.dart';
import 'package:request_manager_app/features/publications/domain/publication_repository.dart';
import 'package:request_manager_app/features/publications/domain/services/publication_catalog_search_service.dart';
import 'package:request_manager_app/features/requesters/domain/requester.dart';
import 'package:request_manager_app/features/requesters/domain/requester_repository.dart';
import 'package:request_manager_app/features/requesters/domain/services/requester_name_normalizer.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_repository.dart';
import 'package:request_manager_app/features/requests/domain/usecases/add_publication_to_request_use_case.dart';
import 'package:request_manager_app/features/requests/domain/usecases/create_request_use_case.dart';
import 'package:request_manager_app/features/requests/presentation/pages/new_request_page.dart';

import '../../../../core/time/fixed_clock.dart';
import '../../../../helpers/test_publication_factory.dart';

class MockRequesterRepository implements RequesterRepository {
  List<Requester> requesters = [];
  bool shouldThrow = false;
  Completer<List<Requester>>? delayedSearchCompleter;
  int searchCallCount = 0;

  @override
  Future<Requester> create(Requester requester) async {
    if (shouldThrow) throw Exception('DB error');
    final saved = requester.copyWith(
      id: requesters.length + 1,
      normalizedName: RequesterNameNormalizer.normalize(requester.name),
    );
    requesters.add(saved);
    return saved;
  }

  @override
  Future<Requester?> getById(int id) async {
    final matches = requesters.where((r) => r.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<Requester?> findByNormalizedName(String normalizedName) async {
    final matches = requesters.where((r) => r.normalizedName == normalizedName);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<List<Requester>> searchActiveByName(String query,
      {int limit = 20}) async {
    searchCallCount++;
    if (shouldThrow) throw Exception('DB error');
    if (delayedSearchCompleter != null) {
      return await delayedSearchCompleter!.future;
    }
    final normalized = RequesterNameNormalizer.normalize(query);
    return requesters
        .where((r) => r.isActive && r.normalizedName.contains(normalized))
        .take(limit)
        .toList();
  }

  @override
  Future<List<Requester>> getAll() async => requesters;
}

class MockPublicationRepository implements PublicationRepository {
  List<Publication> activePublications = [];
  List<Publication> codeResults = [];
  List<Publication> nameResults = [];
  int searchByCodeCallCount = 0;
  int searchByNameCallCount = 0;
  bool shouldThrow = false;
  Completer<List<Publication>>? delayedSearchCompleter;

  @override
  Future<List<Publication>> getActivePublications() async {
    if (shouldThrow) throw Exception('DB error');
    return activePublications;
  }

  @override
  Future<List<Publication>> searchByCode(String query, {int limit = 20}) async {
    searchByCodeCallCount++;
    if (shouldThrow) throw Exception('DB error');
    if (delayedSearchCompleter != null) {
      return await delayedSearchCompleter!.future;
    }
    return codeResults;
  }

  @override
  Future<List<Publication>> searchByName(String query, {int limit = 20}) async {
    searchByNameCallCount++;
    if (shouldThrow) throw Exception('DB error');
    if (delayedSearchCompleter != null) {
      return await delayedSearchCompleter!.future;
    }
    return nameResults;
  }

  int _nextPubId = 100;
  bool shouldThrowOnCreate = false;
  final List<Publication> createdPublications = [];
  List<Publication> activeByNameResults = [];

  @override
  Future<Publication> create(Publication publication) async {
    if (shouldThrowOnCreate) throw Exception('DB error on create');
    final saved = publication.copyWith(id: publication.id ?? _nextPubId++);
    createdPublications.add(saved);
    return saved;
  }

  @override
  Future<List<Publication>> getAll() async => activePublications;

  @override
  Future<Publication?> getById(int id) async {
    for (final p in [...activePublications, ...createdPublications]) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Publication?> findByExactCode(String code) async {
    for (final p in [...activePublications, ...createdPublications]) {
      if (p.code?.toLowerCase() == code.toLowerCase()) return p;
    }
    return null;
  }

  @override
  Future<List<Publication>> findActiveByName(String name) async {
    if (activeByNameResults.isNotEmpty) return activeByNameResults;
    return activePublications
        .where((p) => p.name.trim().toLowerCase() == name.trim().toLowerCase())
        .toList();
  }
}

class MockRequestRepository implements RequestRepository {
  final List<Request> createdRequests = [];
  bool shouldThrow = false;

  @override
  Future<Request> create(Request request) async {
    if (shouldThrow) throw Exception('DB error');
    final saved = request.copyWith(id: createdRequests.length + 1);
    createdRequests.add(saved);
    return saved;
  }

  @override
  Future<List<Request>> getAll() async => createdRequests;

  @override
  Future<Request?> getById(int id) async =>
      createdRequests.firstWhere((r) => r.id == id);
}

void main() {
  late MockPublicationRepository pubRepo;
  late MockRequestRepository reqRepo;
  late MockRequesterRepository requesterRepo;
  late PublicationCatalogSearchService searchService;
  late FixedClock clock;
  late AddPublicationToRequestUseCase addUseCase;
  late CreateRequestUseCase createUseCase;

  final fixedTime = DateTime.utc(2026, 9, 22, 12, 0);

  final pubA = createTestPublication(
    id: 1,
    code: 'nwtls-S',
    name: 'Biblia Letra Grande Español',
    type: 'Biblia',
  );

  final pubB = createTestPublication(
    id: 2,
    code: 'wp26.1-S',
    name: 'La Atalaya',
    type: 'Revista',
  );

  setUp(() {
    pubRepo = MockPublicationRepository();
    reqRepo = MockRequestRepository();
    requesterRepo = MockRequesterRepository();
    searchService = PublicationCatalogSearchService(pubRepo);
    clock = FixedClock(fixedTime);
    addUseCase = AddPublicationToRequestUseCase(clock: clock);
    createUseCase = CreateRequestUseCase(repository: reqRepo);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: NewRequestPage(
        publicationRepository: pubRepo,
        searchService: searchService,
        addPublicationUseCase: addUseCase,
        createRequestUseCase: createUseCase,
        requestRepository: reqRepo,
        requesterRepository: requesterRepo,
        clock: clock,
      ),
    );
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  group('NewRequestPage — 20 Required Verification Points', () {
    testWidgets('1. Búsqueda no se ejecuta inmediatamente antes del debounce',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'bib');
      await tester.pump(const Duration(milliseconds: 100));

      expect(pubRepo.searchByCodeCallCount, equals(0));
      expect(pubRepo.searchByNameCallCount, equals(0));
    });

    testWidgets('2. Búsqueda se ejecuta después de ~300 ms', (tester) async {
      pubRepo.codeResults = [pubA];
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'bib');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(pubRepo.searchByCodeCallCount, equals(1));
      expect(pubRepo.searchByNameCallCount, equals(1));
    });

    testWidgets('3. Búsqueda utiliza la lógica combinada existente',
        (tester) async {
      pubRepo.codeResults = [pubA];
      pubRepo.nameResults = [pubB];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'pub');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byKey(Key('search_result_item_${pubA.id}')), findsOneWidget);
      expect(find.byKey(Key('search_result_item_${pubB.id}')), findsOneWidget);
    });

    testWidgets(
        '4. Búsqueda vacía no muestra catálogo completo en contexto autocomplete',
        (tester) async {
      pubRepo.activePublications = [pubA, pubB];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byKey(Key('search_result_item_${pubA.id}')), findsNothing);
      expect(find.byKey(Key('search_result_item_${pubB.id}')), findsNothing);

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'algo');
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.byKey(Key('search_result_item_${pubA.id}')), findsNothing);
      expect(find.byKey(Key('search_result_item_${pubB.id}')), findsNothing);
    });

    testWidgets('5. Resultados muestran publicación correcta', (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Biblia Letra Grande Español'), findsOneWidget);
      expect(find.text('nwtls-S · Biblia'), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsOneWidget);
      expect(find.text('COMPLETE'), findsOneWidget);
    });

    testWidgets('6. Seleccionar resultado establece Publication seleccionada',
        (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));

      expect(
          find.byKey(const Key('selected_publication_card')), findsOneWidget);
      expect(find.text('Publicación seleccionada'), findsOneWidget);
      expect(find.byKey(Key('search_result_item_${pubA.id}')), findsNothing);
    });

    testWidgets('7. Cantidad inicial = 1', (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));

      expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);
    });

    testWidgets('8. Agregar publicación nueva actualiza el Request',
        (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.currentRequest, isNotNull);
      expect(state.currentRequest!.items.length, equals(1));
      expect(state.currentRequest!.items.first.publicationId, equals(pubA.id));
      expect(state.currentRequest!.items.first.quantityRequested, equals(1));
    });

    testWidgets('9. Aparece en resumen de artículos', (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      expect(find.byKey(const Key('request_items_summary')), findsOneWidget);
      expect(find.text('Biblia Letra Grande Español'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('10. Publicación repetida solicita confirmación',
        (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Agregar por primera vez con cantidad 2
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '2');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      // Intentar agregar pubA nuevamente con cantidad 3
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '3');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));
      await tester.pumpAndSettle();

      expect(find.text('Publicación ya agregada'), findsOneWidget);
      expect(
          find.text(
              '"Biblia Letra Grande Español" ya está agregada con cantidad 2.'),
          findsOneWidget);
      expect(find.text('¿Deseas agregar 3 más?'), findsOneWidget);
      expect(find.text('Nueva cantidad: 5'), findsOneWidget);
    });

    testWidgets('11. Cancelar mantiene Request intacto', (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Agregar primera vez con cantidad 2
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '2');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      // Segunda vez con 3
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '3');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('confirm_accumulation_cancel_button')));
      await tester.pumpAndSettle();

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.currentRequest!.items.length, equals(1));
      expect(state.currentRequest!.items.first.quantityRequested, equals(2));
    });

    testWidgets('12. Confirmar acumula cantidad', (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Agregar primera vez con 2
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '2');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      // Agregar segunda vez con 3
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '3');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('confirm_accumulation_confirm_button')));
      await tester.pumpAndSettle();

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.currentRequest!.items.first.quantityRequested, equals(5));
    });

    testWidgets('13. Verificación aritmética de acumulación: 2 + 3 = 5',
        (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 2 iniciales
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '2');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      // 3 adicionales
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '3');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('confirm_accumulation_confirm_button')));
      await tester.pumpAndSettle();

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.currentRequest!.items.first.quantityRequested, equals(5));
      expect(state.currentRequest!.totalQuantityRequested, equals(5));
    });

    testWidgets('14. Sigue existiendo un solo RequestItem', (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('confirm_accumulation_confirm_button')));
      await tester.pumpAndSettle();

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.currentRequest!.items.length, equals(1));
    });

    testWidgets(
        '15. Selección/búsqueda se limpia después de agregar correctamente',
        (tester) async {
      pubRepo.codeResults = [pubA];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.selectedPublication, isNull);
      expect(find.byKey(const Key('selected_publication_card')), findsNothing);
      expect(find.widgetWithText(TextFormField, ''), findsWidgets);
    });

    testWidgets(
        '16. Respuesta obsoleta no reemplaza resultados de búsqueda más reciente',
        (tester) async {
      final slowCompleter = Completer<List<Publication>>();
      pubRepo.delayedSearchCompleter = slowCompleter;

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'bib');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      pubRepo.delayedSearchCompleter = null;
      pubRepo.codeResults = [pubB];
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'ata');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      slowCompleter.complete([pubA]);
      await tester.pump();

      expect(find.byKey(Key('search_result_item_${pubB.id}')), findsOneWidget);
      expect(find.byKey(Key('search_result_item_${pubA.id}')), findsNothing);
    });

    testWidgets('17. Estado sin resultados funciona', (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'noexiste');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
          find.text(
              'No se encontraron publicaciones activas con el criterio ingresado'),
          findsOneWidget);
    });

    testWidgets('18. Error de búsqueda se representa sin romper la pantalla',
        (tester) async {
      pubRepo.shouldThrow = true;

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'error');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Error al buscar publicaciones'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('19. Flujo existente del catálogo continúa funcionando',
        (tester) async {
      pubRepo.codeResults = [pubA];
      final results = await searchService.search('nwtls');
      expect(results.length, equals(1));
      expect(results.first.name, equals('Biblia Letra Grande Español'));
    });

    testWidgets(
        '20. Request completo llega correctamente a CreateRequestUseCase',
        (tester) async {
      pubRepo.codeResults = [pubA];
      final req1 = Requester(
        id: 1,
        name: 'Congregación Central',
        normalizedName: 'congregacion central',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [req1];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'Congregación');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('requester_search_result_${req1.id}')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('notes_field')), 'Entrega urgente');

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tester.enterText(find.byKey(const Key('quantity_field')), '4');
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      await tapVisible(tester, find.byKey(const Key('save_request_button')));
      await tester.pumpAndSettle();

      expect(reqRepo.createdRequests.length, equals(1));
      final saved = reqRepo.createdRequests.first;
      expect(saved.requesterId, equals(req1.id));
      expect(saved.notes, equals('Entrega urgente'));
      expect(saved.items.length, equals(1));
      expect(saved.items.first.publicationId, equals(pubA.id));
      expect(saved.items.first.quantityRequested, equals(4));
    });

    testWidgets(
        '21. Navegación: Botón Nuevo Pedido en pestaña Pedidos abre NewRequestPage',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DesignSystemPreviewPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Cambiar a pestaña Pedidos
      await tester.tap(find.byIcon(Icons.description_outlined));
      await tester.pumpAndSettle();

      // Verificar y tocar botón Nuevo Pedido
      expect(find.byKey(const Key('btn_nuevo_pedido')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_nuevo_pedido')));
      await tester.pumpAndSettle();

      // Debe mostrarse NewRequestPage
      expect(find.byType(NewRequestPage), findsOneWidget);
      expect(find.text('Nuevo Pedido'), findsOneWidget);
    });
  });

  group('NewRequestPage — Requester Selection & Creation Tests (Fase 2.6.1)',
      () {
    testWidgets('1. Requester search does not execute before 300 ms debounce',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'mar');
      await tester.pump(const Duration(milliseconds: 100));

      expect(requesterRepo.searchCallCount, equals(0));
    });

    testWidgets('2. Requester search executes after 300 ms debounce',
        (tester) async {
      final r = Requester(
        id: 1,
        name: 'María Soto',
        normalizedName: 'maria soto',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'mar');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(requesterRepo.searchCallCount, equals(1));
      expect(
          find.byKey(Key('requester_search_result_${r.id}')), findsOneWidget);
    });

    testWidgets('3. Empty or whitespace query clears requester search results',
        (tester) async {
      final r = Requester(
        id: 1,
        name: 'María Soto',
        normalizedName: 'maria soto',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'mar');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
          find.byKey(Key('requester_search_result_${r.id}')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), '   ');
      await tester.pump();
      expect(find.byKey(Key('requester_search_result_${r.id}')), findsNothing);
    });

    testWidgets(
        '4. Race condition protection ignores stale requester search responses',
        (tester) async {
      final r1 = Requester(
        id: 1,
        name: 'María Soto',
        normalizedName: 'maria soto',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      final r2 = Requester(
        id: 2,
        name: 'Juan Pérez',
        normalizedName: 'juan perez',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r1, r2];

      final completer1 = Completer<List<Requester>>();
      requesterRepo.delayedSearchCompleter = completer1;

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Query 1
      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'mar');
      await tester.pump(const Duration(milliseconds: 300));

      // Query 2 without delay
      requesterRepo.delayedSearchCompleter = null;
      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'juan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Resolve delayed Query 1
      completer1.complete([r1]);
      await tester.pump();

      // UI should reflect Query 2 (juan) and NOT stale Query 1 (mar)
      expect(
          find.byKey(Key('requester_search_result_${r2.id}')), findsOneWidget);
      expect(find.byKey(Key('requester_search_result_${r1.id}')), findsNothing);
    });

    testWidgets(
        '5. Selecting a requester displays selected_requester_card and hides search field',
        (tester) async {
      final r = Requester(
        id: 5,
        name: 'Pedro Almodóvar',
        normalizedName: 'pedro almodovar',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'pedro');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(Key('requester_search_result_${r.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('selected_requester_card')), findsOneWidget);
      expect(find.text('Pedro Almodóvar'), findsOneWidget);
      expect(find.byKey(const Key('search_requester_field')), findsNothing);
    });

    testWidgets(
        '6. Changing requester resets selection and restores search field',
        (tester) async {
      final r = Requester(
        id: 5,
        name: 'Pedro Almodóvar',
        normalizedName: 'pedro almodovar',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'pedro');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('requester_search_result_${r.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('change_requester_button')), findsOneWidget);
      await tapVisible(
          tester, find.byKey(const Key('change_requester_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('selected_requester_card')), findsNothing);
      expect(find.byKey(const Key('search_requester_field')), findsOneWidget);
    });

    testWidgets('7. Validation on creation: rejects name with < 2 words',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'María');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byKey(const Key('create_requester_button')), findsOneWidget);
      await tapVisible(
          tester, find.byKey(const Key('create_requester_button')));
      await tester.pumpAndSettle();

      expect(find.text('Nombre inválido'), findsOneWidget);
      expect(
          find.text(
              'El nombre del solicitante debe contener al menos dos palabras.'),
          findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Nombre inválido'), findsNothing);
    });

    testWidgets(
        '8. Exact duplicate detection shows blocking dialog with option to select existing',
        (tester) async {
      final r = Requester(
        id: 1,
        name: 'María Soto',
        normalizedName: 'maria soto',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Enter variant with different accents / casing
      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'Maria Soto');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_requester_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe el solicitante'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.textContaining('María Soto')),
          findsOneWidget);
      expect(find.byKey(const Key('select_exact_duplicate_button')),
          findsOneWidget);
    });

    testWidgets(
        '9. Selecting existing from exact duplicate dialog selects the requester',
        (tester) async {
      final r = Requester(
        id: 1,
        name: 'María Soto',
        normalizedName: 'maria soto',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'Maria Soto');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_requester_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('select_exact_duplicate_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('selected_requester_card')), findsOneWidget);
      expect(find.text('María Soto'), findsOneWidget);
    });

    testWidgets(
        '10. Possible duplicate detection shows warning dialog with candidates',
        (tester) async {
      final r = Requester(
        id: 1,
        name: 'María Soto',
        normalizedName: 'maria soto',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Typo "Mari Soto" -> similarity high
      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'Mari Soto');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_requester_button')));
      await tester.pumpAndSettle();

      expect(find.text('¿Es alguno de estos solicitantes?'), findsOneWidget);
      expect(find.text('María Soto'), findsOneWidget);
      expect(find.byKey(const Key('confirm_create_new_requester_button')),
          findsOneWidget);
    });

    testWidgets(
        '11. Selecting candidate from possible duplicate dialog selects it',
        (tester) async {
      final r = Requester(
        id: 1,
        name: 'María Soto',
        normalizedName: 'maria soto',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'Mari Soto');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_requester_button')));
      await tester.pumpAndSettle();

      // Tap 'Seleccionar' for candidate
      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('selected_requester_card')), findsOneWidget);
      expect(find.text('María Soto'), findsOneWidget);
    });

    testWidgets(
        '12. Confirming new requester in possible duplicate dialog creates and selects it',
        (tester) async {
      final r = Requester(
        id: 1,
        name: 'María Soto',
        normalizedName: 'maria soto',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'Mari Soto');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_requester_button')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('confirm_create_new_requester_button')));
      await tester.pumpAndSettle();

      expect(requesterRepo.requesters.length, equals(2));
      expect(find.byKey(const Key('selected_requester_card')), findsOneWidget);
      expect(find.text('Mari Soto'), findsOneWidget);
    });

    testWidgets(
        '13. Creating requester with clean name and no duplicates succeeds directly',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'Carlos Méndez');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_requester_button')));
      await tester.pumpAndSettle();

      expect(requesterRepo.requesters.length, equals(1));
      expect(requesterRepo.requesters.first.name, equals('Carlos Méndez'));
      expect(find.byKey(const Key('selected_requester_card')), findsOneWidget);
      expect(find.text('Carlos Méndez'), findsOneWidget);
    });

    testWidgets(
        '14. Save request button is disabled without selected requester',
        (tester) async {
      pubRepo.codeResults = [pubA];
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Add item without selecting requester
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      final saveBtnFinder = find.byKey(const Key('save_request_button'));
      final saveButton = tester.widget<AppPrimaryButton>(saveBtnFinder);
      expect(saveButton.onPressed, isNull);
    });

    testWidgets(
        '15. Save request button is disabled with requester selected but no items',
        (tester) async {
      final r = Requester(
        id: 1,
        name: 'José Ruiz',
        normalizedName: 'jose ruiz',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Select requester
      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'jose');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('requester_search_result_${r.id}')));
      await tester.pumpAndSettle();

      final saveBtnFinder = find.byKey(const Key('save_request_button'));
      final saveButton = tester.widget<AppPrimaryButton>(saveBtnFinder);
      expect(saveButton.onPressed, isNull);
    });

    testWidgets(
        '16. Save request button is enabled with both requester selected and valid items',
        (tester) async {
      pubRepo.codeResults = [pubA];
      final r = Requester(
        id: 1,
        name: 'José Ruiz',
        normalizedName: 'jose ruiz',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );
      requesterRepo.requesters = [r];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Select requester
      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'jose');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('requester_search_result_${r.id}')));
      await tester.pumpAndSettle();

      // Add item
      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(Key('search_result_item_${pubA.id}')));
      await tapVisible(tester, find.byKey(const Key('add_publication_button')));

      final saveBtnFinder = find.byKey(const Key('save_request_button'));
      final saveButton = tester.widget<AppPrimaryButton>(saveBtnFinder);
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('17. Search error displays friendly error message',
        (tester) async {
      requesterRepo.shouldThrow = true;

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'error');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Error al buscar solicitantes'), findsOneWidget);
    });

    testWidgets(
        '18. Preserves accents and ñ in display name and normalized form',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'José Peña');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_requester_button')));
      await tester.pumpAndSettle();

      expect(requesterRepo.requesters.length, equals(1));
      final created = requesterRepo.requesters.first;
      expect(created.name, equals('José Peña'));
      expect(created.normalizedName, equals('jose peña'));
      expect(find.text('José Peña'), findsOneWidget);
    });
  });

  group('NewRequestPage — Quick Draft Creation Tests (Fase 2.7)', () {
    testWidgets('1. Query vacía no ofrece crear Draft', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byKey(const Key('create_quick_draft_button')), findsNothing);
    });

    testWidgets(
        '2. Búsqueda con resultados muestra resultados normales y no muestra botón de borrador',
        (tester) async {
      pubRepo.codeResults = [pubA];
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'nwtls');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byKey(Key('search_result_item_${pubA.id}')), findsOneWidget);
      expect(find.byKey(const Key('create_quick_draft_button')), findsNothing);
    });

    testWidgets(
        '3. Búsqueda sin resultados ofrece crear publicación en borrador',
        (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'Inexistente');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
          find.byKey(const Key('create_quick_draft_button')), findsOneWidget);
      expect(find.text('+ Crear publicación en borrador'), findsOneWidget);
    });

    testWidgets('4. Abrir Quick Draft precarga el nombre desde la búsqueda',
        (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.byKey(const Key('search_publication_field')),
          'Folleto Especial');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_draft_dialog')), findsOneWidget);
      final nameField = tester.widget<TextFormField>(find.descendant(
        of: find.byKey(const Key('quick_draft_name_field')),
        matching: find.byType(TextFormField),
      ));
      expect(nameField.controller?.text, equals('Folleto Especial'));
    });

    testWidgets(
        '5. Nombre inválido (vacío o espacios) no persiste y muestra error de validación',
        (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'algo');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('quick_draft_name_field')),
            matching: find.byType(TextFormField),
          ),
          '   ');
      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pump();

      expect(find.text('El nombre de la publicación no puede estar vacío.'),
          findsOneWidget);
      expect(pubRepo.createdPublications, isEmpty);
    });

    testWidgets(
        '6-10. Crear Draft válido persiste en repo con ID, code null, status DRAFT y timestamps UTC',
        (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'Folleto Nuevo');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('quick_draft_type_field')),
            matching: find.byType(TextFormField),
          ),
          'Folleto');
      await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('quick_draft_description_field')),
            matching: find.byType(TextFormField),
          ),
          'Descripción de prueba');

      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pumpAndSettle();

      expect(pubRepo.createdPublications.length, equals(1));
      final created = pubRepo.createdPublications.first;

      expect(created.id, isNotNull);
      expect(created.id, greaterThan(0));
      expect(created.code, isNull);
      expect(created.status, equals(PublicationStatus.draft));
      expect(created.createdAt, equals(fixedTime));
      expect(created.updatedAt, equals(fixedTime));
      expect(created.createdAt.isUtc, isTrue);
      expect(created.updatedAt.isUtc, isTrue);
    });

    testWidgets(
        '11-14. Tras creación modal cierra, Draft queda seleccionado con cantidad 1 y sin agregarse automáticamente',
        (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.byKey(const Key('search_publication_field')),
          'Revista Especial');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_draft_dialog')), findsNothing);

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.selectedPublication, isNotNull);
      expect(state.selectedPublication!.name, equals('Revista Especial'));
      expect(
          find.byKey(const Key('selected_publication_card')), findsOneWidget);

      final qtyField = tester.widget<TextFormField>(find.descendant(
        of: find.byKey(const Key('quantity_field')),
        matching: find.byType(TextFormField),
      ));
      expect(qtyField.controller?.text, equals('1'));

      expect(state.currentRequest, isNull);
    });

    testWidgets(
        '15-16. Al pulsar Agregar añade RequestItem y al guardar pedido referencia el publicationId persistido',
        (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];
      requesterRepo.requesters = [
        Requester(
          id: 1,
          name: 'Juan Perez',
          normalizedName: 'juan perez',
          isActive: true,
          createdAt: fixedTime,
          updatedAt: fixedTime,
        ),
      ];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_requester_field')), 'Juan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(const Key('requester_search_result_1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search_publication_field')),
          'Manual Operativo');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pumpAndSettle();

      final createdPub = pubRepo.createdPublications.first;

      await tapVisible(tester, find.byKey(const Key('add_publication_button')));
      await tester.pumpAndSettle();

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.currentRequest, isNotNull);
      expect(state.currentRequest!.items.length, equals(1));
      expect(state.currentRequest!.items.first.publicationId,
          equals(createdPub.id));

      await tapVisible(tester, find.byKey(const Key('save_request_button')));
      await tester.pumpAndSettle();

      expect(reqRepo.createdRequests.length, equals(1));
      final savedReq = reqRepo.createdRequests.first;
      expect(savedReq.items.first.publicationId, equals(createdPub.id));
    });

    testWidgets(
        '17. possibleDuplicate muestra diálogo de advertencia con candidatos',
        (tester) async {
      final existingCandidate = createTestPublication(
        id: 77,
        name: 'Tratado Paz',
        type: 'Tratado',
      );
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];
      pubRepo.activePublications = [existingCandidate];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'Tratado Paz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('possible_duplicate_dialog')), findsOneWidget);
      expect(find.text('¿Es alguna de estas publicaciones?'), findsOneWidget);
      expect(find.byKey(Key('duplicate_match_item_${existingCandidate.id}')),
          findsOneWidget);
    });

    testWidgets(
        '18-19. Elegir existente no crea nuevo Draft y deja seleccionada la existente',
        (tester) async {
      final existingCandidate = createTestPublication(
        id: 88,
        name: 'Tratado Vida',
        type: 'Tratado',
      );
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];
      pubRepo.activePublications = [existingCandidate];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'Tratado Vida');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find
          .byKey(Key('select_existing_pub_${existingCandidate.id}_button')));
      await tester.pumpAndSettle();

      expect(pubRepo.createdPublications, isEmpty);

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.selectedPublication?.id, equals(existingCandidate.id));
      expect(state.selectedPublication?.name, equals(existingCandidate.name));
    });

    testWidgets(
        '20-21. Confirmar crear de todos modos persiste nuevo Draft sin alterar publicación existente',
        (tester) async {
      final existingCandidate = createTestPublication(
        id: 99,
        name: 'Tratado Esperanza',
        type: 'Tratado',
      );
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];
      pubRepo.activePublications = [existingCandidate];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.byKey(const Key('search_publication_field')),
          'Tratado Esperanza');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_create_anyway_button')));
      await tester.pumpAndSettle();

      expect(pubRepo.createdPublications.length, equals(1));
      final newDraft = pubRepo.createdPublications.first;
      expect(newDraft.name, equals('Tratado Esperanza'));
      expect(newDraft.id, isNot(equals(existingCandidate.id)));

      final existingInRepo =
          pubRepo.activePublications.firstWhere((p) => p.id == 99);
      expect(existingInRepo.name, equals('Tratado Esperanza'));
      expect(existingInRepo.id, equals(99));

      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.selectedPublication?.id, equals(newDraft.id));
    });

    testWidgets('22. Cancelar Quick Draft no persiste nada y cierra modal',
        (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(find.byKey(const Key('search_publication_field')),
          'Borrador Cancelar');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_draft_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_draft_dialog')), findsNothing);
      expect(pubRepo.createdPublications, isEmpty);
      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.selectedPublication, isNull);
    });

    testWidgets(
        '23-24. Error de persistencia muestra mensaje amigable, no selecciona publicación y permite reintentar',
        (tester) async {
      pubRepo.codeResults = [];
      pubRepo.nameResults = [];
      pubRepo.shouldThrowOnCreate = true;

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('search_publication_field')), 'Borrador Error');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapVisible(
          tester, find.byKey(const Key('create_quick_draft_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_draft_error_banner')), findsOneWidget);
      expect(
          find.text(
              'Error al guardar la publicación en borrador. Intente nuevamente.'),
          findsOneWidget);
      final state =
          tester.state<NewRequestPageState>(find.byType(NewRequestPage));
      expect(state.selectedPublication, isNull);

      pubRepo.shouldThrowOnCreate = false;
      await tester.tap(find.byKey(const Key('quick_draft_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_draft_dialog')), findsNothing);
      expect(pubRepo.createdPublications.length, equals(1));
      expect(state.selectedPublication?.name, equals('Borrador Error'));
    });
  });
}
