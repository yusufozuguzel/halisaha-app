import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiscoverController extends GetxController {
  final RxList<Map<String, dynamic>> openMatches = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchOpenMatches();
  }

  Future<void> fetchOpenMatches() async {
    try {
      isLoading.value = true;

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'open')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .get();

      openMatches.value = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Belgenin kendi id'sini (doc.id) veri içine dahil ediyoruz
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // Index hatası konsoldan linke tıklamak için eklendi
      print('Arama (Keşfet) maçları çekilirken hata oluştu: $e');

      Get.snackbar(
        'Hata',
        'Maçlar yüklenirken bir sorun oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isLoading.value = false;
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
