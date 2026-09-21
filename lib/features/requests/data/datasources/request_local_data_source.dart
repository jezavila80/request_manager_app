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

  Future<List<Request>> getAll();

  Future<Request?> getById(int id);
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

  @override
  Future<List<Request>> getAll() async {
    try {
      final db = await _appDatabase.database;

      return await db.transaction((txn) async {
        final reqRows = await txn.query(
          DatabaseConstants.tableRequests,
          orderBy:
              '${DatabaseConstants.columnCreatedAt} DESC, ${DatabaseConstants.columnId} DESC',
        );

        if (reqRows.isEmpty) {
          return <Request>[];
        }

        final itemRows = await txn.query(
          DatabaseConstants.tableRequestItems,
          orderBy: '${DatabaseConstants.columnId} ASC',
        );

        final itemsByRequestId = <int, List<RequestItem>>{};
        final allPublicationIds = <int>[];

        for (final itemRow in itemRows) {
          final requestId = itemRow[DatabaseConstants.columnRequestId] as int;
          final item = RequestItemMapper.fromMap(itemRow);
          allPublicationIds.add(item.publicationId);
          itemsByRequestId.putIfAbsent(requestId, () => []).add(item);
        }

        await _verifyPublicationsExist(txn, allPublicationIds);

        final requests = <Request>[];
        for (final reqRow in reqRows) {
          final reqId = reqRow[DatabaseConstants.columnId] as int;
          final items = itemsByRequestId[reqId] ?? <RequestItem>[];
          final req = RequestMapper.fromMap(reqRow, items: items);
          requests.add(req);
        }

        return requests;
      });
    } on DatabaseException catch (e) {
      throw RequestPersistenceException(
        'Error de persistencia en SQLite al listar las solicitudes.',
        e,
      );
    } catch (e) {
      if (e is RequestException) {
        rethrow;
      }
      throw RequestPersistenceException(
        'Error inesperado al listar las solicitudes en la base de datos.',
        e,
      );
    }
  }

  @override
  Future<Request?> getById(int id) async {
    if (id <= 0) {
      throw ArgumentError('El ID de la solicitud debe ser mayor a 0.');
    }

    try {
      final db = await _appDatabase.database;

      return await db.transaction((txn) async {
        final reqRows = await txn.query(
          DatabaseConstants.tableRequests,
          where: '${DatabaseConstants.columnId} = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (reqRows.isEmpty) {
          return null;
        }

        final itemRows = await txn.query(
          DatabaseConstants.tableRequestItems,
          where: '${DatabaseConstants.columnRequestId} = ?',
          whereArgs: [id],
          orderBy: '${DatabaseConstants.columnId} ASC',
        );

        final items = itemRows.map(RequestItemMapper.fromMap).toList();
        await _verifyPublicationsExist(txn, items.map((i) => i.publicationId));

        return RequestMapper.fromMap(reqRows.first, items: items);
      });
    } on DatabaseException catch (e) {
      throw RequestPersistenceException(
        'Error de persistencia en SQLite al consultar la solicitud por ID ($id).',
        e,
      );
    } catch (e) {
      if (e is RequestException || e is ArgumentError) {
        rethrow;
      }
      throw RequestPersistenceException(
        'Error inesperado al consultar la solicitud por ID ($id) en la base de datos.',
        e,
      );
    }
  }

  Future<void> _verifyPublicationsExist(
    DatabaseExecutor executor,
    Iterable<int> publicationIds,
  ) async {
    final distinctIds = publicationIds.toSet().toList();
    if (distinctIds.isEmpty) return;

    final placeholders = List.filled(distinctIds.length, '?').join(',');
    final rows = await executor.rawQuery(
      'SELECT ${DatabaseConstants.columnId} FROM ${DatabaseConstants.tablePublications} WHERE ${DatabaseConstants.columnId} IN ($placeholders);',
      distinctIds,
    );

    final existingIds =
        rows.map((r) => r[DatabaseConstants.columnId] as int).toSet();

    for (final pubId in distinctIds) {
      if (!existingIds.contains(pubId)) {
        throw RequestPersistenceException(
          'Integridad referencial rota: la publicación con ID $pubId referenciada en la solicitud no existe.',
        );
      }
    }
  }
}
