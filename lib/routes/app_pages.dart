import 'package:get/get.dart';
import 'package:halisaha_app/modules/home/views/home_view.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = Routes.AUTH;

  static final routes = [
    GetPage(name: Routes.AUTH, page: () => AuthView(), binding: AuthBinding()),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(userName: "Ahmet Yılmaz"),
    ),
  ];
}
