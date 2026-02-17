import 'package:get/get.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/home/views/home_view.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = AppRoutes.AUTH;

  static final routes = [
    GetPage(name: AppRoutes.AUTH, page: () => const AuthView()),
    GetPage(name: AppRoutes.HOME, page: () => const HomeView()),
  ];
}
