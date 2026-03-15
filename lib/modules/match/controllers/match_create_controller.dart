import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
// dotenv kütüphanesini bilerek devredışı bırakmıyorum, diğer yerlerde lazım olabilir ama bu dosyada kullanmayacağız.
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

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
  final selectedTime = Rx<TimeOfDay?>(null);

  final Rx<double?> selectedLat = Rx<double?>(null);
  final Rx<double?> selectedLng = Rx<double?>(null);
  final RxString selectedVenueId = ''.obs; 
  final RxString selectedVenueCity = ''.obs; 

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
  final RxList<Map<String, dynamic>> hybridVenues = <Map<String, dynamic>>[].obs;
  
// .env'den okuyoruz ama sonuna .trim() ekleyerek Onur'un bilgisayarındaki o gizli Windows boşluklarını YOK EDİYORUZ!
  final String _googlePlacesApiKey = (dotenv.env['GOOGLE_API_KEY'] ?? '').trim();

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
            },
          )
          .toList();

      Future.microtask(() {
        allVenues.value = venues;
        if (searchQuery.value.isEmpty) {
          hybridVenues.value = venues;
        }
      });
    } catch (e) {
      print("Sahalar çekilirken hata oluştu: $e");
      Future.microtask(() {
        allVenues.value = mockLocations;
        if (searchQuery.value.isEmpty) {
          hybridVenues.value = mockLocations;
        }
      });
    }
  }

  List<Map<String, dynamic>> get filteredLocations {
    return hybridVenues;
  }

  Future<void> searchGooglePlaces(String query) async {
    if (query.length < 3) return; 

    try {
      final encodedQuery = Uri.encodeComponent('$query halı saha OR stadyum OR spor tesisi');
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$encodedQuery&key=$_googlePlacesApiKey'
      );

      print("🕵️ DEBUG: GOOGLE'A İSTEK ATILIYOR... (Aranan: $query)");

      final response = await http.get(url);
      print("🕵️ DEBUG: HTTP CEVAP KODU -> ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("🕵️ DEBUG: GOOGLE'IN YANITI -> ${data['status']}");

        if (data['status'] == 'OK') {
          final results = data['results'] as List;

          final excludedTypes = [
            'cafe', 'restaurant', 'bar', 'bakery', 'meal_delivery', 'meal_takeaway', 'food',
            'store', 'clothing_store', 'grocery_or_supermarket', 'supermarket', 'pharmacy',
            'hospital', 'health', 'doctor', 'dentist',
            'lodging', 'hotel', 'spa', 'beauty_salon', 'hair_care'
          ];
          
          final filteredResults = results.where((place) {
            final types = List<String>.from(place['types'] ?? []);
            if (types.any((type) => excludedTypes.contains(type))) {
              return false;
            }
            return true;
          }).toList();
          
          List<Map<String, dynamic>> googleVenues = filteredResults.map((place) => {
            'id': place['place_id'],
            'name': place['name'] ?? place['formatted_address'],
            'lat': place['geometry']['location']['lat'],
            'lng': place['geometry']['location']['lng'],
            'source': 'google', 
            'address': place['formatted_address'],
          }).toList();

          final localMatches = allVenues.where(
            (loc) => loc['name'].toString().toLowerCase().contains(query.toLowerCase())
          ).toList();

          final Set<String> localNames = localMatches.map((v) => (v['name'] as String).toLowerCase()).toSet();
          final filteredGoogleVenues = googleVenues.where((v) => !localNames.contains((v['name'] as String).toLowerCase())).toList();

          Future.microtask(() {
            hybridVenues.value = [...localMatches, ...filteredGoogleVenues];
          });
        } else {
          print("🚨🚨 DEBUG KIZIL ALARM: GOOGLE BİZİ REDDETTİ! SEBEP: ${data['error_message']} 🚨🚨");
        }
      } else {
        print("🚨 DEBUG: SUNUCU ÇÖKTÜ VEYA İNTERNET YOK! HTTP KODU: ${response.statusCode}");
      }
    } catch (e) {
      print("Google Places arama hatası: $e");
    }
  }

  Future<void> uploadInitialVenues() async {
    final db = FirebaseFirestore.instance;
    isLoading.value = true;
    try {
      for (var loc in mockLocations) {
        await db.collection('venues').add({
          'name': loc['name'],
          'lat': loc['lat'],
          'lng': loc['lng'],
          'city': 'Sakarya', 
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      Get.snackbar('Başarılı', 'Sahalar Firebase\'e yüklendi!', backgroundColor: Colors.green[800], colorText: Colors.white);
      await fetchVenues(); 
    } catch (e) {
      Get.snackbar('Hata', 'Yüklenemedi: $e', backgroundColor: Colors.red[900], colorText: Colors.white);
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

      selectedLat.value = args['latitude'];
      selectedLng.value = args['longitude'];
      selectedVenueId.value = args['venueId'] ?? ''; 

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

  Future<void> setLocation(String name, double lat, double lng, {String? source, String? id, String? address}) async {
    venueController.text = name;
    
    Future.microtask(() {
      selectedLat.value = lat;
      selectedLng.value = lng;
      selectedVenueId.value = id ?? ''; 
      selectedVenueCity.value = address ?? '';
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

      if (value.isEmpty) {
        hybridVenues.value = allVenues;
      } else {
        final localMatches = allVenues.where(
          (loc) => loc['name'].toString().toLowerCase().contains(value.toLowerCase())
        ).toList();
        hybridVenues.value = localMatches;
      }
    });

    if (value.isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 500), () {
        searchGooglePlaces(value);
      });
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
      urlString = 'https://www.google.com/maps/search/?api=1&query=$encodedVenue';
    } else {
      Get.snackbar('Konum Bulunamadı', 'Lütfen önce bir saha adı girin veya konum seçin.', backgroundColor: Colors.red[900], colorText: Colors.white);
      return;
    }

    final Uri url = Uri.parse(urlString);

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      Get.snackbar('Hata', 'Harita uygulaması açılamadı.', backgroundColor: Colors.red[900], colorText: Colors.white);
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
              ? const ColorScheme.dark(primary: Color(0xFF2EED7B), onPrimary: Colors.black, surface: Color(0xFF162318), onSurface: Colors.white)
              : const ColorScheme.light(primary: Color(0xFF2EED7B), onPrimary: Colors.white, surface: Color(0xFFFFFFFF), onSurface: Colors.black),
          dialogBackgroundColor: AppColors.card(context),
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
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: AppColors.isDark(context)
              ? const ColorScheme.dark(primary: Color(0xFF2EED7B), onPrimary: Colors.black, surface: Color(0xFF162318), onSurface: Colors.white)
              : const ColorScheme.light(primary: Color(0xFF2EED7B), onPrimary: Colors.white, surface: Color(0xFFFFFFFF), onSurface: Colors.black),
          dialogBackgroundColor: AppColors.card(context),
        ),
        child: MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
      ),
    );
    if (picked != null) selectedTime.value = picked;
  }

  Future<void> createAndShareMatch() async {
    final title = titleController.text.trim();
    final venue = venueController.text.trim();
    final priceStr = priceController.text.trim();

    if (title.isEmpty || venue.isEmpty || priceStr.isEmpty || selectedDate.value == null || selectedTime.value == null) {
      Get.snackbar('Eksik Bilgi', 'Lütfen tüm alanları doldurun ve tarih/saat seçin.', backgroundColor: Colors.red[900], colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
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

      final bool isFirebaseVenue = allVenues.any((v) => v['id'] == selectedVenueId.value);
      
      if (!isFirebaseVenue) {
        try {
          final docRef = selectedVenueId.value.isNotEmpty 
              ? FirebaseFirestore.instance.collection('venues').doc(selectedVenueId.value)
              : FirebaseFirestore.instance.collection('venues').doc(); 
              
          await docRef.set({
            'name': venue, 
            'lat': selectedLat.value,
            'lng': selectedLng.value,
            'city': selectedVenueCity.value.isNotEmpty ? selectedVenueCity.value : 'Bilinmiyor',
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          selectedVenueId.value = docRef.id; 
          fetchVenues();
        } catch (e) {
          print("Saha Firebase'e kaydedilirken hata oluştu: $e");
        }
      }

      final date = selectedDate.value!;
      final time = selectedTime.value!;
      final combinedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      final timestamp = Timestamp.fromDate(combinedDateTime);

      final matchData = {
        'title': title,
        'venue': venue,
        'venueId': selectedVenueId.value,
        'latitude': selectedLat.value, 
        'longitude': selectedLng.value, 
        'price': price,
        'maxPlayers': maxPlayers,
        'date': timestamp,
        'createdBy': uid,
        'creatorId': uid, 
        'currentPlayers': [uid],
        'positions': { (maxPlayers ~/ 4).toString(): uid },
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'teamA_name': teamAController.text.trim().isEmpty ? 'A Takımı' : teamAController.text.trim(),
        'teamB_name': teamBController.text.trim().isEmpty ? 'B Takımı' : teamBController.text.trim(),
      };

      String generatedMatchId;
      if (isEditing.value && editingMatchId != null) {
        final updateData = {
          'title': title, 'venue': venue, 'venueId': selectedVenueId.value, 'latitude': selectedLat.value, 'longitude': selectedLng.value,
          'price': price, 'maxPlayers': maxPlayers, 'date': timestamp,
          'teamA_name': teamAController.text.trim().isEmpty ? 'A Takımı' : teamAController.text.trim(),
          'teamB_name': teamBController.text.trim().isEmpty ? 'B Takımı' : teamBController.text.trim(),
        };
        await FirebaseFirestore.instance.collection('matches').doc(editingMatchId).update(updateData);
        generatedMatchId = editingMatchId!;
      } else {
        final docRef = await FirebaseFirestore.instance.collection('matches').add(matchData);
        generatedMatchId = docRef.id;
      }

      final String deepLink = 'https://halisaha.app/join/$generatedMatchId';
      final String formattedDate = "${date.day}/${date.month}/${date.year}";
      final String formattedTime = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

      Get.back();
      Get.snackbar(
        isEditing.value ? 'Maç Güncellendi! ✏️' : 'Maç Oluşturuldu! 🏆',
        isEditing.value ? 'Maç detayları başarıyla güncellendi.' : 'Maç başarıyla kaydedildi.',
        backgroundColor: const Color(0xFF1A2E1F), colorText: const Color(0xFF2EED7B), snackPosition: SnackPosition.BOTTOM,
      );

      final notifCtrl = Get.isRegistered<NotificationsController>() ? Get.find<NotificationsController>() : Get.put(NotificationsController());
      notifCtrl.addNotification(
        title: isEditing.value ? 'Maç Güncellendi ✏️' : 'Yeni Maç Oluşturuldu 🏆',
        message: isEditing.value ? '"$title" maçının detayları güncellendi.' : '"$title" maçı başarıyla kuruldu. Hadi sahaya!',
      );

      if (Get.isRegistered<MyMatchesController>()) Get.find<MyMatchesController>().fetchMyMatches();
      if (Get.isRegistered<HomeController>()) Get.find<HomeController>().fetchMatches();

      if (!isEditing.value) {
        await Share.share('⚽ Yeni bir maça davetlisin!\n\nMaç: $title\n📅 $formattedDate - ⏰ $formattedTime\n📍 $venue\n\nMaça katılmak için hemen tıkla:\n$deepLink', subject: 'Halı Saha Maç Daveti');
      }
    } catch (e) {
      Get.snackbar('Hata', 'Maç oluşturulamadı: $e', backgroundColor: Colors.red[900], colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }
}