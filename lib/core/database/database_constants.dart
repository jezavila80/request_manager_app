class DatabaseConstants {
  static const String databaseName = 'request_manager.db';
  static const int databaseVersion = 3;

  // Tables
  static const String tablePublications = 'publications';
  static const String tableRequests = 'requests';
  static const String tableRequestItems = 'request_items';
  static const String tableRequesters = 'requesters';

  // Common Columns
  static const String columnId = 'id';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  // Requesters Columns
  static const String columnNormalizedName = 'normalized_name';

  // Publications Columns
  static const String columnCode = 'code';
  static const String columnName = 'name';
  static const String columnDescription = 'description';
  static const String columnType = 'type';
  static const String columnSizeValue = 'size_value';
  static const String columnSizeState = 'size_state';
  static const String columnVersionValue = 'version_value';
  static const String columnVersionState = 'version_state';
  static const String columnIsActive = 'is_active';

  // Requests Columns
  static const String columnRequestedBy = 'requested_by';
  static const String columnRequesterId = 'requester_id';
  static const String columnNotes = 'notes';

  // RequestItems Columns
  static const String columnRequestId = 'request_id';
  static const String columnPublicationId = 'publication_id';
  static const String columnQuantityRequested = 'quantity_requested';
  static const String columnQuantityFulfilled = 'quantity_fulfilled';

  // Size / Version State options
  static const String stateUndefined = 'undefined';
  static const String stateValue = 'value';
  static const String stateNotApplicable = 'not_applicable';
}
