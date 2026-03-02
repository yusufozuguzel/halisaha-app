import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart'; // Paylaşım özelliği için eklendi 🔥

// KENDI BACKEND DOSYALARIMIZI IMPORT EDIYORUZ
import '../models/match_model.dart';
import '../services/match_service.dart';

class MatchCreateController extends GetxController {
  // Backend servisimizi çağırıyoruz (Takımın eklediği)
  final MatchService _matchService = MatchService();

  // Step indicator (Takımın eklediği)
  var currentStep = 0.obs;

  // TextEditingController variables (Senin sağlam altyapın)
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
      firstDate: now, // Geçmişe maç açılamaz
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2EED7B), // Neon yeşil
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
            primary: Color(0xFF2EED7B), // Neon yeşil
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

  // 🔥 BİRLEŞTİRİLMİŞ BACKEND VE PAYLAŞIM ENTEGRASYONU 🔥
  Future<void> createAndShareMatch() async {
    // 1. Sıkı Doğrulama (Senin Kodun)
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

      // 2. Zaman Dönüşümü
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

      // 3. Veritabanı Şemasına Uygun Kayıt (Senin kusursuz şeman)
      final matchData = {
        'title': title,
        'venue': venue,
        'price': price,
        'maxPlayers': maxPlayers,
        'date': timestamp,
        'createdBy': uid,
        'currentPlayers': [uid], // Kurucuyu listeye ekle
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 4. Firestore'a ekle ve otomatik oluşan ID'yi al!
      final docRef = await FirebaseFirestore.instance.collection('matches').add(matchData);
      final String generatedMatchId = docRef.id;

      // 5. Dinamik Link Hedefi Üretimi (Takımın eklediği özellik)
      final String deepLink = 'https://halisaha.app/join/$generatedMatchId';
      
      // Paylaşım metni için tarih formatlama
      final String formattedDate = "${date.day}/${date.month}/${date.year}";
      final String formattedTime = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

      // 6. Başarı Mesajı ve Kapanış
      Get.back(); // Formu kapatır
      Get.snackbar(
        'Maç Oluşturuldu! 🏆',
        'Maç başarıyla kaydedildi ve paylaşım menüsü açıldı.',
        backgroundColor: const Color(0xFF1A2E1F),
        colorText: const Color(0xFF2EED7B),
        snackPosition: SnackPosition.BOTTOM,
      );

      // 7. Native Paylaşım (share_plus) Tetiklemesi
      await Share.share(
        '⚽ Yeni bir maça davetlisin!\n\nMaç: $title\n📅 $formattedDate - ⏰ $formattedTime\n📍 $venue\n\nMaça katılmak için hemen tıkla:\n$deepLink',
        subject: 'Halı Saha Maç Daveti',
      );

    } catch (e) {
      Get.snackbar(
        'Hata',
        'Maç oluşturulamadı: $e',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}