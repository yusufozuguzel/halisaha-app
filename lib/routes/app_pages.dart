import 'package:get/get.dart';
import 'package:halisaha_app/modules/home/views/home_view.dart';
import 'package:halisaha_app/modules/match/views/match_list_view.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/auth/views/profile_setup_view.dart';
import '../modules/auth/controllers/profile_setup_controller.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/root/views/root_view.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/home/bindings/profile_binding.dart';
import 'app_routes.dart';

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
      name: Routes.PROFILE_SETUP,
      page: () => const ProfileSetupView(),
      binding: BindingsBuilder(() {
        Get.put(ProfileSetupController());
      }),
    ),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(userName: "Ahmet Yılmaz"),
    ),
    GetPage(
      name: Routes.SETTINGS,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
  ];
}
