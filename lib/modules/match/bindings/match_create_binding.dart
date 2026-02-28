import 'package:get/get.dart';
import '../controllers/match_create_controller.dart';

class MatchCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MatchCreateController>(() => MatchCreateController());
  }
}
