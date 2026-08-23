class DatabaseConstants {
  static const String databaseName = 'request_manager.db';
  static const int databaseVersion = 1;

  // Publications Table
  static const String tablePublications = 'publications';

  // Columns
  static const String columnId = 'id';
  static const String columnCode = 'code';
  static const String columnName = 'name';
  static const String columnDescription = 'description';
  static const String columnType = 'type';
  static const String columnSizeValue = 'size_value';
  static const String columnSizeState = 'size_state';
  static const String columnVersionValue = 'version_value';
  static const String columnVersionState = 'version_state';
  static const String columnIsActive = 'is_active';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  // Size / Version State options
  static const String stateUndefined = 'undefined';
  static const String stateValue = 'value';
  static const String stateNotApplicable = 'not_applicable';
}
