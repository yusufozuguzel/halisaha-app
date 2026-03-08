import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get_storage/get_storage.dart';
import '../../../routes/app_routes.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/controllers/profile_controller.dart';
import '../../home/controllers/discover_controller.dart';
import '../../home/controllers/notifications_controller.dart';
import '../../match/controllers/match_controller.dart';
import '../../match/controllers/my_matches_controller.dart';
import '../../match/controllers/match_detail_controller.dart';
import '../../match/controllers/match_create_controller.dart';
import '../../friends/controllers/friends_controller.dart';
import '../../settings/controllers/settings_controller.dart';

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
        if (user.uid.isEmpty) return;
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
          Get.snackbar(
            "Hata",
            "Kullanıcı bulunamadı. Lütfen isminizi büyük/küçük harfe dikkat ederek doğru girdiğinizden emin olun.",
          );
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
    } catch (e) {
      print("SİSTEM HATASI: $e");
      Get.snackbar("Giriş Hatası", "Hata detayı: $e");
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

      // Belirli veri dinleyicilerini (Stream) ve controller'ları sıfırla
      Get.delete<HomeController>(force: true);
      Get.delete<ProfileController>(force: true);
      Get.delete<DiscoverController>(force: true);
      Get.delete<NotificationsController>(force: true);
      Get.delete<MatchController>(force: true);
      Get.delete<MyMatchesController>(force: true);
      Get.delete<MatchDetailController>(force: true);
      Get.delete<MatchCreateController>(force: true);
      Get.delete<FriendsController>(force: true);
      Get.delete<SettingsController>(force: true);

      isLogin.value = true;
      Get.offAllNamed(Routes.AUTH);
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
        if (user.uid.isEmpty) return;
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

  Future<void> resetPassword(String input) async {
    try {
      String targetEmail;

      if (!input.contains('@')) {
        String trimmedUsername = input.trim();
        final querySnapshot = await _firestore
            .collection('users')
            .where('name', isEqualTo: trimmedUsername)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          Get.snackbar(
            'Kullanıcı Bulunamadı',
            'Bu kullanıcı adıyla eşleşen bir hesap bulunamadı.',
            backgroundColor: Colors.red.shade600,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
          return;
        }

        targetEmail = querySnapshot.docs.first.data()['email'] ?? '';
      } else {
        targetEmail = input.trim();
      }

      await _auth.sendPasswordResetEmail(email: targetEmail);

      Get.snackbar(
        'Sıfırlama Bağlantısı Gönderildi',
        'Lütfen e-posta kutunuzu kontrol edin.',
        backgroundColor: Colors.greenAccent.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Hata',
        'İşlem sırasında bir hata oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }
}
