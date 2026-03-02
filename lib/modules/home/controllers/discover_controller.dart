import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiscoverController extends GetxController {
  final RxList<Map<String, dynamic>> openMatches = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchOpenMatches();
  }

  void fetchOpenMatches() {
    isLoading.value = true;

    FirebaseFirestore.instance
        .collection('matches')
        .where('status', isEqualTo: 'open')
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date')
        .snapshots()
        .listen(
          (QuerySnapshot querySnapshot) {
            openMatches.value = querySnapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              // Belgenin kendi id'sini (doc.id) veri içine dahil ediyoruz
              data['id'] = doc.id;
              return data;
            }).toList();

            isLoading.value = false;
          },
          onError: (e) {
            print('Arama (Keşfet) maçları dinlenirken hata oluştu: $e');
            isLoading.value = false;

            Get.snackbar(
              'Hata',
              'Maçlar yüklenirken bir sorun oluştu: $e',
              backgroundColor: Colors.red.shade600,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(16),
            );
          },
        );
  }

  Future<void> joinMatch(
    String matchId,
    List<dynamic> currentPlayers,
    int maxPlayers,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı.');
      }

      final uid = user.uid;

      if (currentPlayers.contains(uid)) {
        Get.snackbar(
          'Zaten Kadrodasın',
          'Bu maça daha önce kayıt oldunuz.',
          backgroundColor: Colors.amber.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      if (currentPlayers.length >= maxPlayers) {
        Get.snackbar(
          'Kontenjan Dolu',
          'Maalesef bu maç için yer kalmadı.',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .update({
            'currentPlayers': FieldValue.arrayUnion([uid]),
          });

      Get.snackbar(
        'Başarılı',
        'Maça kadrosuna eklendiniz! Kramponları hazırlayın.',
        backgroundColor: Colors.greenAccent.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );

      fetchOpenMatches();
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Bir hata oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  Future<void> leaveMatch(String matchId, List<dynamic> currentPlayers) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı.');
      }

      final uid = user.uid;

      if (!currentPlayers.contains(uid)) {
        return;
      }

      await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .update({
            'currentPlayers': FieldValue.arrayRemove([uid]),
          });

      Get.snackbar(
        'Başarılı',
        'Maçtan başarıyla ayrıldınız.',
        backgroundColor: Colors.greenAccent.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Bir hata oluştu: $e',
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

  Future<void> cancelMatch(String matchId) async {
    try {
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .delete();

      Get.snackbar(
        'Maç İptal Edildi',
        'Kurduğunuz maç sistemden başarıyla silindi.',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Maç iptal edilirken bir sorun oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }
}
