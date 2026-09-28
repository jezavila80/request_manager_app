/// Represents the calculated fulfillment status of a [Request].
///
/// A request can be:
/// - [pending]: No items have been fulfilled yet.
/// - [partiallyFulfilled]: Some items have been fulfilled, or items are partially fulfilled.
/// - [fulfilled]: All items have been completely fulfilled.
enum RequestFulfillmentStatus {
  pending,
  partiallyFulfilled,
  fulfilled,
}

/// Pure domain function calculating the fulfillment status of a request based on:
/// - [itemCount]: Number of distinct publication items.
/// - [quantityRequested]: Total units requested across all items.
/// - [quantityFulfilled]: Total units fulfilled across all items.
RequestFulfillmentStatus calculateRequestFulfillmentStatus({
  required int itemCount,
  required int quantityRequested,
  required int quantityFulfilled,
}) {
  if (itemCount == 0) {
    return RequestFulfillmentStatus.pending;
  }
  if (quantityFulfilled == 0) {
    return RequestFulfillmentStatus.pending;
  }
  if (quantityFulfilled == quantityRequested) {
    return RequestFulfillmentStatus.fulfilled;
  }
  return RequestFulfillmentStatus.partiallyFulfilled;
}
