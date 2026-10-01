import 'account_deletion.dart';
import 'safety_api.dart';

class FirebaseAccountDeletion implements AccountDeletionBackend {
  FirebaseAccountDeletion({SafetyApi? api}) : _api = api ?? SafetyApi();
  final SafetyApi _api;

  @override
  Future<void> prepareDeletion() async {
    final result = await _api.call('prepareAccountDeletion');
    if (result['ready'] != true) throw const DeletionUnavailable();
  }

  @override
  Future<void> deleteCurrentAccount() async {
    final result = await _api.call('requestAccountDeletion');
    if (result['accepted'] != true) throw const SafetyApiException('INTERNAL');
  }
}
