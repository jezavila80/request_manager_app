import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/widgets/app_card.dart';
import 'package:request_manager_app/core/widgets/app_states.dart';
import 'package:request_manager_app/core/widgets/app_status_badge.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/publication_repository.dart';
import 'package:request_manager_app/features/publications/domain/services/publication_catalog_search_service.dart';
import 'package:request_manager_app/features/publications/presentation/pages/publication_detail_page.dart';
import 'package:request_manager_app/features/publications/presentation/pages/publications_page.dart';

class MockPublicationRepository implements PublicationRepository {
  List<Publication> mockActivePublications = [];
  List<Publication> mockCodeResults = [];
  List<Publication> mockNameResults = [];
  bool shouldThrow = false;

  @override
  Future<List<Publication>> getActivePublications() async {
    if (shouldThrow) throw Exception('Database error');
    return mockActivePublications;
  }

  @override
  Future<List<Publication>> searchByCode(String query, {int limit = 20}) async {
    if (shouldThrow) throw Exception('Database error');
    return mockCodeResults;
  }

  @override
  Future<List<Publication>> searchByName(String query, {int limit = 20}) async {
    if (shouldThrow) throw Exception('Database error');
    return mockNameResults;
  }

  @override
  Future<Publication> create(Publication publication) async => publication;

  @override
  Future<List<Publication>> getAll() async => mockActivePublications;

  @override
  Future<Publication?> getById(int id) async => null;

  @override
  Future<Publication?> findByExactCode(String code) async => null;

  @override
  Future<List<Publication>> findActiveByName(String name) async => [];
}

void main() {
  late MockPublicationRepository repository;
  late PublicationCatalogSearchService searchService;

  setUp(() {
    repository = MockPublicationRepository();
    searchService = PublicationCatalogSearchService(repository);
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: PublicationsPage(
          repository: repository,
          searchService: searchService,
        ),
      ),
    );
  }

  group('PublicationsPage Widget Tests', () {
    testWidgets('Renders header title and search field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Publicaciones'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
        'Renders list of publications with code, type and status badges',
        (tester) async {
      repository.mockActivePublications = [
        Publication(
          id: 1,
          name: 'Biblia de Referencia',
          code: 'RBI-8',
          type: 'Libro',
          isActive: true,
        ),
        Publication(
          id: 2,
          name: 'Folleto Informativo',
          code: null,
          type: 'Folleto',
          isActive: true,
        ),
      ];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Biblia de Referencia'), findsOneWidget);
      expect(find.text('RBI-8 · Libro'), findsOneWidget);
      expect(find.text('Folleto Informativo'), findsOneWidget);
      expect(find.text('-Sin código- · Folleto'), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsNWidgets(2));
    });

    testWidgets('Renders empty catalog message when repository is empty',
        (tester) async {
      repository.mockActivePublications = [];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Aún no hay publicaciones registradas'), findsOneWidget);
    });

    testWidgets('Renders search no results message when query has no matches',
        (tester) async {
      repository.mockActivePublications = [
        Publication(id: 1, name: 'Biblia', code: 'RBI-8', isActive: true),
      ];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron publicaciones para "inexistente"'),
          findsOneWidget);
    });

    testWidgets('Renders error state with retry action', (tester) async {
      repository.shouldThrow = true;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
          find.text('No se pudieron cargar las publicaciones'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      // Fix error and retry
      repository.shouldThrow = false;
      repository.mockActivePublications = [
        Publication(id: 1, name: 'Biblia', code: 'RBI-8', isActive: true),
      ];

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Biblia'), findsOneWidget);
    });

    testWidgets('Tapping publication card opens PublicationDetailPage',
        (tester) async {
      final pub = Publication(
        id: 1,
        name: 'Biblia de Referencia',
        code: 'RBI-8',
        type: 'Libro',
        isActive: true,
      );
      repository.mockActivePublications = [pub];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Biblia de Referencia'));
      await tester.pumpAndSettle();

      expect(find.byType(PublicationDetailPage), findsOneWidget);
      expect(find.text('Detalle de Publicación'), findsOneWidget);
    });

    group('Reduced Viewport (Keyboard Simulation) Tests', () {
      testWidgets(
          'Renders empty catalog in reduced viewport without layout overflow',
          (tester) async {
        tester.view.physicalSize = const Size(360, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        repository.mockActivePublications = [];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
            find.text('Aún no hay publicaciones registradas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'Renders search no results in reduced viewport without layout overflow',
          (tester) async {
        tester.view.physicalSize = const Size(360, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        repository.mockActivePublications = [
          Publication(id: 1, name: 'Biblia', code: 'RBI-8', isActive: true),
        ];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'inexistente');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('No se encontraron publicaciones para "inexistente"'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'Renders loading indicator in reduced viewport without layout overflow',
          (tester) async {
        tester.view.physicalSize = const Size(360, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AppLoadingIndicator(message: 'Cargando publicaciones...'),
            ),
          ),
        );

        expect(find.text('Cargando publicaciones...'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'Renders error state in reduced viewport without layout overflow',
          (tester) async {
        tester.view.physicalSize = const Size(360, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        repository.shouldThrow = true;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('No se pudieron cargar las publicaciones'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Renders list of items in reduced viewport and allows scroll',
          (tester) async {
        tester.view.physicalSize = const Size(360, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        repository.mockActivePublications = List.generate(
          10,
          (i) => Publication(
            id: i + 1,
            name: 'Publicación $i',
            code: 'CODE-$i',
            isActive: true,
          ),
        );

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Publicación 0'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Perform scroll
        await tester.fling(find.byType(ListView), const Offset(0, -300), 1000);
        await tester.pumpAndSettle();

        expect(find.byType(AppCard), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
