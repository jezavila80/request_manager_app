import '../../domain/requester.dart';
import '../../domain/requester_repository.dart';
import '../datasources/requester_local_data_source.dart';

class RequesterRepositoryImpl implements RequesterRepository {
  final RequesterLocalDataSource _localDataSource;

  RequesterRepositoryImpl({RequesterLocalDataSource? localDataSource})
      : _localDataSource = localDataSource ?? RequesterLocalDataSourceImpl();

  @override
  Future<Requester> create(Requester requester) async {
    return await _localDataSource.create(requester);
  }

  @override
  Future<Requester?> getById(int id) async {
    if (id <= 0) {
      throw ArgumentError('El ID del solicitante debe ser mayor a 0.');
    }
    return await _localDataSource.getById(id);
  }

  @override
  Future<Requester?> findByNormalizedName(String normalizedName) async {
    final trimmed = normalizedName.trim();
    if (trimmed.isEmpty) return null;
    return await _localDataSource.findByNormalizedName(trimmed);
  }

  @override
  Future<List<Requester>> searchActiveByName(String query,
      {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    return await _localDataSource.searchActiveByName(trimmed, limit: limit);
  }

  @override
  Future<List<Requester>> getAll() async {
    return await _localDataSource.getAll();
  }
}
