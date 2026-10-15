import 'package:firebase_app_check/firebase_app_check.dart';

/// Disabled until platform attestation providers have been configured.
Future<String?> callableAppCheckToken() async {
  if (!const bool.fromEnvironment('APP_CHECK_ENABLED')) return null;
  final token = await FirebaseAppCheck.instance.getToken();
  if (token == null || token.isEmpty) {
    throw StateError('App Check token unavailable');
  }
  return token;
}
