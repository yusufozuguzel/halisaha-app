import 'package:get/get.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/root/views/root_view.dart';
import '../modules/home/views/home_view.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.ROOT, page: () => RootView()),
    GetPage(name: AppRoutes.AUTH, page: () => AuthView()),
    GetPage(name: AppRoutes.HOME, page: () => HomeView()),
  ];
}
