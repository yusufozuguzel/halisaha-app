import '../../../core/services/places_proxy.dart';
import '../../../core/services/places_attribution.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/match_participation.dart';
import '../../friends/controllers/block_controller.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class DiscoverController extends GetxController {
  final RxList<Map<String, dynamic>> _allMatches = <Map<String, dynamic>>[].obs;
  final BlockController _blocks = BlockController.shared;
  List<Map<String, dynamic>> get openMatches => _allMatches
      .where(
        (m) => _blocks.visible((m['createdBy'] ?? m['creatorId']) as String?),
      )
      .toList();
  final RxBool isLoading = true.obs;
  StreamSubscription<QuerySnapshot>? _matchSubscription;
  bool _matchErrorShown = false;

  // 📍 Yakındaki Sahalar
  final List<Map<String, dynamic>> baseVenues = [];
  final RxList<Map<String, dynamic>> nearbyVenues =
      <Map<String, dynamic>>[].obs;
  final RxBool isVenuesLoading = true.obs;

  // 🌍 Yeni Filtre Değişkenleri
  final RxList<String> availableCities = <String>[].obs;
  final RxList<String> availableDistricts = <String>[].obs;
  final RxString selectedCity = ''.obs;
  final RxString selectedDistrict = ''.obs;

  // 🔍 Google Places Arama
  final PlacesProxy _places = PlacesProxy();
  bool _placesUnavailableShown = false;
  void _showPlacesUnavailable() {
    if (isClosed || _placesUnavailableShown) return;
    _placesUnavailableShown = true;
    Get.snackbar('Saha arama', const PlacesUnavailable().message);
  }

  Timer? _debounce;
  Position? _cachedPosition;

  // 🗺️ Harita Görünüm Geçiçi
  final RxBool isMapView = false.obs;
  Position? get userPosition => _cachedPosition;

  void toggleMapView() {
    isMapView.value = !isMapView.value;
  }

  @override
  void onClose() {
    _matchSubscription?.cancel();
    _debounce?.cancel();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    fetchOpenMatches();
    fetchNearbyVenues();
  }

  Future<void> fetchNearbyVenues() async {
    try {
      isVenuesLoading.value = true;

      // 1. Sahaları Firebase'den çek
      final snapshot = await FirebaseFirestore.instance
          .collection('venues')
          .get();
      List<Map<String, dynamic>> allVenues = snapshot.docs.map((doc) {
        final data = doc.data();
        final lat = data['lat'];
        final lng = data['lng'];

        String photoUrl = data['photoUrl'] ?? data['image'] ?? '';

        final address = data['city'] ?? data['address'] ?? 'Bilinmiyor';
        final loc = _parseLocation(address.toString());
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Bilinmiyor',
          'lat': lat,
          'lng': lng,
          'city': loc['city'],
          'district': loc['district'],
          'photoUrl': photoUrl,
          ...placesAttributionMetadata(data, google: false),
        };
      }).toList();

      // 2. Konum kontrolü
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // EĞER GPS YOKSA VEYA İZİN REDDEDİLDİYSE FİREBASE'DEKİLERİ GÖSTER GEÇ
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Konum kullanılamıyor',
          'Sahalar mesafeye göre sıralanmadan gösteriliyor. Konum erişimini cihaz ayarlarından açabilirsiniz.',
        );
        baseVenues
          ..clear()
          ..addAll(allVenues.map(_places.safeCatalogVenue));
        nearbyVenues.assignAll(baseVenues);
        isVenuesLoading.value = false;
        return;
      }

      // 3. Konumu Al
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _cachedPosition = position;

      try {
        final data = await _places.search(
          'hal\u0131 saha OR spor tesisi',
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _placesUnavailableShown = false;
        for (final raw in (data['results'] as List? ?? [])) {
          if (raw is! Map) continue;
          final place = Map<String, dynamic>.from(raw);
          if (allVenues.any((venue) => venue['name'] == place['name']))
            continue;
          final geometry = place['geometry'];
          final location = geometry is Map ? geometry['location'] : null;
          if (location is! Map) continue;
          final address = place['formatted_address']?.toString() ?? '';
          final loc = _parseLocation(address);
          allVenues.add({
            ...place,
            'id': place['place_id'],
            'source': 'google',
            'lat': location['lat'],
            'lng': location['lng'],
            'city': loc['city'],
            'district': loc['district'],
            ...placesAttributionMetadata(
              place,
              responseAttributions: data['html_attributions'],
            ),
          });
        }
      } on PlacesUnavailable {
        _showPlacesUnavailable();
      }

      // 5. MESAFELERİ HESAPLA VE SIRALA
      for (var i = 0; i < allVenues.length; i++) {
        final v = allVenues[i];
        if (v['lat'] != null && v['lng'] != null) {
          final distMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            (v['lat'] as num).toDouble(),
            (v['lng'] as num).toDouble(),
          );
          allVenues[i]['distanceInMeters'] = distMeters;
        } else {
          allVenues[i]['distanceInMeters'] = 9999999.0;
        }
      }

      allVenues.sort(
        (a, b) => (a['distanceInMeters'] as double).compareTo(
          b['distanceInMeters'] as double,
        ),
      );

      // Filtreler için TÜM SAHALARI (allVenues) alıyoruz.
      // Mesafe kısıtlamasını UI seviyesinde kaldırdığımız için
      // veritabanındaki her şehrin dropdown'a düşmesini sağlıyoruz.
      if (isClosed) return;
      nearbyVenues.assignAll(allVenues.map(_places.safeCatalogVenue));
      isVenuesLoading.value = false;
      allVenues = await _places.decorateVisible(allVenues);
      baseVenues.clear();
      baseVenues.addAll(allVenues);

      final cities = baseVenues
          .map((v) => v['city']?.toString().trim() ?? '')
          .where((c) => c.isNotEmpty && c != 'Bilinmiyor')
          .toSet()
          .toList();
      cities.sort();
      availableCities.value = cities;

      applyFilter();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Yakındaki sahalar yüklenirken hata: $e');
      }
    } finally {
      isVenuesLoading.value = false;
    }
  }

  // 🔍 Arama değiştiğinde çağrılır
  void onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      fetchNearbyVenues();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchGooglePlaces(value.trim());
    });
  }

  // 🔍 Google Places API ile manuel saha arama
  Future<void> searchGooglePlaces(String query) async {
    if (query.length < 3) return;
    isVenuesLoading.value = true;
    try {
      final data = await _places.search(
        query.toLowerCase().contains('saha') ? query : '$query hal\u0131 saha',
      );
      final venues = <Map<String, dynamic>>[];
      for (final raw in (data['results'] as List? ?? [])) {
        if (raw is! Map) continue;
        final place = Map<String, dynamic>.from(raw);
        final location = (place['geometry'] as Map?)?['location'];
        if (location is! Map) continue;
        final loc = _parseLocation(
          place['formatted_address']?.toString() ?? '',
        );
        venues.add({
          ...place,
          'source': 'google',
          'id': place['place_id'],
          'lat': location['lat'],
          'lng': location['lng'],
          'city': loc['city'],
          'district': loc['district'],
          ...placesAttributionMetadata(
            place,
            responseAttributions: data['html_attributions'],
          ),
        });
      }
      if (isClosed) return;
      _placesUnavailableShown = false;
      baseVenues
        ..clear()
        ..addAll(venues);
      applyFilter();
      isVenuesLoading.value = false;
      final enriched = await _places.decorateVisible(venues);
      if (isClosed) return;
      baseVenues
        ..clear()
        ..addAll(enriched);
      availableCities.assignAll(
        venues
            .map((v) => v['city']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort(),
      );
      applyFilter();
    } on PlacesUnavailable {
      _showPlacesUnavailable(); // Keep the cached catalog when proxy is unavailable.
    } finally {
      if (!isClosed) isVenuesLoading.value = false;
    }
  }

  void fetchOpenMatches() {
    _matchSubscription?.cancel();
    isLoading.value = true;

    _matchSubscription = FirebaseFirestore.instance
        .collection('matches')
        .where('status', isEqualTo: 'open')
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date')
        .snapshots()
        .listen(
          (QuerySnapshot querySnapshot) {
            if (isClosed) return;
            _matchErrorShown = false;
            _allMatches.value = querySnapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList();

            isLoading.value = false;
          },
          onError: (e) {
            if (isClosed) return;
            if (kDebugMode) {
              debugPrint('Arama (Keşfet) maçları dinlenirken hata oluştu: $e');
            }
            isLoading.value = false;

            if (FirebaseAuth.instance.currentUser == null || _matchErrorShown) {
              return;
            }

            _matchErrorShown = true;
            Get.snackbar(
              'Hata',
              'Maçlar yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
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
      await MatchParticipation().join(matchId);
      Get.snackbar('Başarılı', 'Maç kadrosuna katıldınız.');
    } catch (e) {
      Get.snackbar(
        'Katılım tamamlanamadı',
        e is MatchActionException ? e.message : 'Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> leaveMatch(String matchId, List<dynamic> currentPlayers) async {
    try {
      await MatchParticipation().leave(matchId);
      Get.snackbar('Başarılı', 'Maçtan ayrıldınız.');
    } catch (e) {
      Get.snackbar(
        'İşlem tamamlanamadı',
        e is MatchActionException ? e.message : 'Lütfen tekrar deneyin.',
      );
    }
  }

  Map<String, String> _parseLocation(String address) {
    if (address.isEmpty || address == 'Bilinmiyor') {
      return {'city': 'Bilinmiyor', 'district': ''};
    }

    final parts = address.split(',');
    String targetPart = parts.last;

    for (int i = parts.length - 1; i >= 0; i--) {
      if (parts[i].toLowerCase().contains('türkiye')) {
        if (i > 0) {
          targetPart = parts[i - 1];
        } else {
          targetPart = parts[i];
        }
        break;
      }
    }

    targetPart = targetPart.replaceAll(RegExp(r'\d{5}'), '').trim();

    final slashParts = targetPart.split('/');
    if (slashParts.length >= 2) {
      return {'district': slashParts[0].trim(), 'city': slashParts[1].trim()};
    } else {
      return {'city': targetPart.trim(), 'district': ''};
    }
  }

  void onCityChanged(String? city) {
    selectedCity.value = city ?? '';
    selectedDistrict.value = '';
    availableDistricts.clear();

    if (city != null && city.isNotEmpty) {
      final districts = baseVenues
          .where((v) => v['city']?.toString().trim() == city)
          .map((v) => v['district']?.toString().trim() ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
      districts.sort();
      availableDistricts.value = districts;
    }
  }

  void onDistrictChanged(String? district) {
    selectedDistrict.value = district ?? '';
  }

  void applyFilter() {
    List<Map<String, dynamic>> filtered = List.from(baseVenues);

    final city = selectedCity.value;
    final district = selectedDistrict.value;

    if (city.isNotEmpty) {
      filtered = filtered
          .where((v) => v['city']?.toString().trim() == city)
          .toList();
    }
    if (district.isNotEmpty) {
      filtered = filtered
          .where((v) => v['district']?.toString().trim() == district)
          .toList();
    }

    nearbyVenues.value = filtered;
  }

  void clearFilter() {
    selectedCity.value = '';
    selectedDistrict.value = '';
    availableDistricts.clear();
    applyFilter();
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
