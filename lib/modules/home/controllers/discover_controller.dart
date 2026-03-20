import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DiscoverController extends GetxController {
  final RxList<Map<String, dynamic>> openMatches = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  StreamSubscription<QuerySnapshot>? _matchSubscription;

  // 📍 Yakındaki Sahalar
  final RxList<Map<String, dynamic>> nearbyVenues =
      <Map<String, dynamic>>[].obs;
  final RxBool isVenuesLoading = true.obs;

  // 🔍 Google Places Arama
  final String _googlePlacesApiKey = (dotenv.env['GOOGLE_API_KEY'] ?? '')
      .trim();
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

        if (photoUrl.isEmpty || photoUrl == 'null') {
          if (lat != null && lng != null) {
            photoUrl =
                'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=18&size=600x400&maptype=satellite&key=$_googlePlacesApiKey';
          }
        }

        return {
          'id': doc.id,
          'name': data['name'] ?? 'Bilinmiyor',
          'lat': lat,
          'lng': lng,
          'city': data['city'] ?? 'Bilinmiyor',
          'photoUrl': photoUrl,
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
        nearbyVenues.value = allVenues;
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

      // 4. GOOGLE PLACES API İLE OTOMATİK ÇEKİM
      if (_googlePlacesApiKey.isNotEmpty) {
        try {
          final encodedQuery = Uri.encodeComponent('halı saha OR spor tesisi');
          final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$encodedQuery&location=${position.latitude},${position.longitude}&radius=30000&key=$_googlePlacesApiKey',
          );
          final response = await http.get(url);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK') {
              final results = data['results'] as List;
              for (var place in results) {
                bool exists = allVenues.any((v) => v['name'] == place['name']);
                if (!exists) {
                  String photoUrl = '';
                  if (place['photos'] != null &&
                      (place['photos'] as List).isNotEmpty) {
                    final photoRef = place['photos'][0]['photo_reference'];
                    photoUrl =
                        'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$_googlePlacesApiKey';
                  } else if (place['geometry'] != null) {
                    final pLat = place['geometry']['location']['lat'];
                    final pLng = place['geometry']['location']['lng'];
                    photoUrl =
                        'https://maps.googleapis.com/maps/api/staticmap?center=$pLat,$pLng&zoom=18&size=600x400&maptype=satellite&key=$_googlePlacesApiKey';
                  }

                  allVenues.add({
                    'id': place['place_id'],
                    'name': place['name'] ?? place['formatted_address'],
                    'lat': place['geometry']['location']['lat'],
                    'lng': place['geometry']['location']['lng'],
                    'city': place['formatted_address'] ?? '',
                    'source': 'google',
                    'photoUrl': photoUrl,
                  });
                }
              }
            } else {
              // Eğer Google API Key bozuksa veya yetki yoksa terminale yazdıracak
              print("🚨 GOOGLE API HATASI: ${data['status']}");
            }
          }
        } catch (e) {
          print('Google otomatik çekim hatası: $e');
        }
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

      // 6. 75 KM FİLTRESİ
      final List<Map<String, dynamic>> filteredList = allVenues
          .where((v) => (v['distanceInMeters'] as double) <= 75000)
          .toList();

      // 🔥 HAYAT KURTARAN DOKUNUŞ: Ekran asla boş kalmasın! 75km içinde saha yoksa en yakın 5 tanesini zorla göster.
      if (filteredList.isNotEmpty) {
        nearbyVenues.value = filteredList;
      } else {
        nearbyVenues.value = allVenues.take(5).toList();
      }
    } catch (e) {
      print('Yakındaki sahalar yüklenirken hata: $e');
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

    try {
      isVenuesLoading.value = true;

      String lowerQuery = query.toLowerCase();
      String apiQuery = lowerQuery.contains('saha') || lowerQuery.contains('spor')
          ? query
          : '$query halı saha';

      final encodedQuery = Uri.encodeComponent(apiQuery);
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

          List<Map<String, dynamic>> googleVenues = filteredResults.map((
            place,
          ) {
            String photoUrl = '';
            if (place['photos'] != null &&
                (place['photos'] as List).isNotEmpty) {
              final photoRef = place['photos'][0]['photo_reference'];
              photoUrl =
                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$_googlePlacesApiKey';
            } else if (place['geometry'] != null) {
              final pLat = place['geometry']['location']['lat'];
              final pLng = place['geometry']['location']['lng'];
              photoUrl =
                  'https://maps.googleapis.com/maps/api/staticmap?center=$pLat,$pLng&zoom=18&size=600x400&maptype=satellite&key=$_googlePlacesApiKey';
            }

            return <String, dynamic>{
              'id': place['place_id'],
              'name': place['name'] ?? place['formatted_address'],
              'lat': place['geometry']['location']['lat'],
              'lng': place['geometry']['location']['lng'],
              'city': place['formatted_address'] ?? '',
              'source': 'google',
              'photoUrl': photoUrl,
            };
          }).toList();

          if (_cachedPosition != null) {
            googleVenues = googleVenues.map((v) {
              final dist = Geolocator.distanceBetween(
                _cachedPosition!.latitude,
                _cachedPosition!.longitude,
                (v['lat'] as num).toDouble(),
                (v['lng'] as num).toDouble(),
              );
              return {...v, 'distanceInMeters': dist};
            }).toList();

            googleVenues.sort(
              (a, b) => (a['distanceInMeters'] as double).compareTo(
                b['distanceInMeters'] as double,
              ),
            );
          }

          nearbyVenues.value = googleVenues;
        } else {
          nearbyVenues.clear();
        }
      }
    } catch (e) {
      print('Google Places arama hatası: $e');
    } finally {
      isVenuesLoading.value = false;
    }
  }

  void fetchOpenMatches() {
    isLoading.value = true;

    _matchSubscription = FirebaseFirestore.instance
        .collection('matches')
        .where('status', isEqualTo: 'open')
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date')
        .snapshots()
        .listen(
          (QuerySnapshot querySnapshot) {
            openMatches.value = querySnapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList();

            isLoading.value = false;
          },
          onError: (e) {
            print('Arama (Keşfet) maçları dinlenirken hata oluştu: $e');
            isLoading.value = false;

            if (FirebaseAuth.instance.currentUser == null) {
              return;
            }

            Get.snackbar(
              'Hata',
              'Maçlar yüklenirken bir sorun oluştu: $e',
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar(
          'Oturum Hatası',
          'İşlem yapabilmek için lütfen tekrar giriş yapın',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
        return;
      }

      final uid = user.uid;

      if (currentPlayers.contains(uid)) {
        Get.snackbar(
          'Zaten Kadrodasın',
          'Bu maça daha önce kayıt oldunuz.',
          backgroundColor: Colors.amber.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      if (currentPlayers.length >= maxPlayers) {
        Get.snackbar(
          'Kontenjan Dolu',
          'Maalesef bu maç için yer kalmadı.',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .update({
            'currentPlayers': FieldValue.arrayUnion([uid]),
          });

      Get.snackbar(
        'Başarılı',
        'Maça kadrosuna eklendiniz! Kramponları hazırlayın.',
        backgroundColor: Colors.greenAccent.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );

      fetchOpenMatches();
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Bir hata oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  Future<void> leaveMatch(String matchId, List<dynamic> currentPlayers) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar(
          'Oturum Hatası',
          'İşlem yapabilmek için lütfen tekrar giriş yapın',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
        return;
      }

      final uid = user.uid;

      if (!currentPlayers.contains(uid)) {
        return;
      }

      await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .update({
            'currentPlayers': FieldValue.arrayRemove([uid]),
          });

      Get.snackbar(
        'Başarılı',
        'Maçtan başarıyla ayrıldınız.',
        backgroundColor: Colors.greenAccent.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Bir hata oluştu: $e',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
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
