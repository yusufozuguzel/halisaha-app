import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class LoginIdentifierException implements Exception {
  const LoginIdentifierException(this.message);
  final String message;
}

/// No anonymous Firestore queries. Username resolution requires the password
/// on the server; reset responses never include an email or account existence.
class LoginIdentifier {
  LoginIdentifier({
    http.Client? client,
    String? projectId,
    Future<void> Function(String email, String password)? signIn,
    Future<void> Function(String email)? resetEmail,
  }) : _client = client,
       _projectId = projectId,
       _signIn = signIn ?? _firebaseSignIn,
       _resetEmail = resetEmail ?? _firebaseReset;

  final http.Client? _client;
  final String? _projectId;
  final Future<void> Function(String, String) _signIn;
  final Future<void> Function(String) _resetEmail;

  static Future<void> _firebaseSignIn(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> _firebaseReset(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email);

  String _identifier(String input) {
    final value = input.trim();
    if (value.isEmpty || value.length > 254) {
      throw const LoginIdentifierException(
        'E-posta veya kullanıcı adınızı girin.',
      );
    }
    return value;
  }

  Future<void> signIn(String input, String password) async {
    final value = _identifier(input);
    if (value.contains('@')) {
      await _signIn(value, password);
      return;
    }
    final result = await _call('verifyUsernamePassword', {
      'username': value,
      'password': password,
    });
    final email = result['email'];
    if (email is! String || !email.contains('@')) {
      throw const LoginIdentifierException(
        'Giriş tamamlanamadı. Lütfen tekrar deneyin.',
      );
    }
    // Keep Firebase's native password session and provider checks. No custom
    // token is minted, and no returned email is stored by this adapter.
    await _signIn(email, password);
  }

  Future<void> resetPassword(String input) async {
    final value = _identifier(input);
    if (value.contains('@')) {
      try {
        await _resetEmail(value);
      } on FirebaseAuthException catch (e) {
        if (!{'user-not-found', 'user-disabled'}.contains(e.code)) rethrow;
      }
    } else {
      final result = await _call('resetUsernamePassword', {'username': value});
      if (result['accepted'] != true) {
        throw const LoginIdentifierException(
          'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _call(
    String function,
    Map<String, dynamic> data,
  ) async {
    final project = _projectId ?? Firebase.app().options.projectId;
    if (!RegExp(r'^[a-z][a-z0-9-]+$').hasMatch(project)) {
      throw const LoginIdentifierException('Giriş hizmeti yapılandırılmamış.');
    }
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.https('europe-west1-$project.cloudfunctions.net', '/$function'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body);
      if (body is! Map) throw const FormatException();
      if (body['error'] is Map) {
        final code = body['error']['status'];
        throw LoginIdentifierException(
          code == 'UNAUTHENTICATED'
              ? 'Kullanıcı adı veya şifre hatalı. Aynı adı kullanan hesaplarda e-postanızla giriş yapın.'
              : code == 'RESOURCE_EXHAUSTED'
              ? 'Çok fazla deneme yapıldı. Daha sonra tekrar deneyin.'
              : 'Kullanıcı adı hizmetine ulaşılamadı. E-posta adresinizle tekrar deneyebilirsiniz.',
        );
      }
      if (response.statusCode != 200 || body['result'] is! Map) {
        throw const FormatException();
      }
      return Map<String, dynamic>.from(body['result'] as Map);
    } on LoginIdentifierException {
      rethrow;
    } catch (_) {
      throw const LoginIdentifierException(
        'Kullanıcı adı hizmetine ulaşılamadı. E-posta adresinizle tekrar deneyebilirsiniz.',
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}
