import '../../../../core/database/database_constants.dart';
import '../../../../core/time/app_date_time.dart';
import '../../domain/requester.dart';

class RequesterMapper {
  RequesterMapper._();

  static Requester fromMap(Map<String, dynamic> map) {
    return Requester(
      id: map[DatabaseConstants.columnId] as int?,
      name: map[DatabaseConstants.columnName] as String,
      normalizedName: map[DatabaseConstants.columnNormalizedName] as String?,
      isActive: (map[DatabaseConstants.columnIsActive] as int? ?? 1) == 1,
      createdAt: AppDateTime.fromStorage(
          map[DatabaseConstants.columnCreatedAt] as String),
      updatedAt: AppDateTime.fromStorage(
          map[DatabaseConstants.columnUpdatedAt] as String),
    );
  }

  static Map<String, dynamic> toMap(Requester requester) {
    return {
      if (requester.id != null) DatabaseConstants.columnId: requester.id,
      DatabaseConstants.columnName: requester.name,
      DatabaseConstants.columnNormalizedName: requester.normalizedName,
      DatabaseConstants.columnIsActive: requester.isActive ? 1 : 0,
      DatabaseConstants.columnCreatedAt:
          AppDateTime.toStorage(requester.createdAt),
      DatabaseConstants.columnUpdatedAt:
          AppDateTime.toStorage(requester.updatedAt),
    };
  }
}
