import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  var isLogin = true.obs;

  Future<void> submit(String email, String password) async {
    try {
      if (isLogin.value) {
        await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
      } else {
        UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password.trim(),
            );

        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Get.snackbar("Başarılı", "İşlem tamamlandı");
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Hata", e.message ?? "Bir hata oluştu");
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
