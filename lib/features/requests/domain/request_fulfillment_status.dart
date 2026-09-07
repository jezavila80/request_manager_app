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
