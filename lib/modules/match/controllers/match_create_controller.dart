import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart'; // Paylaşım özelliği için eklendi 🔥

// KENDI BACKEND DOSYALARIMIZI IMPORT EDIYORUZ
import '../services/match_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../modules/home/controllers/notifications_controller.dart';
import '../../../modules/home/controllers/home_controller.dart';
import 'my_matches_controller.dart';

class MatchCreateController extends GetxController {
  // Backend servisimizi çağırıyoruz (Takımın eklediği)
  final MatchService _matchService = MatchService();

  // Step indicator (Takımın eklediği)
  var currentStep = 0.obs;

  // TextEditingController variables
  final titleController = TextEditingController();
  final venueController = TextEditingController();
  final priceController = TextEditingController();
  final teamAController = TextEditingController();
  final teamBController = TextEditingController();

  // Maç formatı (dropdown) — değerden maxPlayers hesaplanır
  final RxString selectedFormat = '7x7'.obs;

  // Reactive variables for Date and Time
  final selectedDate = Rx<DateTime?>(null);
  final selectedTime = Rx<TimeOfDay?>(null);

  // Loading state
  final isLoading = false.obs;

  // Edit (Güncelleme) State
  final RxBool isEditing = false.obs;
  String? editingMatchId;

  @override
  void onInit() {
    super.onInit();
    _checkEditMode();
  }

  void _checkEditMode() {
    final args = Get.arguments;
    if (args != null && args is Map<String, dynamic>) {
      isEditing.value = true;
      editingMatchId = args['id'];

      // Verileri Doldur (Pre-fill)
      titleController.text = args['title'] ?? '';
      venueController.text = args['venue'] ?? '';
      priceController.text = (args['price'] ?? '').toString();
      teamAController.text = args['teamA_name'] ?? '';
      teamBController.text = args['teamB_name'] ?? '';

      if (args['maxPlayers'] != null) {
        final mp = args['maxPlayers'] as int;
        // Örneğin maxPlayers 14 ise format 7x7 olur
        final side = mp ~/ 2;
        // Eğer desteklenmeyen bir rakamsa (örn 15 -> 7x7) en yakına yuvarlar
        if (side >= 5 && side <= 11) {
          selectedFormat.value = '${side}x$side';
        }
      }

      if (args['date'] is Timestamp) {
        final dt = (args['date'] as Timestamp).toDate();
        selectedDate.value = dt;
        selectedTime.value = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    venueController.dispose();
    priceController.dispose();
    teamAController.dispose();
    teamBController.dispose();
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
        data: Theme.of(context).copyWith(
          colorScheme: AppColors.isDark(context)
              ? const ColorScheme.dark(
                  primary: Color(0xFF2EED7B), // Neon yeşil
                  onPrimary: Colors.black,
                  surface: Color(0xFF162318), // AppColors.card(context) Dark
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: Color(0xFF2EED7B), // Neon yeşil
                  onPrimary: Colors.white,
                  surface: Color(0xFFFFFFFF), // AppColors.card(context) Light
                  onSurface: Colors.black,
                ),
          dialogBackgroundColor: AppColors.card(context),
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
      initialEntryMode:
          TimePickerEntryMode.input, // Doğrudan klavye girişi açılsın
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: AppColors.isDark(context)
              ? const ColorScheme.dark(
                  primary: Color(0xFF2EED7B), // Neon yeşil
                  onPrimary: Colors.black,
                  surface: Color(0xFF162318), // AppColors.card(context) Dark
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: Color(0xFF2EED7B), // Neon yeşil
                  onPrimary: Colors.white,
                  surface: Color(0xFFFFFFFF), // AppColors.card(context) Light
                  onSurface: Colors.black,
                ),
          dialogBackgroundColor: AppColors.card(context),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
    );
    if (picked != null) {
      selectedTime.value = picked;
    }
  }

  // 🔥 BİRLEŞTİRİLMİŞ BACKEND VE PAYLAŞIM ENTEGRASYONU 🔥
  Future<void> createAndShareMatch() async {
    // 1. Validation
    final title = titleController.text.trim();
    final venue = venueController.text.trim();
    final priceStr = priceController.text.trim();

    if (title.isEmpty ||
        venue.isEmpty ||
        priceStr.isEmpty ||
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
    // Format string'den oyuncu sayısını hesapla: '7x7' → 14
    final n = int.tryParse(selectedFormat.value.split('x').first) ?? 7;
    final maxPlayers = n * 2;

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

      // 3. Firestore'a kayıt
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
        'teamA_name': teamAController.text.trim().isEmpty
            ? 'A Takımı'
            : teamAController.text.trim(),
        'teamB_name': teamBController.text.trim().isEmpty
            ? 'B Takımı'
            : teamBController.text.trim(),
      };

      // 4. Firestore İşlemi (Edit vs Create)
      String generatedMatchId;
      if (isEditing.value && editingMatchId != null) {
        // Güncelleme
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(editingMatchId)
            .update(matchData);
        generatedMatchId = editingMatchId!;
      } else {
        // Yeni Oluşturma
        final docRef = await FirebaseFirestore.instance
            .collection('matches')
            .add(matchData);
        generatedMatchId = docRef.id;
      }

      // 5. Dinamik Link Hedefi Üretimi (Takımın eklediği özellik)
      final String deepLink = 'https://halisaha.app/join/$generatedMatchId';

      // Paylaşım metni için tarih formatlama
      final String formattedDate = "${date.day}/${date.month}/${date.year}";
      final String formattedTime =
          "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

      // 6. Başarı Mesajı ve Kapanış
      Get.back(); // Formu kapatır
      Get.snackbar(
        isEditing.value ? 'Maç Güncellendi! ✏️' : 'Maç Oluşturuldu! 🏆',
        isEditing.value
            ? 'Maç detayları başarıyla güncellendi.'
            : 'Maç başarıyla kaydedildi ve paylaşım menüsü açıldı.',
        backgroundColor: const Color(0xFF1A2E1F),
        colorText: const Color(0xFF2EED7B),
        snackPosition: SnackPosition.BOTTOM,
      );

      // 7. Bildirim tetikle
      Get.find<NotificationsController>().addNotification(
        title: isEditing.value
            ? 'Maç Güncellendi ✏️'
            : 'Yeni Maç Oluşturuldu 🏆',
        message: isEditing.value
            ? '"$title" maçının detayları güncellendi.'
            : '"$title" maçı başarıyla kuruldu. Hadi sahaya!',
      );

      // 8. Ana sayfa ve Maçlarım listelerini yenile
      if (Get.isRegistered<MyMatchesController>()) {
        Get.find<MyMatchesController>().fetchMyMatches();
      }
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().fetchMatches();
      }

      // 9. Native Paylaşım (share_plus) Tetiklemesi (Sadece yeni oluşturmada paylaş)
      if (!isEditing.value) {
        await Share.share(
          '⚽ Yeni bir maça davetlisin!\n\nMaç: $title\n📅 $formattedDate - ⏰ $formattedTime\n📍 $venue\n\nMaça katılmak için hemen tıkla:\n$deepLink',
          subject: 'Halı Saha Maç Daveti',
        );
      }
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
