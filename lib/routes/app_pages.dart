import 'package:get/get.dart';
import 'package:halisaha_app/modules/home/views/home_view.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/auth/views/profile_setup_view.dart';
import '../modules/auth/controllers/profile_setup_controller.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/root/views/root_view.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = Routes.ROOT;

  static final routes = [
    GetPage(name: Routes.ROOT, page: () => const RootView()),
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
  ];
}
