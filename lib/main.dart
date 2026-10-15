import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'routes/app_pages.dart';
import 'modules/auth/controllers/auth_controller.dart';
import 'modules/home/controllers/notifications_controller.dart';
import 'core/theme/app_theme.dart';

import 'package:get_storage/get_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (mobile) {
    // Enable only after registering both apps; enforcement is a separate rollout.
    if (const bool.fromEnvironment('APP_CHECK_ENABLED')) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
    final crashlytics = FirebaseCrashlytics.instance;
    final collectCrashes =
        kReleaseMode && const bool.fromEnvironment('CRASHLYTICS_ENABLED');
    await crashlytics.setCrashlyticsCollectionEnabled(collectCrashes);
    if (collectCrashes) {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        crashlytics.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    }
  }
  await GetStorage.init();

  Get.put(AuthController(), permanent: true);
  Get.put(NotificationsController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DEPAR',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: (GetStorage().read('isDarkMode') ?? true)
          ? ThemeMode.dark
          : ThemeMode.light,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
