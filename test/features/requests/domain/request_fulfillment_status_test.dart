import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requests/domain/request_fulfillment_status.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';

import '../../../helpers/test_request_factory.dart';

void main() {
  group('calculateRequestFulfillmentStatus Pure Function Tests', () {
    test('itemCount == 0 returns pending regardless of quantities', () {
      expect(
        calculateRequestFulfillmentStatus(
          itemCount: 0,
          quantityRequested: 0,
          quantityFulfilled: 0,
        ),
        equals(RequestFulfillmentStatus.pending),
      );

      expect(
        calculateRequestFulfillmentStatus(
          itemCount: 0,
          quantityRequested: 10,
          quantityFulfilled: 5,
        ),
        equals(RequestFulfillmentStatus.pending),
      );
    });

    test('quantityFulfilled == 0 with itemCount > 0 returns pending', () {
      expect(
        calculateRequestFulfillmentStatus(
          itemCount: 1,
          quantityRequested: 5,
          quantityFulfilled: 0,
        ),
        equals(RequestFulfillmentStatus.pending),
      );

      expect(
        calculateRequestFulfillmentStatus(
          itemCount: 3,
          quantityRequested: 20,
          quantityFulfilled: 0,
        ),
        equals(RequestFulfillmentStatus.pending),
      );
    });

    test(
        'quantityFulfilled == quantityRequested with quantityRequested > 0 and itemCount > 0 returns fulfilled',
        () {
      expect(
        calculateRequestFulfillmentStatus(
          itemCount: 1,
          quantityRequested: 5,
          quantityFulfilled: 5,
        ),
        equals(RequestFulfillmentStatus.fulfilled),
      );

      expect(
        calculateRequestFulfillmentStatus(
          itemCount: 4,
          quantityRequested: 12,
          quantityFulfilled: 12,
        ),
        equals(RequestFulfillmentStatus.fulfilled),
      );
    });

    test(
        'quantityFulfilled > 0 and quantityFulfilled < quantityRequested returns partiallyFulfilled',
        () {
      expect(
        calculateRequestFulfillmentStatus(
          itemCount: 2,
          quantityRequested: 10,
          quantityFulfilled: 3,
        ),
        equals(RequestFulfillmentStatus.partiallyFulfilled),
      );

      expect(
        calculateRequestFulfillmentStatus(
          itemCount: 1,
          quantityRequested: 5,
          quantityFulfilled: 4,
        ),
        equals(RequestFulfillmentStatus.partiallyFulfilled),
      );
    });
  });

  group(
      'Equivalence between calculateRequestFulfillmentStatus and Request.fulfillmentStatus',
      () {
    test('empty request produces pending in both', () {
      final req = createTestRequest(requesterId: 1);

      expect(req.fulfillmentStatus, equals(RequestFulfillmentStatus.pending));
      expect(
        calculateRequestFulfillmentStatus(
          itemCount: req.items.length,
          quantityRequested: req.totalQuantityRequested,
          quantityFulfilled: req.totalQuantityFulfilled,
        ),
        equals(req.fulfillmentStatus),
      );
    });

    test('all items pending produces pending in both', () {
      final req = createTestRequest(requesterId: 1).copyWith(
        items: [
          RequestItem(
            publicationId: 1,
            quantityRequested: 5,
            quantityFulfilled: 0,
          ),
          RequestItem(
            publicationId: 2,
            quantityRequested: 3,
            quantityFulfilled: 0,
          ),
        ],
      );

      expect(req.fulfillmentStatus, equals(RequestFulfillmentStatus.pending));
      expect(
        calculateRequestFulfillmentStatus(
          itemCount: req.items.length,
          quantityRequested: req.totalQuantityRequested,
          quantityFulfilled: req.totalQuantityFulfilled,
        ),
        equals(req.fulfillmentStatus),
      );
    });

    test('all items fulfilled produces fulfilled in both', () {
      final req = createTestRequest(requesterId: 1).copyWith(
        items: [
          RequestItem(
            publicationId: 1,
            quantityRequested: 5,
            quantityFulfilled: 5,
          ),
          RequestItem(
            publicationId: 2,
            quantityRequested: 3,
            quantityFulfilled: 3,
          ),
        ],
      );

      expect(req.fulfillmentStatus, equals(RequestFulfillmentStatus.fulfilled));
      expect(
        calculateRequestFulfillmentStatus(
          itemCount: req.items.length,
          quantityRequested: req.totalQuantityRequested,
          quantityFulfilled: req.totalQuantityFulfilled,
        ),
        equals(req.fulfillmentStatus),
      );
    });

    test('mixed items produce partiallyFulfilled in both', () {
      final req = createTestRequest(requesterId: 1).copyWith(
        items: [
          RequestItem(
            publicationId: 1,
            quantityRequested: 5,
            quantityFulfilled: 5,
          ),
          RequestItem(
            publicationId: 2,
            quantityRequested: 3,
            quantityFulfilled: 0,
          ),
        ],
      );

      expect(
        req.fulfillmentStatus,
        equals(RequestFulfillmentStatus.partiallyFulfilled),
      );
      expect(
        calculateRequestFulfillmentStatus(
          itemCount: req.items.length,
          quantityRequested: req.totalQuantityRequested,
          quantityFulfilled: req.totalQuantityFulfilled,
        ),
        equals(req.fulfillmentStatus),
      );
    });
  });
}
