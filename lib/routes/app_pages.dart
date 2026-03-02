import 'package:get/get.dart';
import 'package:halisaha_app/modules/home/views/home_view.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/match/views/match_create_view.dart';
import '../modules/match/bindings/match_create_binding.dart';
import '../modules/root/views/root_view.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/home/bindings/profile_binding.dart';
import '../routes/app_routes.dart';

class AppPages {
  static const initial = Routes.ROOT;

  static final routes = [
    GetPage(
      name: Routes.ROOT,
      page: () => const RootView(),
      // ProfileController'ı uygulama başlar başlamaz permanent olarak yükle
      binding: ProfileBinding(),
    ),
    GetPage(name: Routes.AUTH, page: () => AuthView(), binding: AuthBinding()),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(userName: 'Ahmet Yılmaz'),
    ),
    GetPage(
      name: Routes.MATCH_CREATE,
      page: () => const MatchCreateView(),
      binding: MatchCreateBinding(),
    ),
    GetPage(
      name: Routes.SETTINGS,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
  ];
}
