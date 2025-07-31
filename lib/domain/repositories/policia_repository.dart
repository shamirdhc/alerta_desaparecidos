import '../entities/policia.dart';

abstract class PoliciaRepository {
  Future<List<Policia>> getAllPolicias();
  Future<Policia?> getPoliciaById(String uid);
  Future<Policia?> getCurrentPolicia();
  Future<bool> isCurrentUserAdmin();
  Future<void> createPolicia(Policia policia);
  Future<void> updatePolicia(Policia policia);
  Future<void> deletePolicia(String uid);
  Future<bool> phoneNumberExists(String phoneNumber, {String? excludeUid});
  Future<bool> cipNumberExists(String cipNumber, {String? excludeUid});
}