import 'package:firebase_auth/firebase_auth.dart';
import 'profile_photo_upload.dart';
import 'safety_api.dart';

typedef AuthenticatedCallable =
    Future<Map<String, dynamic>> Function(
      String function,
      Map<String, dynamic> data,
    );

Future<Map<String, dynamic>> authenticatedCallable(
  String function,
  Map<String, dynamic> data,
) {
  final auth = FirebaseAuth.instance;
  final owner = auth.currentUser;
  if (owner == null) throw const SafetyApiException('UNAUTHENTICATED');
  return SafetyApi(
    token: () => profilePhotoTokenForOwner(
      owner.uid,
      currentUid: () => auth.currentUser?.uid,
      getTokenResult: () => owner.getIdTokenResult(true),
    ),
  ).call(function, data);
}
