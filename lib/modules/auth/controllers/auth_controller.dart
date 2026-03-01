import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Rx<User?> firebaseUser;
  var isLogin = true.obs;

  @override
  void onReady() {
    super.onReady();
    // Initialize the firebaseUser with current state
    firebaseUser = Rx<User?>(_auth.currentUser);
    // Bind stream so it updates when auth states change
    firebaseUser.bindStream(_auth.authStateChanges());
    // Use worker to trigger routing based on changes
    ever(firebaseUser, _setInitialScreen);
  }

  _setInitialScreen(User? user) {
    if (user == null) {
      Get.offAllNamed(Routes.AUTH);
    } else {
      Get.offAllNamed(Routes.HOME);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      Get.snackbar("Başarılı", "Giriş yapıldı");
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Hata", e.message ?? "Bir hata oluştu");
    }
  }

  Future<void> register(String email, String password, String fullName) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        "uid": userCredential.user!.uid,
        "email": email.trim(),
        "name": fullName.trim(),
        "createdAt": Timestamp.now(),
      });

      Get.snackbar("Başarılı", "Kayıt işlemi tamamlandı");
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Hata", e.message ?? "Bir hata oluştu");
    }
  }

  // Proper logout function
  Future<void> logout() async {
    try {
      await _auth.signOut();
      // Notice: we don't need any manual routing here either
    } catch (e) {
      Get.snackbar("Hata", "Çıkış yapılırken bir hata oluştu: ${e.toString()}");
    }
  }

  // Google Sign-In logic
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // User canceled the sign-in
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // Check if user exists in Firestore
        final DocumentSnapshot doc = await _firestore
            .collection("users")
            .doc(user.uid)
            .get();

        if (!doc.exists) {
          // If the user doesn't exist, create a new document
          await _firestore.collection("users").doc(user.uid).set({
            "uid": user.uid,
            "email": user.email ?? "",
            "name": user.displayName ?? "",
            "createdAt": Timestamp.now(),
          });
        }

        Get.snackbar("Başarılı", "Google ile giriş yapıldı");
      }
    } catch (e) {
      Get.snackbar("Hata", "Google girişi başarısız: ${e.toString()}");
    }
  }
}
