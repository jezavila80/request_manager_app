import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_exceptions.dart';
import 'package:request_manager_app/features/requests/domain/request_fulfillment_status.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';

void main() {
  group('Request Domain Entity Tests', () {
    final tCreatedAt = DateTime(2026, 9, 6, 10, 0);
    final tUpdatedAt = DateTime(2026, 9, 6, 10, 30);

    test(
        'Creates valid Request with trimmed requestedBy and unmodifiable items',
        () {
      final item1 = RequestItem(publicationId: 1, quantityRequested: 5);
      final item2 = RequestItem(publicationId: 2, quantityRequested: 10);

      final request = Request(
        id: 100,
        requestedBy: '  Juan Pérez  ',
        items: [item1, item2],
        notes: '  Entregar por la mañana  ',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      expect(request.id, equals(100));
      expect(request.requestedBy, equals('Juan Pérez'));
      expect(request.notes, equals('Entregar por la mañana'));
      expect(request.items.length, equals(2));
      expect(request.createdAt, equals(tCreatedAt));
      expect(request.updatedAt, equals(tUpdatedAt));

      // Check unmodifiable list protection
      expect(
        () => request.items.add(
          RequestItem(publicationId: 3, quantityRequested: 1),
        ),
        throwsUnsupportedError,
      );
    });

    test('Trims notes and converts blank string to null', () {
      final request = Request(
        requestedBy: 'María',
        notes: '   ',
      );
      expect(request.notes, isNull);
    });

    test('Throws ArgumentError if requestedBy is empty or only whitespace', () {
      expect(
        () => Request(requestedBy: ''),
        throwsArgumentError,
      );
      expect(
        () => Request(requestedBy: '   '),
        throwsArgumentError,
      );
    });

    test('Throws ArgumentError if id <= 0', () {
      expect(
        () => Request(id: 0, requestedBy: 'Carlos'),
        throwsArgumentError,
      );
      expect(
        () => Request(id: -5, requestedBy: 'Carlos'),
        throwsArgumentError,
      );
    });

    test('Throws ArgumentError if updatedAt is before createdAt', () {
      final created = DateTime(2026, 9, 6, 12, 0);
      final earlier = DateTime(2026, 9, 6, 11, 0);

      expect(
        () => Request(
          requestedBy: 'Pedro',
          createdAt: created,
          updatedAt: earlier,
        ),
        throwsArgumentError,
      );
    });

    test(
        'Throws DuplicatePublicationInRequestException if initial items contain duplicate publicationId',
        () {
      final item1 = RequestItem(publicationId: 8, quantityRequested: 5);
      final item2 = RequestItem(publicationId: 8, quantityRequested: 3);

      expect(
        () => Request(
          requestedBy: 'Ana',
          items: [item1, item2],
        ),
        throwsA(isA<DuplicatePublicationInRequestException>()),
      );
    });

    group('Calculated Properties & Totals Tests', () {
      test(
          'Calculates totalQuantityRequested and totalQuantityFulfilled correctly',
          () {
        final item1 = RequestItem(
          publicationId: 1,
          quantityRequested: 10,
          quantityFulfilled: 10,
        );
        final item2 = RequestItem(
          publicationId: 2,
          quantityRequested: 5,
          quantityFulfilled: 2,
        );
        final item3 = RequestItem(
          publicationId: 3,
          quantityRequested: 3,
          quantityFulfilled: 0,
        );

        final request = Request(
          requestedBy: 'Lucía',
          items: [item1, item2, item3],
        );

        expect(request.totalQuantityRequested, equals(18));
        expect(request.totalQuantityFulfilled, equals(12));
        expect(request.isValidForOrder, isTrue);
      });

      test('Returns 0 totals and isValidForOrder = false for empty request',
          () {
        final request = Request(requestedBy: 'Mateo', items: []);

        expect(request.totalQuantityRequested, equals(0));
        expect(request.totalQuantityFulfilled, equals(0));
        expect(request.isValidForOrder, isFalse);
      });
    });

    group('Fulfillment Status Calculation Tests', () {
      test('Returns PENDING for empty request (documented baseline behavior)',
          () {
        final request = Request(requestedBy: 'Sofia', items: []);
        expect(
          request.fulfillmentStatus,
          equals(RequestFulfillmentStatus.pending),
        );
      });

      test('Returns PENDING when all items have quantityFulfilled == 0', () {
        final item1 = RequestItem(
          publicationId: 1,
          quantityRequested: 5,
          quantityFulfilled: 0,
        );
        final item2 = RequestItem(
          publicationId: 2,
          quantityRequested: 10,
          quantityFulfilled: 0,
        );

        final request = Request(
          requestedBy: 'Sofia',
          items: [item1, item2],
        );

        expect(
          request.fulfillmentStatus,
          equals(RequestFulfillmentStatus.pending),
        );
      });

      test(
          'Returns FULFILLED when all items have quantityFulfilled == quantityRequested',
          () {
        final item1 = RequestItem(
          publicationId: 1,
          quantityRequested: 5,
          quantityFulfilled: 5,
        );
        final item2 = RequestItem(
          publicationId: 2,
          quantityRequested: 10,
          quantityFulfilled: 10,
        );

        final request = Request(
          requestedBy: 'Sofia',
          items: [item1, item2],
        );

        expect(
          request.fulfillmentStatus,
          equals(RequestFulfillmentStatus.fulfilled),
        );
      });

      test('Returns PARTIALLY_FULFILLED for mixed or partial fulfillment cases',
          () {
        // Case A: 1 item complete, 1 partial, 1 zero
        final requestA = Request(
          requestedBy: 'Diego',
          items: [
            RequestItem(
                publicationId: 1, quantityRequested: 10, quantityFulfilled: 10),
            RequestItem(
                publicationId: 2, quantityRequested: 5, quantityFulfilled: 2),
            RequestItem(
                publicationId: 3, quantityRequested: 3, quantityFulfilled: 0),
          ],
        );
        expect(
          requestA.fulfillmentStatus,
          equals(RequestFulfillmentStatus.partiallyFulfilled),
        );

        // Case B: 1 item zero, 1 partial
        final requestB = Request(
          requestedBy: 'Diego',
          items: [
            RequestItem(
                publicationId: 1, quantityRequested: 5, quantityFulfilled: 0),
            RequestItem(
                publicationId: 2, quantityRequested: 10, quantityFulfilled: 3),
          ],
        );
        expect(
          requestB.fulfillmentStatus,
          equals(RequestFulfillmentStatus.partiallyFulfilled),
        );
      });
    });

    group('Domain Item Management Operations Tests', () {
      test('addItem appends item and updates updatedAt', () {
        final request = Request(requestedBy: 'Laura', createdAt: tCreatedAt);
        final item = RequestItem(publicationId: 10, quantityRequested: 4);

        final updated = request.addItem(item, updatedAt: tUpdatedAt);

        expect(updated.items.length, equals(1));
        expect(updated.items.first, equals(item));
        expect(updated.updatedAt, equals(tUpdatedAt));
      });

      test(
          'addItem throws DuplicatePublicationInRequestException if publicationId exists',
          () {
        final item1 = RequestItem(publicationId: 10, quantityRequested: 4);
        final request = Request(requestedBy: 'Laura', items: [item1]);

        final itemDuplicate =
            RequestItem(publicationId: 10, quantityRequested: 2);

        expect(
          () => request.addItem(itemDuplicate),
          throwsA(isA<DuplicatePublicationInRequestException>()),
        );
      });

      test('removeItem removes item by publicationId and recalculates status',
          () {
        final item1 = RequestItem(
          publicationId: 1,
          quantityRequested: 5,
          quantityFulfilled: 5,
        );
        final item2 = RequestItem(
          publicationId: 2,
          quantityRequested: 3,
          quantityFulfilled: 0,
        );

        final request = Request(
          requestedBy: 'Elena',
          items: [item1, item2],
        );

        expect(
          request.fulfillmentStatus,
          equals(RequestFulfillmentStatus.partiallyFulfilled),
        );

        final updated = request.removeItem(2);

        expect(updated.items.length, equals(1));
        expect(updated.items.first.publicationId, equals(1));
        expect(
          updated.fulfillmentStatus,
          equals(RequestFulfillmentStatus.fulfilled),
        );
      });

      test(
          'removeItem throws RequestItemNotFoundException if publicationId not found',
          () {
        final request = Request(requestedBy: 'Elena');

        expect(
          () => request.removeItem(99),
          throwsA(isA<RequestItemNotFoundException>()),
        );
      });

      group('Publication Replacement (Draft -> Complete & Collision Tests)',
          () {
        test(
            'replaceItemPublication replaces publicationId preserving item id and quantities',
            () {
          final originalItem = RequestItem(
            id: 50,
            publicationId: 35, // Draft publication
            quantityRequested: 10,
            quantityFulfilled: 4,
          );

          final request = Request(
            requestedBy: 'Gabriel',
            items: [originalItem],
            createdAt: tCreatedAt,
          );

          // Replaces Draft #35 with Complete #8
          final updatedRequest = request.replaceItemPublication(
            oldPublicationId: 35,
            newPublicationId: 8,
            updatedAt: tUpdatedAt,
          );

          expect(updatedRequest.items.length, equals(1));
          final replacedItem = updatedRequest.items.first;

          expect(replacedItem.id, equals(50));
          expect(replacedItem.publicationId, equals(8));
          expect(replacedItem.quantityRequested, equals(10));
          expect(replacedItem.quantityFulfilled, equals(4));
          expect(updatedRequest.updatedAt, equals(tUpdatedAt));
        });

        test(
            'replaceItemPublication throws DuplicatePublicationInRequestException on collision',
            () {
          final itemDraft = RequestItem(
            id: 1,
            publicationId: 35, // Draft #35
            quantityRequested: 10,
          );
          final itemExisting = RequestItem(
            id: 2,
            publicationId: 8, // Complete #8 already in request
            quantityRequested: 5,
          );

          final request = Request(
            requestedBy: 'Gabriel',
            items: [itemDraft, itemExisting],
          );

          // Attempting to replace 35 -> 8 when 8 is already present must throw exception
          expect(
            () => request.replaceItemPublication(
              oldPublicationId: 35,
              newPublicationId: 8,
            ),
            throwsA(isA<DuplicatePublicationInRequestException>()),
          );

          // Confirm request instance remains untouched
          expect(request.items[0].publicationId, equals(35));
          expect(request.items[1].publicationId, equals(8));
        });

        test('replaceItemPublication returns identical instance if old == new',
            () {
          final item = RequestItem(publicationId: 8, quantityRequested: 5);
          final request = Request(requestedBy: 'Hugo', items: [item]);

          final updated = request.replaceItemPublication(
            oldPublicationId: 8,
            newPublicationId: 8,
          );

          expect(identical(request, updated), isTrue);
        });

        test(
            'replaceItemPublication throws RequestItemNotFoundException if oldPublicationId is not in request',
            () {
          final request = Request(requestedBy: 'Hugo');

          expect(
            () => request.replaceItemPublication(
              oldPublicationId: 99,
              newPublicationId: 8,
            ),
            throwsA(isA<RequestItemNotFoundException>()),
          );
        });
      });

      test(
          'updateItemQuantityRequested modifies item quantity with invariant checks',
          () {
        final item = RequestItem(
          publicationId: 10,
          quantityRequested: 5,
          quantityFulfilled: 2,
        );
        final request = Request(requestedBy: 'Irene', items: [item]);

        final updated = request.updateItemQuantityRequested(10, 8);
        expect(updated.items.first.quantityRequested, equals(8));

        expect(
          () => request.updateItemQuantityRequested(10, 1),
          throwsArgumentError,
        );
      });

      test(
          'updateItemQuantityFulfilled modifies item quantity with invariant checks',
          () {
        final item = RequestItem(
          publicationId: 10,
          quantityRequested: 5,
          quantityFulfilled: 2,
        );
        final request = Request(requestedBy: 'Irene', items: [item]);

        final updated = request.updateItemQuantityFulfilled(10, 5);
        expect(updated.items.first.quantityFulfilled, equals(5));

        expect(
          () => request.updateItemQuantityFulfilled(10, 6),
          throwsArgumentError,
        );
      });
    });

    group('isFullyDefined Pure Domain Evaluation Tests', () {
      final completePub1 = Publication(
        id: 1,
        code: 'RBI-8',
        name: 'Biblia Letra Grande',
        type: 'Libro',
      );
      final completePub2 = Publication(
        id: 8,
        code: 'RL-12',
        name: 'Revista La Atalaya',
        type: 'Revista',
      );
      final draftPub35 = Publication.quickDraft(
        id: 35,
        name: 'Biblia especial',
        description: 'Borrador rápido para identificación posterior',
      );

      test('Returns true when all items refer to COMPLETE publications', () {
        final request = Request(
          requestedBy: 'Marcos',
          items: [
            RequestItem(publicationId: 1, quantityRequested: 2),
            RequestItem(publicationId: 8, quantityRequested: 5),
          ],
        );

        expect(
          request.isFullyDefined([completePub1, completePub2]),
          isTrue,
        );
      });

      test('Returns false when any item refers to a DRAFT publication', () {
        final request = Request(
          requestedBy: 'Marcos',
          items: [
            RequestItem(publicationId: 1, quantityRequested: 2),
            RequestItem(publicationId: 35, quantityRequested: 1), // Draft
          ],
        );

        expect(
          request.isFullyDefined([completePub1, completePub2, draftPub35]),
          isFalse,
        );
      });

      test('Returns false when a publication is missing from the provided list',
          () {
        final request = Request(
          requestedBy: 'Marcos',
          items: [
            RequestItem(publicationId: 1, quantityRequested: 2),
            RequestItem(publicationId: 99, quantityRequested: 1), // Missing #99
          ],
        );

        expect(
          request.isFullyDefined([completePub1, completePub2]),
          isFalse,
        );
      });

      test('Returns false when request items list is empty', () {
        final request = Request(requestedBy: 'Marcos', items: []);

        expect(
          request.isFullyDefined([completePub1, completePub2]),
          isFalse,
        );
      });
    });

    group('Equality, CopyWith and Serialization Tests', () {
      test('copyWith updates specified fields and preserves remaining ones',
          () {
        final request = Request(
          id: 1,
          requestedBy: 'Valeria',
          notes: 'Nota original',
          createdAt: tCreatedAt,
          updatedAt: tCreatedAt,
        );

        final copied = request.copyWith(
          requestedBy: 'Valeria Gómez',
          notes: () => null,
          updatedAt: tUpdatedAt,
        );

        expect(copied.id, equals(1));
        expect(copied.requestedBy, equals('Valeria Gómez'));
        expect(copied.notes, isNull);
        expect(copied.createdAt, equals(tCreatedAt));
        expect(copied.updatedAt, equals(tUpdatedAt));
      });

      test('Supports value equality (==) and hashCode', () {
        final item = RequestItem(publicationId: 1, quantityRequested: 2);

        final req1 = Request(
          id: 10,
          requestedBy: 'Pablo',
          items: [item],
          createdAt: tCreatedAt,
          updatedAt: tCreatedAt,
        );
        final req2 = Request(
          id: 10,
          requestedBy: 'Pablo',
          items: [item],
          createdAt: tCreatedAt,
          updatedAt: tCreatedAt,
        );

        expect(req1, equals(req2));
        expect(req1.hashCode, equals(req2.hashCode));
      });

      test('toString returns informative string representation', () {
        final request = Request(
          id: 5,
          requestedBy: 'Rosa',
          items: [RequestItem(publicationId: 1, quantityRequested: 2)],
        );

        expect(
          request.toString(),
          contains(
              'Request(id: 5, requestedBy: "Rosa", items: 1, status: RequestFulfillmentStatus.pending'),
        );
      });
    });
  });
}
