import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_constants.dart';
import '../../domain/request.dart';
import '../../domain/request_exceptions.dart';
import '../../domain/request_item.dart';
import '../mappers/request_item_mapper.dart';
import '../mappers/request_mapper.dart';

abstract class RequestLocalDataSource {
  Future<Request> create(Request request);
}

class RequestLocalDataSourceImpl implements RequestLocalDataSource {
  final AppDatabase _appDatabase;

  RequestLocalDataSourceImpl({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  @override
  Future<Request> create(Request request) async {
    // 1. Validation before opening transaction
    if (!request.isValidForOrder) {
      throw InvalidRequestForCreationException(
        'La solicitud debe contener al menos un artículo para ser procesada.',
      );
    }

    if (request.id != null) {
      throw RequestAlreadyPersistedException(request.id!);
    }

    for (final item in request.items) {
      if (item.id != null) {
        throw RequestItemAlreadyPersistedException(item.id!);
      }
    }

    try {
      final db = await _appDatabase.database;

      return await db.transaction((txn) async {
        // Insert request header
        final headerMap = RequestMapper.toMap(request);
        final requestId = await txn.insert(
          DatabaseConstants.tableRequests,
          headerMap,
        );

        if (requestId <= 0) {
          throw RequestPersistenceException(
            'La base de datos devolvió un ID de solicitud inválido ($requestId).',
          );
        }

        // Insert request items in exact original order
        final persistedItems = <RequestItem>[];

        for (final item in request.items) {
          final itemMap = RequestItemMapper.toMap(item, requestId: requestId);
          final itemId = await txn.insert(
            DatabaseConstants.tableRequestItems,
            itemMap,
          );

          if (itemId <= 0) {
            throw RequestPersistenceException(
              'La base de datos devolvió un ID de renglón inválido ($itemId).',
            );
          }

          persistedItems.add(item.copyWith(id: itemId));
        }

        return request.copyWith(
          id: requestId,
          items: persistedItems,
          updatedAt: request.updatedAt,
        );
      });
    } on DatabaseException catch (e) {
      throw RequestPersistenceException(
        'Error de persistencia en SQLite al crear la solicitud.',
        e,
      );
    } catch (e) {
      if (e is RequestException) {
        rethrow;
      }
      throw RequestPersistenceException(
        'Error inesperado al crear la solicitud en la base de datos.',
        e,
      );
    }
  }
}
