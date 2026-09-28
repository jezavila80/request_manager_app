import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/widgets/app_states.dart';

import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_list_item.dart';
import 'package:request_manager_app/features/requests/domain/request_repository.dart';
import 'package:request_manager_app/features/requests/presentation/pages/new_request_page.dart';
import 'package:request_manager_app/features/requests/presentation/pages/requests_page.dart';
import 'package:request_manager_app/features/requests/presentation/widgets/request_list_item_card.dart';
import '../../../../helpers/test_request_factory.dart';

class MockRequestRepository implements RequestRepository {
  List<RequestListItem> itemsToReturn = [];
  bool shouldThrow = false;
  String throwMessage = 'Database failure';
  Completer<List<RequestListItem>>? completer;
  int getRequestListCallCount = 0;

  @override
  Future<Request> create(Request request) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Request>> getAll() async {
    throw UnimplementedError();
  }

  @override
  Future<Request?> getById(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<List<RequestListItem>> getRequestList() async {
    getRequestListCallCount++;
    if (completer != null) {
      return await completer!.future;
    }
    if (shouldThrow) {
      throw Exception(throwMessage);
    }
    return itemsToReturn;
  }
}

void main() {
  late MockRequestRepository mockRepository;

  setUp(() {
    mockRepository = MockRequestRepository();
  });

  Widget buildWidget({Size? screenSize}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize ?? const Size(400, 800),
        ),
        child: Scaffold(
          body: RequestsPage(repository: mockRepository),
        ),
      ),
    );
  }

  group('RequestsPage Presentation & Widget Tests (Phase 2.8)', () {
    testWidgets('1. Displays loading indicator while requests are loading',
        (tester) async {
      mockRepository.completer = Completer<List<RequestListItem>>();

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('Cargando pedidos...'), findsOneWidget);

      mockRepository.completer!.complete([]);
      await tester.pumpAndSettle();

      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('2. Displays empty state when no requests are registered',
        (tester) async {
      mockRepository.itemsToReturn = [];

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('No hay pedidos registrados.'), findsOneWidget);
      expect(find.byKey(const Key('btn_nuevo_pedido')), findsOneWidget);
    });

    testWidgets(
        '3. Displays error state with retry button and recovers on retry',
        (tester) async {
      mockRepository.shouldThrow = true;

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.text('No se pudieron cargar los pedidos.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      // Now fix repository and tap retry
      mockRepository.shouldThrow = false;
      mockRepository.itemsToReturn = [
        RequestListItem(
          requestId: 1,
          requesterId: 10,
          requesterName: 'Carlos Ruiz',
          createdAt: DateTime.utc(2026, 9, 24, 12, 0),
          publicationCount: 2,
          quantityRequested: 5,
          quantityFulfilled: 0,
        ),
      ];

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorState), findsNothing);
      expect(find.text('Carlos Ruiz'), findsOneWidget);
      expect(find.text('Pedido #1'), findsOneWidget);
    });

    testWidgets(
        '4. Displays list with solicitante, badges (pending, partial, complete), dates and quantities',
        (tester) async {
      mockRepository.itemsToReturn = [
        RequestListItem(
          requestId: 31,
          requesterId: 1,
          requesterName: 'Juan Pérez',
          createdAt: DateTime.utc(2026, 9, 23, 10, 0),
          publicationCount: 2,
          quantityRequested: 7,
          quantityFulfilled: 0,
        ),
        RequestListItem(
          requestId: 27,
          requesterId: 2,
          requesterName: 'María Soto',
          createdAt: DateTime.utc(2026, 9, 24, 10, 0),
          publicationCount: 4,
          quantityRequested: 8,
          quantityFulfilled: 3,
        ),
        RequestListItem(
          requestId: 19,
          requesterId: 3,
          requesterName: 'Congregación La Calma',
          createdAt: DateTime.utc(2026, 9, 15, 10, 0),
          publicationCount: 1,
          quantityRequested: 12,
          quantityFulfilled: 12,
        ),
      ];

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(RequestListItemCard), findsNWidgets(3));

      // Item 1: Juan Pérez (Pending)
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.text('Pedido #31'), findsOneWidget);
      expect(find.text('2 publicaciones · 0 de 7 surtidas'), findsOneWidget);

      // Item 2: María Soto (Partial)
      expect(find.text('María Soto'), findsOneWidget);
      expect(find.text('PARCIAL'), findsOneWidget);
      expect(find.text('Pedido #27'), findsOneWidget);
      expect(find.text('4 publicaciones · 3 de 8 surtidas'), findsOneWidget);

      // Item 3: Congregación La Calma (Fulfilled) - singular "1 publicación"
      expect(find.text('Congregación La Calma'), findsOneWidget);
      expect(find.text('COMPLETO'), findsOneWidget);
      expect(find.text('Pedido #19'), findsOneWidget);
      expect(find.text('1 publicación · 12 de 12 surtidas'), findsOneWidget);
    });

    testWidgets('5. Handles extremely long requester name without overflow',
        (tester) async {
      mockRepository.itemsToReturn = [
        RequestListItem(
          requestId: 99,
          requesterId: 5,
          requesterName:
              'Hermano con un nombre extremadamente largo que sobrepasa el ancho normal de pantalla para verificar elipsis',
          createdAt: DateTime.utc(2026, 9, 24, 10, 0),
          publicationCount: 10,
          quantityRequested: 50,
          quantityFulfilled: 25,
        ),
      ];

      await tester.pumpWidget(buildWidget(screenSize: const Size(320, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RequestListItemCard), findsOneWidget);
    });

    testWidgets(
        '6. Navigates to NewRequestPage from btn_nuevo_pedido and refreshes on return with result',
        (tester) async {
      mockRepository.itemsToReturn = [];

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(mockRepository.getRequestListCallCount, equals(1));
      expect(find.byKey(const Key('btn_nuevo_pedido')), findsOneWidget);

      // Tap to navigate to NewRequestPage
      await tester.tap(find.byKey(const Key('btn_nuevo_pedido')));
      await tester.pumpAndSettle();

      // NewRequestPage is opened
      expect(find.byType(NewRequestPage), findsOneWidget);

      // Add new item to mock repository so refreshed list will have it
      mockRepository.itemsToReturn = [
        RequestListItem(
          requestId: 101,
          requesterId: 1,
          requesterName: 'Nuevo Solicitante',
          createdAt: DateTime.utc(2026, 9, 27, 10, 0),
          publicationCount: 1,
          quantityRequested: 3,
          quantityFulfilled: 0,
        ),
      ];

      // Simulate pop from NewRequestPage with saved Request
      final dummySavedRequest = createTestRequest(id: 101, requesterId: 1);
      Navigator.of(tester.element(find.byType(NewRequestPage)))
          .pop(dummySavedRequest);

      await tester.pumpAndSettle();

      // We should be back on RequestsPage and list should be refreshed
      expect(find.byType(RequestsPage), findsOneWidget);
      expect(mockRepository.getRequestListCallCount, equals(2));
      expect(find.text('Nuevo Solicitante'), findsOneWidget);
      expect(find.text('Pedido #101'), findsOneWidget);
    });
  });
}
