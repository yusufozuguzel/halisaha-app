import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchCreateController extends GetxController {
  // TextEditingController variables
  final titleController = TextEditingController();
  final venueController = TextEditingController();
  final priceController = TextEditingController();
  final maxPlayersController = TextEditingController(text: '14');

  // Reactive variables for Date and Time
  final selectedDate = Rx<DateTime?>(null);
  final selectedTime = Rx<TimeOfDay?>(null);

  // Loading state
  final isLoading = false.obs;

  @override
  void onClose() {
    // Dispose all controllers
    titleController.dispose();
    venueController.dispose();
    priceController.dispose();
    maxPlayersController.dispose();
    super.onClose();
  }

  // Pick Date Function
  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? now,
      firstDate: now, // Prevents selection of past dates
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2EED7B), // Neon yeşil ana renk
            onPrimary: Colors.black,
            surface: Color(0xFF1A2E1F),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1A2E1F),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      selectedDate.value = picked;
    }
  }

  // Pick Time Function
  Future<void> pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime.value ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2EED7B), // Neon yeşil ana renk
            onPrimary: Colors.black,
            surface: Color(0xFF1A2E1F),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1A2E1F),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      selectedTime.value = picked;
    }
  }

  // Create Match Function
  Future<void> createMatch() async {
    // Validation
    final title = titleController.text.trim();
    final venue = venueController.text.trim();
    final priceStr = priceController.text.trim();
    final maxPlayersStr = maxPlayersController.text.trim();

    if (title.isEmpty ||
        venue.isEmpty ||
        priceStr.isEmpty ||
        maxPlayersStr.isEmpty ||
        selectedDate.value == null ||
        selectedTime.value == null) {
      Get.snackbar(
        'Eksik Bilgi',
        'Lütfen tüm alanları doldurun ve tarih/saat seçin.',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final price = double.tryParse(priceStr) ?? 0.0;
    final maxPlayers = int.tryParse(maxPlayersStr) ?? 14;

    try {
      isLoading.value = true;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Oturum açmış kullanıcı bulunamadı.');
      }
      final uid = user.uid;

      // Zaman Dönüşümü
      final date = selectedDate.value!;
      final time = selectedTime.value!;
      final combinedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      final timestamp = Timestamp.fromDate(combinedDateTime);

      // Veritabanı Şemasına Uygun Kayıt
      final matchData = {
        'title': title,
        'venue': venue,
        'price': price,
        'maxPlayers': maxPlayers,
        'date': timestamp,
        'createdBy': uid,
        'currentPlayers': [uid],
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('matches').add(matchData);

      // Sonuç - İşlem başarılı
      Get.back();
      Get.snackbar(
        'Başarılı',
        'Maç başarıyla oluşturuldu.',
        backgroundColor: const Color(0xFF2EED7B),
        colorText: Colors.black,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      // Hata durumu
      Get.snackbar(
        'Hata',
        'Maç oluşturulurken bir hata oluştu: $e',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
