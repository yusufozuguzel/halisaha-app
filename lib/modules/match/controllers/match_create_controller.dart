import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class MatchCreateController extends GetxController {
  // Step indicator
  var currentStep = 0.obs;

  // General Info
  var matchName = ''.obs;
  var matchFormat = '7x7'.obs;
  var fieldType = 'Açık Saha'.obs;

  // Time & Location
  var selectedDate = Rxn<DateTime>();
  var selectedTime = Rxn<TimeOfDay>();
  var locationName = ''.obs;

  // Teams
  var homeTeamName = ''.obs;
  var awayTeamName = ''.obs;

  // Text editing controllers
  final matchNameController = TextEditingController();
  final locationController = TextEditingController();
  final homeTeamController = TextEditingController();
  final awayTeamController = TextEditingController();

  // Options
  final List<String> matchFormats = ['5x5', '6x6', '7x7', '8x8', '11x11'];
  final List<String> fieldTypes = [
    'Açık Saha',
    'Kapalı Saha',
    'Sentetik Çim',
    'Doğal Çim',
  ];

  @override
  void onInit() {
    super.onInit();
    matchNameController.addListener(
      () => matchName.value = matchNameController.text,
    );
    locationController.addListener(
      () => locationName.value = locationController.text,
    );
    homeTeamController.addListener(
      () => homeTeamName.value = homeTeamController.text,
    );
    awayTeamController.addListener(
      () => awayTeamName.value = awayTeamController.text,
    );
  }

  @override
  void onClose() {
    matchNameController.dispose();
    locationController.dispose();
    homeTeamController.dispose();
    awayTeamController.dispose();
    super.onClose();
  }

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2EED7B),
            onPrimary: Color(0xFF0F1712),
            surface: Color(0xFF1A2E1F),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1A2E1F),
        ),
        child: child!,
      ),
    );
    if (picked != null) selectedDate.value = picked;
  }

  Future<void> pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime.value ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2EED7B),
            onPrimary: Color(0xFF0F1712),
            surface: Color(0xFF1A2E1F),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1A2E1F),
        ),
        child: child!,
      ),
    );
    if (picked != null) selectedTime.value = picked;
  }

  String get formattedDate {
    if (selectedDate.value == null) return 'mm/dd/yy';
    final d = selectedDate.value!;
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final year = d.year.toString().substring(2);
    return '$month/$day/$year';
  }

  String get formattedTime {
    if (selectedTime.value == null) return '--:-- --';
    final t = selectedTime.value!;
    final hour = t.hourOfPeriod.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> createAndShareMatch() async {
    if (matchName.value.isEmpty) {
      Get.snackbar(
        'Eksik Bilgi',
        'Lütfen maç adını girin.',
        backgroundColor: const Color(0xFF1A2E1F),
        colorText: const Color(0xFF2EED7B),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      // 1. Dinamik Link Hedefi Üretimi (UI/Mock)
      final String matchId = DateTime.now().millisecondsSinceEpoch.toString();
      final String deepLink = 'https://halisaha.app/join/$matchId';

      // 2. Native Paylaşım (share_plus) Tetiklemesi
      // Backend ekibi veritabanı kayıt mantığını (Keşfet havuzuna pushlama vs)
      // buraya entegre edecektir. Biz sadece UI/Share tetikleyicisini bırakıyoruz.
      await Share.share(
        '⚽ Yeni bir maça davetlisin!\n\nMaç: ${matchName.value}\n📅 $formattedDate - ⏰ $formattedTime\n📍 ${locationName.value.isNotEmpty ? locationName.value : "Belirtilmedi"}\n\nTakımlar: ${homeTeamName.value.isNotEmpty ? homeTeamName.value : "Ev Sahibi"} vs ${awayTeamName.value.isNotEmpty ? awayTeamName.value : "Deplasman"}\n\nMaça katılmak için hemen tıkla:\n$deepLink',
        subject: 'Halı Saha Maç Daveti',
      );

      Get.snackbar(
        'Paylaşım Başarılı',
        'Maç oluşturma ve davet linki paylaşım menüsü açıldı.',
        backgroundColor: const Color(0xFF16221A),
        colorText: const Color(0xFF2EED7B),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF2EED7B)),
      );
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Paylaşım menüsü açılamadı: $e',
        backgroundColor: const Color(0xFF16221A),
        colorText: Colors.redAccent,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
