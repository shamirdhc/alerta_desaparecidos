import '../../domain/entities/policia.dart';
import '../../domain/repositories/policia_repository.dart';
import '../data_sources/policia_remote_data_source.dart';

class PoliciaRepositoryImpl implements PoliciaRepository {
  final PoliciaRemoteDataSource _remoteDataSource;

  PoliciaRepositoryImpl({required PoliciaRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<Policia>> getAllPolicias() async {
    return await _remoteDataSource.getAllPolicias();
  }

  @override
  Future<Policia?> getPoliciaById(String uid) async {
    return await _remoteDataSource.getPoliciaById(uid);
  }

  @override
  Future<Policia?> getCurrentPolicia() async {
    return await _remoteDataSource.getCurrentPolicia();
  }

  @override
  Future<bool> isCurrentUserAdmin() async {
    return await _remoteDataSource.isCurrentUserAdmin();
  }

  @override
  Future<void> createPolicia(Policia policia) async {
    await _remoteDataSource.createPolicia(policia);
  }

  @override
  Future<void> updatePolicia(Policia policia) async {
    await _remoteDataSource.updatePolicia(policia);
  }

  @override
  Future<void> deletePolicia(String uid) async {
    await _remoteDataSource.deletePolicia(uid);
  }

  @override
  Future<bool> phoneNumberExists(String phoneNumber, {String? excludeUid}) async {
    return await _remoteDataSource.phoneNumberExists(phoneNumber, excludeUid: excludeUid);
  }

  @override
  Future<bool> cipNumberExists(String cipNumber, {String? excludeUid}) async {
    return await _remoteDataSource.cipNumberExists(cipNumber, excludeUid: excludeUid);
  }
}