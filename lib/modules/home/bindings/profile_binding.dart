  import 'package:get/get.dart';
import '../controllers/profile_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    // permanent: true → başka sayfaya geçildiğinde controller hafızadan silinmez
    Get.put(ProfileController(), permanent: true);
  }
}
