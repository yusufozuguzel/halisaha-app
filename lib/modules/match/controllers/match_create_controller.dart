import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../modules/home/controllers/notifications_controller.dart';
import '../../../modules/home/controllers/home_controller.dart';
import 'my_matches_controller.dart';

class MatchCreateController extends GetxController {
  var currentStep = 0.obs;

  final titleController = TextEditingController();
  final venueController = TextEditingController();
  final priceController = TextEditingController();
  final teamAController = TextEditingController();
  final teamBController = TextEditingController();

  final RxString selectedFormat = '7x7'.obs;

  final selectedDate = Rx<DateTime?>(null);

  // 🔥 YENİ: Tek saat yerine Başlangıç ve Bitiş Saatleri 🔥
  final selectedStartTime = Rx<TimeOfDay?>(null);
  final selectedEndTime = Rx<TimeOfDay?>(null);

  final Rx<double?> selectedLat = Rx<double?>(null);
  final Rx<double?> selectedLng = Rx<double?>(null);
  final RxString selectedVenueId = ''.obs;
  final RxString selectedVenueCity = ''.obs;
  final RxString selectedPhotoUrl = ''.obs;
  final isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isEditing = false.obs;
  String? editingMatchId;

  final List<Map<String, dynamic>> mockLocations = [
    {'name': 'Şampiyonlar Halı Saha, Serdivan', 'lat': 40.7654, 'lng': 30.3712},
    {'name': 'Erenler Spor Kompleksi, Sakarya', 'lat': 40.7589, 'lng': 30.4156},
    {'name': 'Olimpiyat Halı Saha', 'lat': 40.7731, 'lng': 30.3948},
  ];

  final RxList<Map<String, dynamic>> allVenues = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> hybridVenues =
      <Map<String, dynamic>>[].obs;

  // 📍 GPS mesafe sıralaması
  final RxBool isLocationLoading = false.obs;

  final String _googlePlacesApiKey = (dotenv.env['GOOGLE_API_KEY'] ?? '')
      .trim();
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    print("-----------------------------------------");
    print("🚨 BALYOZ MODU AKTİF 🚨");
    print("DEBUG: API ANAHTARI ZORLA KODA GÖMÜLDÜ -> '$_googlePlacesApiKey'");
    print("-----------------------------------------");

    _checkEditMode();
    fetchVenues();
  }

  Future<void> fetchVenues() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('venues')
          .get();
      final venues = snapshot.docs
          .map(
            (doc) => {
              'id': doc.id,
              'name': doc['name'],
              'lat': doc['lat'],
              'lng': doc['lng'],
              'city': doc.data().containsKey('city')
                  ? doc['city']
                  : 'Bilinmiyor',
            },
          )
          .toList();

      Future.microtask(() {
        allVenues.value = venues;
        if (searchQuery.value.isEmpty) {
          hybridVenues.value = venues;
        } else {
          applyFilters();
        }
      });
    } catch (e) {
      print("Sahalar çekilirken hata oluştu: $e");
      Future.microtask(() {
        allVenues.value = mockLocations;
        if (searchQuery.value.isEmpty) {
          hybridVenues.value = mockLocations;
        } else {
          applyFilters();
        }
      });
    }
  }

  void applyFilters() {
    List<Map<String, dynamic>> result = List.from(allVenues);

    // Arama filtresi
    if (searchQuery.value.isNotEmpty) {
      result = result
          .where(
            (v) => v['name'].toString().toLowerCase().contains(
              searchQuery.value.toLowerCase(),
            ),
          )
          .toList();
    }

    hybridVenues.value = result;
  }

  Future<void> sortByDistance() async {
    try {
      isLocationLoading.value = true;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'Konum İzni',
            'Konum izni verilmedi.',
            backgroundColor: Colors.red[900],
            colorText: Colors.white,
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Konum İzni',
          'Konum izni kalıcı olarak reddedildi. Ayarlardan açınız.',
          backgroundColor: Colors.red[900],
          colorText: Colors.white,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final sorted = hybridVenues.map((v) {
        final distMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          (v['lat'] as num).toDouble(),
          (v['lng'] as num).toDouble(),
        );
        return {...v, 'distanceInMeters': distMeters};
      }).toList();

      sorted.sort(
        (a, b) => (a['distanceInMeters'] as double).compareTo(
          b['distanceInMeters'] as double,
        ),
      );

      hybridVenues.value = sorted;
    } catch (e) {
      print('Konum hatası: $e');
      Get.snackbar(
        'Hata',
        'Konum alınamadı: $e',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
      );
    } finally {
      isLocationLoading.value = false;
    }
  }

  List<Map<String, dynamic>> get filteredLocations => hybridVenues;

  Future<void> searchGooglePlaces(String query) async {
    if (query.length < 3) return;

    try {
      final encodedQuery = Uri.encodeComponent(
        '$query halı saha OR stadyum OR spor tesisi',
      );
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$encodedQuery&key=$_googlePlacesApiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          final excludedTypes = [
            'cafe',
            'restaurant',
            'bar',
            'bakery',
            'meal_delivery',
            'meal_takeaway',
            'food',
            'store',
            'clothing_store',
            'grocery_or_supermarket',
            'supermarket',
            'pharmacy',
            'hospital',
            'health',
            'doctor',
            'dentist',
            'lodging',
            'hotel',
            'spa',
            'beauty_salon',
            'hair_care',
          ];

          final filteredResults = results.where((place) {
            final types = List<String>.from(place['types'] ?? []);
            return !types.any((type) => excludedTypes.contains(type));
          }).toList();

          List<Map<String, dynamic>> googleVenues = filteredResults
              .map(
                (place) => {
                  'id': place['place_id'],
                  'name': place['name'] ?? place['formatted_address'],
                  'lat': place['geometry']['location']['lat'],
                  'lng': place['geometry']['location']['lng'],
                  'source': 'google',
                  'address': place['formatted_address'],
                },
              )
              .toList();

          final localMatches = allVenues
              .where(
                (loc) => loc['name'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();
          final Set<String> localNames = localMatches
              .map((v) => (v['name'] as String).toLowerCase())
              .toSet();
          final filteredGoogleVenues = googleVenues
              .where(
                (v) =>
                    !localNames.contains((v['name'] as String).toLowerCase()),
              )
              .toList();

          Future.microtask(() {
            hybridVenues.value = [...localMatches, ...filteredGoogleVenues];
          });
        }
      }
    } catch (e) {
      print("Google Places arama hatası: $e");
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

      selectedLat.value = args['latitude'];
      selectedLng.value = args['longitude'];
      selectedVenueId.value = args['venueId'] ?? '';

      if (args['maxPlayers'] != null) {
        final mp = args['maxPlayers'] as int;
        final side = mp ~/ 2;
        if (side >= 5 && side <= 11) selectedFormat.value = '${side}x$side';
      }

      // 🔥 YENİ: Edit modunda hem başlangıç hem bitiş saatini doldur
      if (args['date'] is Timestamp) {
        final dt = (args['date'] as Timestamp).toDate();
        selectedDate.value = dt;
        selectedStartTime.value = TimeOfDay(hour: dt.hour, minute: dt.minute);

        if (args['endDate'] is Timestamp) {
          final endDt = (args['endDate'] as Timestamp).toDate();
          selectedEndTime.value = TimeOfDay(
            hour: endDt.hour,
            minute: endDt.minute,
          );
        } else {
          selectedEndTime.value = TimeOfDay(
            hour: (dt.hour + 1) % 24,
            minute: dt.minute,
          );
        }
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

  Future<void> setLocation(
    String name,
    double lat,
    double lng, {
    String? source,
    String? id,
    String? address,
    String? photoUrl, // 🔥 YENİ EKLENDİ
  }) async {
    venueController.text = name;
    Future.microtask(() {
      selectedLat.value = lat;
      selectedLng.value = lng;
      selectedVenueId.value = id ?? '';
      selectedVenueCity.value = address ?? '';
      selectedPhotoUrl.value = photoUrl ?? ''; // 🔥 YENİ EKLENDİ
      searchQuery.value = '';
      hybridVenues.value = allVenues;
    });
  }

  void onVenueSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    Future.microtask(() {
      searchQuery.value = value;
      selectedLat.value = null;
      selectedLng.value = null;
      applyFilters();
    });

    if (value.isNotEmpty) {
      _debounce = Timer(
        const Duration(milliseconds: 500),
        () => searchGooglePlaces(value),
      );
    }
  }

  Future<void> openMap() async {
    final lat = selectedLat.value;
    final lng = selectedLng.value;
    final venue = venueController.text.trim();

    String urlString;
    if (lat != null && lng != null) {
      urlString = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else if (venue.isNotEmpty) {
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

    try {
      await launchUrl(
        Uri.parse(urlString),
        mode: LaunchMode.externalApplication,
      );
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
      builder: (context, child) => _buildPickerTheme(context, child!),
    );
    if (picked != null) selectedDate.value = picked;
  }

  // 🔥 HİBRİT SAAT SEÇİCİ: 24 SAAT FORMATLI (AM/PM YOK) 🔥
  Future<void> pickTime(BuildContext context, {required bool isStart}) async {
    DateTime now = DateTime.now();
    DateTime initialDateTime;

    if (isStart) {
      initialDateTime = selectedStartTime.value != null
          ? DateTime(
              now.year,
              now.month,
              now.day,
              selectedStartTime.value!.hour,
              selectedStartTime.value!.minute,
            )
          : now;
    } else {
      initialDateTime = selectedEndTime.value != null
          ? DateTime(
              now.year,
              now.month,
              now.day,
              selectedEndTime.value!.hour,
              selectedEndTime.value!.minute,
            )
          : now.add(const Duration(hours: 1));
    }

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: AppColors.isDark(context)
            ? const Color(0xFF162318)
            : Colors.white,
        child: Column(
          children: [
            // Üst Onay Barı
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Icon(
                      Icons.keyboard_outlined,
                      color: Color(0xFF2EED7B),
                    ),
                    onPressed: () {
                      Get.back();
                      _pickTimeWithKeyboard(context, isStart: isStart);
                    },
                  ),
                  Text(
                    isStart ? 'Başlangıç' : 'Bitiş',
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  CupertinoButton(
                    child: const Text(
                      'Tamam',
                      style: TextStyle(
                        color: Color(0xFF2EED7B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            // 24 Saatlik Tekerlek
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true, // 👈 AM/PM'i tekerlekten kaldıran ayar!
                initialDateTime: initialDateTime,
                onDateTimeChanged: (DateTime newDate) {
                  final picked = TimeOfDay(
                    hour: newDate.hour,
                    minute: newDate.minute,
                  );
                  _updateTime(picked, isStart);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Klavye Girişi (Burada da 24 saat zorunlu) 🔥
  Future<void> _pickTimeWithKeyboard(
    BuildContext context, {
    required bool isStart,
  }) async {
    final initial = isStart
        ? (selectedStartTime.value ?? TimeOfDay.now())
        : (selectedEndTime.value ?? TimeOfDay.now());

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (context, child) => MediaQuery(
        // 👈 Klavyeli girişte de 24 saat formatını zorluyoruz
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: _buildPickerTheme(context, child!),
      ),
    );

    if (picked != null) {
      _updateTime(picked, isStart);
    }
  }

  void _updateTime(TimeOfDay picked, bool isStart) {
    // 🔥 YUVARLAMA İPTAL! Adam kaçı seçerse saniyesi saniyesine o kaydedilecek.
    final exactTime = TimeOfDay(hour: picked.hour, minute: picked.minute);

    if (isStart) {
      selectedStartTime.value = exactTime;

      // 🔥 Otomatik 1 saat ileri atma: Başlangıç seçildiği ANDA bitişi 1 saat sonrasına kur
      selectedEndTime.value = TimeOfDay(
        hour: (picked.hour + 1) % 24,
        minute: picked.minute,
      );
    } else {
      selectedEndTime.value = exactTime;
    }
  }

  // Tema kodunu tekrar etmemek için yardımcı metot
  Widget _buildPickerTheme(BuildContext context, Widget child) {
    return Theme(
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
      child: child,
    );
  }

  Future<void> createAndShareMatch() async {
    final title = titleController.text.trim();
    final venue = venueController.text.trim();
    final priceStr = priceController.text.trim();

    // 🔥 KONTROL: Tüm saatler seçilmiş mi?
    if (title.isEmpty ||
        venue.isEmpty ||
        priceStr.isEmpty ||
        selectedDate.value == null ||
        selectedStartTime.value == null ||
        selectedEndTime.value == null) {
      Get.snackbar(
        'Eksik Bilgi',
        'Lütfen tüm alanları doldurun ve başlangıç/bitiş saati seçin.',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final date = selectedDate.value!;
    final sTime = selectedStartTime.value!;
    final eTime = selectedEndTime.value!;

    final combinedStartDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      sTime.hour,
      sTime.minute,
    );
    var combinedEndDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      eTime.hour,
      eTime.minute,
    );

    // 🔥 KONTROL 1: GEÇMİŞ ZAMAN KONTROLÜ 🔥
    if (combinedStartDateTime.isBefore(DateTime.now())) {
      Get.snackbar(
        'Geçersiz Saat',
        'Geçmiş tarihe veya saate maç kurulamaz!',
        backgroundColor: Colors.red[900],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // 🔥 KONTROL 2: BİTİŞ SAATİ VE MİNİMUM SÜRE KONTROLÜ 🔥
    final difference = combinedEndDateTime.difference(combinedStartDateTime);
    if (!combinedEndDateTime.isAfter(combinedStartDateTime) ||
        difference.inMinutes < 30) {
      Get.snackbar(
        'Geçersiz Saat',
        'Hata: Bitiş saati, başlama saatinden önce veya aynı olamaz!',
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
      if (user == null) throw Exception('Oturum açmış kullanıcı bulunamadı.');
      final uid = user.uid;

      final bool isFirebaseVenue = allVenues.any(
        (v) => v['id'] == selectedVenueId.value,
      );
      if (!isFirebaseVenue) {
        try {
          final docRef = selectedVenueId.value.isNotEmpty
              ? FirebaseFirestore.instance
                    .collection('venues')
                    .doc(selectedVenueId.value)
              : FirebaseFirestore.instance.collection('venues').doc();
          await docRef.set({
            'name': venue,
            'lat': selectedLat.value,
            'lng': selectedLng.value,
            'city': selectedVenueCity.value.isNotEmpty
                ? selectedVenueCity.value
                : 'Bilinmiyor',
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          selectedVenueId.value = docRef.id;
          fetchVenues();
        } catch (e) {
          print("Saha Firebase'e kaydedilirken hata oluştu: $e");
        }
      }

      final startTimestamp = Timestamp.fromDate(combinedStartDateTime);
      final endTimestamp = Timestamp.fromDate(
        combinedEndDateTime,
      ); // 🔥 YENİ: Bitiş tarihini de kaydediyoruz

      final matchData = {
        'title': title,
        'venue': venue,
        'venuePhotoUrl': selectedPhotoUrl.value,
        'venueId': selectedVenueId.value,
        'latitude': selectedLat.value,
        'longitude': selectedLng.value,
        'price': price, 'maxPlayers': maxPlayers,
        'date': startTimestamp,
        'endDate': endTimestamp, // Veritabanına bitişi yazıyoruz
        'createdBy': uid, 'creatorId': uid, 'currentPlayers': [uid],
        'positions': {(maxPlayers ~/ 4).toString(): uid},
        'status': 'open', 'createdAt': FieldValue.serverTimestamp(),
        'teamA_name': teamAController.text.trim().isEmpty
            ? 'A Takımı'
            : teamAController.text.trim(),
        'teamB_name': teamBController.text.trim().isEmpty
            ? 'B Takımı'
            : teamBController.text.trim(),
      };

      String generatedMatchId;
      if (isEditing.value && editingMatchId != null) {
        final updateData = {
          'title': title,
          'venue': venue,
          'venueId': selectedVenueId.value,
          'latitude': selectedLat.value,
          'longitude': selectedLng.value,
          'price': price,
          'maxPlayers': maxPlayers,
          'date': startTimestamp,
          'endDate': endTimestamp,
          'teamA_name': teamAController.text.trim().isEmpty
              ? 'A Takımı'
              : teamAController.text.trim(),
          'teamB_name': teamBController.text.trim().isEmpty
              ? 'B Takımı'
              : teamBController.text.trim(),
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
      final String startStr =
          "${sTime.hour.toString().padLeft(2, '0')}:${sTime.minute.toString().padLeft(2, '0')}";
      final String endStr =
          "${eTime.hour.toString().padLeft(2, '0')}:${eTime.minute.toString().padLeft(2, '0')}";

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

      if (Get.isRegistered<MyMatchesController>())
        Get.find<MyMatchesController>().fetchMyMatches();
      if (Get.isRegistered<HomeController>())
        Get.find<HomeController>().fetchMatches();

      if (!isEditing.value) {
        await Share.share(
          '⚽ Yeni bir maça davetlisin!\n\nMaç: $title\n📅 $formattedDate - ⏰ $startStr - $endStr\n📍 $venue\n\nMaça katılmak için hemen tıkla:\n$deepLink',
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
