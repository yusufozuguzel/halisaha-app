import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';

GoogleSignIn createGoogleSignIn() => GoogleSignIn(
  clientId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? DefaultFirebaseOptions.ios.iosClientId
      : null,
);
