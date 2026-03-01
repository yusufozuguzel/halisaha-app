import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get_storage/get_storage.dart';
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

  Future<void> _setInitialScreen(User? user) async {
    if (user == null) {
      Get.offAllNamed(Routes.AUTH);
    } else {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final isComplete = data['isProfileComplete'] ?? false;
          if (isComplete) {
            Get.offAllNamed(Routes.HOME);
          } else {
            Get.offAllNamed(Routes.PROFILE_SETUP);
          }
        } else {
          // If no doc exists somehow, force profile setup
          Get.offAllNamed(Routes.PROFILE_SETUP);
        }
      } catch (e) {
        // Fallback
        Get.offAllNamed(Routes.HOME);
      }
    }
  }

  Future<void> login(
    String input,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      String emailToLogin = input.trim();

      // Check if it's a username (no @ symbol)
      if (!emailToLogin.contains('@')) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('name', isEqualTo: emailToLogin)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          Get.snackbar("Hata", "Kullanıcı adı bulunamadı");
          return;
        }

        emailToLogin = querySnapshot.docs.first.data()['email'] ?? '';
      }

      await _auth.signInWithEmailAndPassword(
        email: emailToLogin,
        password: password.trim(),
      );

      if (rememberMe) {
        GetStorage().write('rememberedEmail', input.trim());
      } else {
        GetStorage().remove('rememberedEmail');
      }

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
      isLogin.value = true;
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
