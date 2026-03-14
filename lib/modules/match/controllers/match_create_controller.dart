import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // Harita için eklendi 🔥

import '../services/match_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../modules/home/controllers/notifications_controller.dart';
import '../../../modules/home/controllers/home_controller.dart';
import 'my_matches_controller.dart';

class MatchCreateController extends GetxController {
  final MatchService _matchService = MatchService();
  var currentStep = 0.obs;

  final titleController = TextEditingController();
  final venueController = TextEditingController();
  final priceController = TextEditingController();
  final teamAController = TextEditingController();
  final teamBController = TextEditingController();

  final RxString selectedFormat = '7x7'.obs;
  final selectedDate = Rx<DateTime?>(null);
  final selectedTime = Rx<TimeOfDay?>(null);

  // 🔥 HARİTA İÇİN YENİ DEĞİŞKENLER 🔥
  final Rx<double?> selectedLat = Rx<double?>(null);
  final Rx<double?> selectedLng = Rx<double?>(null);

  final isLoading = false.obs;
  final RxString searchQuery = ''.obs; // Arama kutusuna yazılan metin
  final RxBool isEditing = false.obs;
  String? editingMatchId;

  // Test için örnek sahalar
  final List<Map<String, dynamic>> mockLocations = [
    {'name': 'Şampiyonlar Halı Saha, Serdivan', 'lat': 40.7654, 'lng': 30.3712},
    {'name': 'Erenler Spor Kompleksi, Sakarya', 'lat': 40.7589, 'lng': 30.4156},
    {'name': 'Olimpiyat Halı Saha', 'lat': 40.7731, 'lng': 30.3948},
  ];

  // Firebase'den gelecek canlı saha listesi
  final RxList<Map<String, dynamic>> allVenues = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _checkEditMode(); // Eskiden olan edit kontrolü
    fetchVenues(); // 🔥 YENİ: Uygulama açılınca sahaları Firebase'den çek
  }

  // Arama metnine göre filtrelenmiş sahalar
  // 🔥 1. FİREBASE'DEN SAHALARI İNDİR 🔥
  Future<void> fetchVenues() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('venues')
          .get();

      // Veritabanındaki sahaları alıp listemize dolduruyoruz
      final venues = snapshot.docs
          .map(
            (doc) => {
              'id': doc.id,
              'name': doc['name'],
              'lat': doc['lat'],
              'lng': doc['lng'],
            },
          )
          .toList();

      allVenues.value = venues;
    } catch (e) {
      print("Sahalar çekilirken hata oluştu: $e");
      allVenues.value =
          mockLocations; // Hata olursa yedek olarak mock verileri kullan
    }
  }

  // 🔥 2. FİLTRELEME (ARTIK CANLI VERİDEN) 🔥
  List<Map<String, dynamic>> get filteredLocations {
    // Arama kutusu boşsa tüm Firebase sahalarını göster
    if (searchQuery.value.isEmpty) return allVenues;

    // Doluysa adına göre filtrele
    return allVenues
        .where(
          (loc) => loc['name'].toString().toLowerCase().contains(
            searchQuery.value.toLowerCase(),
          ),
        )
        .toList();
  }

  // 🔥 3. TEK SEFERLİK SAHA YÜKLEME ARACI 🔥
  Future<void> uploadInitialVenues() async {
    final db = FirebaseFirestore.instance;
    isLoading.value = true;
    try {
      for (var loc in mockLocations) {
        await db.collection('venues').add({
          'name': loc['name'],
          'lat': loc['lat'],
          'lng': loc['lng'],
          'city': 'Sakarya', // Şimdilik memleketi sabit verelim
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      Get.snackbar(
        'Başarılı',
        'Sahalar Firebase\'e yüklendi!',
        backgroundColor: Colors.green[800],
        colorText: Colors.white,
      );
      await fetchVenues(); // Yükledikten sonra listeyi yenile
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Yüklenemedi: $e',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _checkEditMode() {
    final args = Get.arguments;
    if (args != null && args is Map<String, dynamic>) {
      isEditing.value = true;
      editingMatchId = args['id'];

      titleController.text = args['title'] ?? '';
      venueController.text = args['venue'] ?? '';
      priceController.text = (args['price'] ?? '').toString();
      teamAController.text = args['teamA_name'] ?? '';
      teamBController.text = args['teamB_name'] ?? '';

      // Varsa koordinatları da çek
      selectedLat.value = args['latitude'];
      selectedLng.value = args['longitude'];

      if (args['maxPlayers'] != null) {
        final mp = args['maxPlayers'] as int;
        final side = mp ~/ 2;
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

  // 🔥 YENİ: KONUM SEÇME METODU 🔥
  void setLocation(String name, double lat, double lng) {
    venueController.text = name;
    selectedLat.value = lat;
    selectedLng.value = lng;
    searchQuery.value = ''; // Konum seçilince aramayı temizle
  }

  // 🔥 YENİ: Ana ekrandaki kutudan arama yapıldığında çalışır
  void onVenueSearchChanged(String value) {
    searchQuery.value = value;
    // Kullanıcı elle yeni bir şey yazmaya başladığında eski seçili koordinatı sıfırlıyoruz ki harita kafası karışmasın
    selectedLat.value = null;
    selectedLng.value = null;
  }

  // 🔥 YENİ: HARİTAYI AÇMA METODU 🔥
  // 🔥 YENİ VE GÜVENLİ: HARİTAYI AÇMA METODU 🔥
  Future<void> openMap() async {
    final lat = selectedLat.value;
    final lng = selectedLng.value;
    final venue = venueController.text.trim();

    String urlString;

    if (lat != null && lng != null) {
      // Resmi Google Maps arama URL'si (Koordinat ile)
      urlString = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else if (venue.isNotEmpty) {
      // Resmi Google Maps arama URL'si (İsim ile)
      final encodedVenue = Uri.encodeComponent(venue);
      urlString =
          'https://www.google.com/maps/search/?api=1&query=$encodedVenue';
    } else {
      Get.snackbar(
        'Konum Bulunamadı',
        'Lütfen önce bir saha adı girin veya konum seçin.',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
      );
      return;
    }

    final Uri url = Uri.parse(urlString);

    // Uygulama dışına (Google Maps uygulamasına veya Tarayıcıya) atar
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Harita uygulaması açılamadı.',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
      );
    }
  }

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: AppColors.isDark(context)
              ? const ColorScheme.dark(
                  primary: Color(0xFF2EED7B),
                  onPrimary: Colors.black,
                  surface: Color(0xFF162318),
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: Color(0xFF2EED7B),
                  onPrimary: Colors.white,
                  surface: Color(0xFFFFFFFF),
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

  Future<void> pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime.value ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: AppColors.isDark(context)
              ? const ColorScheme.dark(
                  primary: Color(0xFF2EED7B),
                  onPrimary: Colors.black,
                  surface: Color(0xFF162318),
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: Color(0xFF2EED7B),
                  onPrimary: Colors.white,
                  surface: Color(0xFFFFFFFF),
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

  Future<void> createAndShareMatch() async {
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
    final n = int.tryParse(selectedFormat.value.split('x').first) ?? 7;
    final maxPlayers = n * 2;

    try {
      isLoading.value = true;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Oturum açmış kullanıcı bulunamadı.');
      }
      final uid = user.uid;

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

      final matchData = {
        'title': title,
        'venue': venue,
        'latitude': selectedLat.value, // 🔥 KOORDİNATLAR EKLENDİ
        'longitude': selectedLng.value, // 🔥 KOORDİNATLAR EKLENDİ
        'price': price,
        'maxPlayers': maxPlayers,
        'date': timestamp,
        'createdBy': uid,
        'currentPlayers': [uid],
        'positions': {
          (maxPlayers ~/ 4).toString(): uid // Kaptanı (Kuran Kişiyi) takımın merkez slotuna yerleştir (Örn: 14 max -> 7 takım boyu -> 3. index vs)
        },
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'teamA_name': teamAController.text.trim().isEmpty
            ? 'A Takımı'
            : teamAController.text.trim(),
        'teamB_name': teamBController.text.trim().isEmpty
            ? 'B Takımı'
            : teamBController.text.trim(),
      };

      String generatedMatchId;
      if (isEditing.value && editingMatchId != null) {
        // SADEYCE DÜZENLENEBİLİR ALANLARI GÜNCELLE
        // currentPlayers, positions, createdBy gibi verileri ASLA EZME!
        final updateData = {
          'title': title,
          'venue': venue,
          'latitude': selectedLat.value,
          'longitude': selectedLng.value,
          'price': price,
          'maxPlayers': maxPlayers,
          'date': timestamp,
          'teamA_name': teamAController.text.trim().isEmpty ? 'A Takımı' : teamAController.text.trim(),
          'teamB_name': teamBController.text.trim().isEmpty ? 'B Takımı' : teamBController.text.trim(),
        };
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(editingMatchId)
            .update(updateData);
        generatedMatchId = editingMatchId!;
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('matches')
            .add(matchData);
        generatedMatchId = docRef.id;
      }

      final String deepLink = 'https://halisaha.app/join/$generatedMatchId';
      final String formattedDate = "${date.day}/${date.month}/${date.year}";
      final String formattedTime =
          "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

      Get.back();
      Get.snackbar(
        isEditing.value ? 'Maç Güncellendi! ✏️' : 'Maç Oluşturuldu! 🏆',
        isEditing.value
            ? 'Maç detayları başarıyla güncellendi.'
            : 'Maç başarıyla kaydedildi.',
        backgroundColor: const Color(0xFF1A2E1F),
        colorText: const Color(0xFF2EED7B),
        snackPosition: SnackPosition.BOTTOM,
      );

      final notifCtrl = Get.isRegistered<NotificationsController>()
          ? Get.find<NotificationsController>()
          : Get.put(NotificationsController());
      notifCtrl.addNotification(
        title: isEditing.value
            ? 'Maç Güncellendi ✏️'
            : 'Yeni Maç Oluşturuldu 🏆',
        message: isEditing.value
            ? '"$title" maçının detayları güncellendi.'
            : '"$title" maçı başarıyla kuruldu. Hadi sahaya!',
      );

      if (Get.isRegistered<MyMatchesController>()) {
        Get.find<MyMatchesController>().fetchMyMatches();
      }
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().fetchMatches();
      }

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
