import 'package:firebase_auth/firebase_auth.dart';
import 'authenticated_callable.dart';
import 'safety_api.dart';

class UsernameException implements Exception {
  const UsernameException(this.message);
  final String message;
}

String normalizeUsername(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(normalized)) {
    throw const UsernameException(
      'Kullan\u0131c\u0131 ad\u0131 3-30 harf, rakam veya alt \u00e7izgi olmal\u0131d\u0131r.',
    );
  }
  return normalized;
}

class UsernameService {
  UsernameService({AuthenticatedCallable? call, String? Function()? currentUid})
    : _call = call ?? authenticatedCallable,
      _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final AuthenticatedCallable _call;
  final String? Function() _uid;
  void _checkOwner(String? owner) {
    if (owner == null || _uid() != owner)
      throw const UsernameException(
        'Oturum de\u011fi\u015fti. L\u00fctfen tekrar deneyin.',
      );
  }

  Future<bool> enabled() async =>
      (await _call('safetyStatus', {}))['usernamesEnabled'] == true;
  Future<String> claim(String input) async {
    final username = normalizeUsername(input);
    final owner = _uid();
    _checkOwner(owner);
    try {
      if (!await enabled())
        throw const UsernameException(
          'Kullan\u0131c\u0131 ad\u0131 hizmeti hen\u00fcz kullan\u0131lam\u0131yor.',
        );
      _checkOwner(owner);
      final result = await _call('claimUsername', {'username': username});
      _checkOwner(owner);
      if (result['username'] != username)
        throw const UsernameException(
          'Kullan\u0131c\u0131 ad\u0131 kaydedilemedi.',
        );
      return username;
    } on UsernameException {
      rethrow;
    } on SafetyApiException catch (error) {
      throw UsernameException(
        error.code == 'ALREADY_EXISTS'
            ? 'Bu kullan\u0131c\u0131 ad\u0131 kullan\u0131l\u0131yor. Ba\u015fka bir ad se\u00e7in.'
            : 'Kullan\u0131c\u0131 ad\u0131 kaydedilemedi. Daha sonra tekrar deneyin.',
      );
    } catch (_) {
      throw const UsernameException(
        'Kullan\u0131c\u0131 ad\u0131 hizmetine ula\u015f\u0131lamad\u0131.',
      );
    }
  }

  Future<String?> find(String input) async {
    final username = normalizeUsername(
      input.startsWith('@') ? input.substring(1) : input,
    );
    if (!await enabled()) return null;
    final result = await _call('findUsername', {'username': username});
    if (result['available'] == true) return null;
    final uid = result['uid'];
    if (result['available'] != false ||
        uid is! String ||
        uid.isEmpty ||
        uid.contains('/')) {
      throw const UsernameException('Kullan\u0131c\u0131 bulunamad\u0131.');
    }
    return uid;
  }
}
