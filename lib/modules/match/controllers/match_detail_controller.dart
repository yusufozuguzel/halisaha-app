import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchDetailController extends GetxController {
  final RxBool isLoading = true.obs;
  final Rx<Map<String, dynamic>?> matchData = Rx<Map<String, dynamic>?>(null);

  String matchId = '';

  @override
  void onInit() {
    super.onInit();
    // Get arguments'ten maç ID'sini alıyoruz
    var args = Get.arguments;
    if (args != null && args is String) {
      matchId = args;
      fetchMatchDetail(matchId);
    } else {
      // Hatalı veya eksik argüman
      isLoading.value = false;
      matchData.value = null;
    }
  }

  Future<void> fetchMatchDetail(String id) async {
    try {
      isLoading.value = true;

      final docSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .doc(id)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        data['id'] = docSnapshot.id;
        matchData.value = data;
      } else {
        matchData.value = null;
      }
    } catch (e) {
      print('Maç detayı çekilirken hata oluştu: $e');
      matchData.value = null;
    } finally {
      // Başta sonsuz yüklemede kalıyordu, şimdi işlem bitince try/catch fark etmeksizin duruyor.
      isLoading.value = false;
    }
  }

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
