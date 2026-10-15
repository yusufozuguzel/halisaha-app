import 'account_deletion.dart';
import 'safety_api.dart';

class FirebaseAccountDeletion implements AccountDeletionBackend {
  FirebaseAccountDeletion({SafetyApi? api, String? Function()? currentUid})
      : _api = api ?? SafetyApi(),
        _currentUid = currentUid;
  final SafetyApi _api;
  final String? Function()? _currentUid;

  @override
  Future<void> prepareDeletion({String? expectedUid}) async {
    if (expectedUid != null && _currentUid != null && _currentUid!() != expectedUid) {
      throw const DeletionUnavailable();
    }
    final result = await _api.call('prepareAccountDeletion');
    if (result['ready'] != true) throw const DeletionUnavailable();
  }

  @override
  Future<void> deleteCurrentAccount({String? expectedUid}) async {
    if (expectedUid != null && _currentUid != null && _currentUid!() != expectedUid) {
      throw const DeletionUnavailable();
    }
    final result = await _api.call('requestAccountDeletion');
    if (result['accepted'] != true) throw const SafetyApiException('INTERNAL');
  }
}
