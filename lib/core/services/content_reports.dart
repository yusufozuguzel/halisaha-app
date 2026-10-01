import 'safety_api.dart';

enum ReportTarget { user, match }

enum ReportReason { harassment, inappropriateContent, spam, other }

class ContentReports {
  ContentReports({SafetyApi? api}) : _api = api ?? SafetyApi();
  final SafetyApi _api;

  Future<bool> isAvailable() async {
    try {
      return (await _api.call('safetyStatus'))['reportsEnabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> submit({
    required ReportTarget type,
    required String targetId,
    required ReportReason reason,
  }) async {
    if (targetId.isEmpty || targetId.contains('/')) {
      throw ArgumentError.value(targetId, 'targetId');
    }
    final result = await _api.call('submitContentReport', {
      'type': type.name,
      'targetId': targetId,
      'reason': reason.name,
    });
    if (result['recorded'] != true) throw const SafetyApiException('INTERNAL');
  }
}
