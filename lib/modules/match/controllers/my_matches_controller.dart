import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyMatchesController extends GetxController {
  final RxList<Map<String, dynamic>> myMatches = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  List<Map<String, dynamic>> get upcomingMatches {
    final now = Timestamp.now();
    return myMatches.where((match) {
      final matchDate = match['date'] as Timestamp?;
      if (matchDate == null) return false;
      return matchDate.compareTo(now) > 0;
    }).toList();
  }

  List<Map<String, dynamic>> get pastMatches {
    final now = Timestamp.now();
    return myMatches.where((match) {
      final matchDate = match['date'] as Timestamp?;
      if (matchDate == null) return false;
      return matchDate.compareTo(now) <= 0;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    fetchMyMatches();
  }

  Future<void> fetchMyMatches() async {
    try {
      isLoading.value = true;

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Kullanıcı oturumu bulunamadı.');
      }

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('currentPlayers', arrayContains: currentUser.uid)
          .get();

      myMatches.value = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Detay sayfasına gitmek veya benzersiz bir key olarak kullanmak için ID'yi ekliyoruz
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      if (FirebaseAuth.instance.currentUser == null) return;
      Get.snackbar(
        'Hata',
        'Maçlarınız yüklenirken bir sorun oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> cancelMatch(String matchId) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) return;

      // 1. Hedef maçı ve listedeki indeksini yedekle
      final targetMatch = myMatches.firstWhere((m) => m['id'] == matchId);
      final index = myMatches.indexOf(targetMatch);

      // 2. Anında UI'dan sök (Optimistic Update)
      myMatches.removeAt(index);

      // 3. Geri alma statüsünü tutacak bayrak
      bool isUndone = false;

      // 4. Geri Al butonlu Snackbar
      Get.snackbar(
        'İşlem Başarılı',
        'Kurduğunuz maç sistemden siliniyor.',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        mainButton: TextButton(
          onPressed: () {
            isUndone = true;
            myMatches.insert(index, targetMatch);
            if (Get.isSnackbarOpen) Get.back();
          },
          child: const Text('Geri Al',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );

      // 5. 3 saniye cayma hakkını bekle
      await Future.delayed(const Duration(seconds: 3));

      // 6. Asıl Firebase Görevi
      if (!isUndone) {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .delete();
      }
    } catch (e) {
      if (FirebaseAuth.instance.currentUser == null) return;
      Get.snackbar(
        'Silme Hatası',
        'Maç iptal edilirken bir sorun oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  Future<void> leaveMatch(String matchId) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 1. Hedef maçı ve listedeki indeksini yedekle
      final targetMatch = myMatches.firstWhere((m) => m['id'] == matchId);
      final index = myMatches.indexOf(targetMatch);

      // 2. Anında UI'dan sök (Optimistic Update)
      myMatches.removeAt(index);

      // 3. Geri alma statüsünü tutacak bayrak
      bool isUndone = false;

      // 4. Geri Al butonlu Snackbar
      Get.snackbar(
        'İşlem Başarılı',
        'Maçtan ayrıldınız.',
        backgroundColor: Colors.greenAccent.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        mainButton: TextButton(
          onPressed: () {
            isUndone = true;
            myMatches.insert(index, targetMatch);
            if (Get.isSnackbarOpen) Get.back();
          },
          child: const Text('Geri Al',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );

      // 5. 3 saniye cayma hakkını bekle
      await Future.delayed(const Duration(seconds: 3));

      // 6. Asıl Firebase Görevi
      if (!isUndone) {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .update({
          'currentPlayers': FieldValue.arrayRemove([currentUser.uid]),
        });
      }
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Maçtan ayrılırken bir sorun oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  /// Firestore'dan gelen Timestamp verisini okunabilir bir saat/tarih formatına dönüştürür.
  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih Belirtilmedi';

    try {
      final DateTime date = timestamp.toDate();
      final String day = date.day.toString().padLeft(2, '0');
      final String month = date.month.toString().padLeft(2, '0');
      final String year = date.year.toString();
      final String hour = date.hour.toString().padLeft(2, '0');
      final String minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    } catch (e) {
      return 'Geçersiz Tarih';
    }
  }
}
