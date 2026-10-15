import 'dart:convert';
import 'callable_app_check.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class SafetyApiException implements Exception {
  const SafetyApiException(this.code);
  final String code;
}

/// Firebase callable protocol, using the existing HTTP dependency.
/// The project comes from the initialized Firebase app, never a user-provided URL.
class SafetyApi {
  SafetyApi({
    http.Client? client,
    Future<String?> Function()? token,
    String? projectId,
    Future<String?> Function()? appCheckToken,
  }) : _client = client,
       _token = token,
       _appCheckToken = appCheckToken ?? callableAppCheckToken,
       _projectId = projectId;

  final http.Client? _client;
  final Future<String?> Function()? _token;
  final String? _projectId;
  final Future<String?> Function() _appCheckToken;

  Future<Map<String, dynamic>> call(
    String function, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (!const {
      'safetyStatus',
      'placesProxy',
      'claimUsername',
      'findUsername',
      'uploadProfilePhoto',
      'prepareAccountDeletion',
      'requestAccountDeletion',
      'submitContentReport',
      'listContentReports',
      'reviewContentReport',
      'moderationQueue',
      'applyModerationAction',
      'restoreModeratedAccount',
    }.contains(function)) {
      throw const SafetyApiException('INVALID_ARGUMENT');
    }
    final token = _token != null
        ? await _token()
        : await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null) throw const SafetyApiException('UNAUTHENTICATED');
    final project = _projectId ?? Firebase.app().options.projectId;
    if (!RegExp(r'^[a-z][a-z0-9-]+$').hasMatch(project)) {
      throw const SafetyApiException('INVALID_ARGUMENT');
    }
    final client = _client ?? http.Client();
    try {
      final appCheck = await _appCheckToken();
      final response = await client
          .post(
            Uri.https('europe-west1-$project.cloudfunctions.net', '/$function'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              if (appCheck != null) 'X-Firebase-AppCheck': appCheck,
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(
            Duration(seconds: function == 'uploadProfilePhoto' ? 65 : 30),
          );
      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const SafetyApiException('UNAVAILABLE');
      }
      if (body['error'] is Map) {
        throw SafetyApiException(
          body['error']['status'] as String? ?? 'INTERNAL',
        );
      }
      if (response.statusCode != 200 || body['result'] is! Map) {
        throw const SafetyApiException('UNAVAILABLE');
      }
      return Map<String, dynamic>.from(body['result'] as Map);
    } on SafetyApiException {
      rethrow;
    } catch (_) {
      throw const SafetyApiException('UNAVAILABLE');
    } finally {
      if (_client == null) client.close();
    }
  }
}
