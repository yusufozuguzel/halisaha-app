import 'package:get/get.dart';
import 'package:halisaha_app/modules/home/views/home_view.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/root/views/root_view.dart';
import '../modules/home/views/home_view.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.ROOT, page: () => RootView()),
    GetPage(name: AppRoutes.AUTH, page: () => AuthView()),
    GetPage(name: AppRoutes.HOME, page: () => HomeView()),
  static const initial = Routes.AUTH;

  static final routes = [
    GetPage(name: Routes.AUTH, page: () => AuthView(), binding: AuthBinding()),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(userName: "Ahmet Yılmaz"),
    ),
  ];
}
