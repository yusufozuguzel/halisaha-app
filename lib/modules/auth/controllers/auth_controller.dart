import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  var isLogin = true.obs;

  Future<void> submit(String email, String password) async {
    try {
      if (isLogin.value) {
        await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
      }
      Get.snackbar("Başarılı", "İşlem tamamlandı");
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Hata", e.message ?? "Bir hata oluştu");
    }
  }
}
