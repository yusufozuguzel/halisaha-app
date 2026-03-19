import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../match/models/match_model.dart';
import '../../match/services/match_service.dart';
import '../models/activity_model.dart';

class HomeController extends GetxController {
  // Backend servisimizi çağırıyoruz
  final MatchService _matchService = MatchService();

  // Firebase'den gelecek maçları tutacağımız reaktif (canlı) liste
  final RxList<MatchModel> upcomingMatches = <MatchModel>[].obs;

  // Veriler yüklenirken ekranda dönen top/loading efekti için
  final RxBool isLoading = true.obs;

  // Kullanıcının sıradaki (yaklaşan en yakın) maçı
  final Rx<MatchModel?> nextMatch = Rx<MatchModel?>(null);
  final RxBool isNextMatchLoading = true.obs;

  // --- Günün Sahaları ---
  final RxList<Map<String, dynamic>> dailyVenues = <Map<String, dynamic>>[].obs;
  final RxBool isVenuesLoading = true.obs;

  // --- Arkadaşların Neler Yapıyor? (Social Feed) ---
  final RxList<ActivityModel> friendActivities = <ActivityModel>[].obs;
  final RxBool isActivitiesLoading = true.obs;
  final int _feedDaysLimit = 7; // Son 7 günün aktiviteleri

  @override
  void onInit() {
    super.onInit();
    // Ana sayfa açılır açılmaz maçları çekmeye başla!
    fetchMatches();
    fetchNextMatch();
    fetchFriendActivities();
    fetchDailyVenues();
  }

  Future<void> fetchDailyVenues() async {
    try {
      isVenuesLoading.value = true;
      final snapshot = await FirebaseFirestore.instance.collection('venues').get();
      final String googleApiKey = (dotenv.env['GOOGLE_API_KEY'] ?? '').trim();

      final venues = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final lat = data['lat'];
        final lng = data['lng'];
        
        // placeId kontrolü (Firebase'de id, placeId veya place_id olarak kayıtlı olabilir)
        final placeId = data['placeId'] ?? data['place_id'] ?? data['id'] ?? doc.id;

        String photoUrl = data['photoUrl']?.toString() ?? data['image']?.toString() ?? '';

        if (photoUrl.isEmpty || photoUrl == 'null') {
          if (data['photo_reference'] != null) {
            final photoRef = data['photo_reference'];
            photoUrl =
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$googleApiKey';
          } else if (data['photos'] != null && (data['photos'] as List).isNotEmpty) {
            final photoRef = data['photos'][0]['photo_reference'];
            photoUrl =
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$googleApiKey';
          }
        }

        // Eğer hala photoUrl boşsa ve placeId varsa Google API'ye soralım
        if ((photoUrl.isEmpty || photoUrl == 'null') && googleApiKey.isNotEmpty && placeId != null) {
          try {
            final url = Uri.parse(
              'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=photos&key=$googleApiKey',
            );
            final response = await http.get(url);
            if (response.statusCode == 200) {
              final resultData = json.decode(response.body);
              if (resultData['status'] == 'OK' && resultData['result'] != null) {
                final result = resultData['result'];
                if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
                  final photoRef = result['photos'][0]['photo_reference'];
                  photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$googleApiKey';
                }
              }
            }
          } catch (e) {
            print('Google Places API fotoğraf çekim hatası: $e');
          }
        }

        if (photoUrl == 'null') photoUrl = '';

        final venue = {
          'id': doc.id,
          'name': data['name'] ?? 'Bilinmiyor',
          'lat': lat,
          'lng': lng,
          'city': data['city'] ?? 'Bilinmiyor',
          'photoUrl': photoUrl,
        };
        
        return venue;
      }).toList());

      venues.shuffle();
      dailyVenues.value = venues.take(5).toList();
    } catch (e) {
      print('Günün sahaları yüklenirken hata: $e');
    } finally {
      isVenuesLoading.value = false;
    }
  }

  void fetchMatches() {
    // SİHİR BURADA: Firebase'deki değişiklikleri canlı olarak listemize bağlıyoruz!
    // Artık biri maç eklediğinde sayfayı yenilemeye bile gerek kalmadan ekrana düşecek.
    upcomingMatches.bindStream(_matchService.getMatches());

    // Veri Firebase'den ulaştığı anda loading durumunu kapatıyoruz
    upcomingMatches.listen((_) {
      isLoading.value = false;
    });
  }

  void fetchNextMatch() {
    isNextMatchLoading.value = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isNextMatchLoading.value = false;
      return;
    }

    FirebaseFirestore.instance
        .collection('matches')
        .where('currentPlayers', arrayContains: user.uid)
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date')
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final doc = snapshot.docs.first;
              nextMatch.value = MatchModel.fromMap(
                doc.id,
                doc.data(),
              );
            } else {
              nextMatch.value = null;
            }
            isNextMatchLoading.value = false;
          },
          onError: (e) {
            if (FirebaseAuth.instance.currentUser == null) return;
            print('Sıradaki maç çekilirken hata: $e');
            isNextMatchLoading.value = false;
          },
        );
  }

  // SIFIRDAN YAZILACAK: Dinamik Sosyal Akış Mantığı
  void fetchFriendActivities() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isActivitiesLoading.value = false;
      return;
    }

    final String myUid = user.uid;
    final db = FirebaseFirestore.instance;

    // 1. Önce Takip Edilenleri Çek (Following collection)
    db.collection('users').doc(myUid).collection('following').snapshots().listen((followingSnap) async {
      try {
        if (followingSnap.docs.isEmpty) {
          friendActivities.clear();
          isActivitiesLoading.value = false;
          return;
        }

        final List<String> followingUids = followingSnap.docs.map((d) => d.id).toList();

        // Firestore 'in' query limitations (max 10).
        // For robustness, break into chunks of 10 if necessary. 
        // For now, take up to 10 closest friends or chunk them.
        final List<String> targetUids = followingUids.take(10).toList();

        // 2. Takip edilenlerin son 7 gündeki maçlarını çek (limitliyoruz)
        final DateTime weekAgo = DateTime.now().subtract(Duration(days: _feedDaysLimit));
        final Timestamp weekAgoTS = Timestamp.fromDate(weekAgo);

        // Created Matches (Maç Kuranlar)
        final QuerySnapshot createdMatchesSnap = await db
            .collection('matches')
            .where('creatorId', whereIn: targetUids)
            .where('createdAt', isGreaterThanOrEqualTo: weekAgoTS)
            .get();

        // Joined Matches (Maça Katılanlar - arrayContainsAny requires a list of up to 10)
        final QuerySnapshot joinedMatchesSnap = await db
            .collection('matches')
            .where('currentPlayers', arrayContainsAny: targetUids)
            // Note: Cannot mix arrayContainsAny with inequality filter on field not in order by natively sometimes without composite index, handling dynamically if needed, but normally OK if small dataset.
            // We will filter by date in memory to be safe against complex composite index errors right now.
            .get();

        final List<ActivityModel> activities = [];
        final Map<String, Map<String, String>> userCache = {}; // UID -> {name, avatar}

        // Helper to get user profile 
        Future<Map<String, String>> getUserProfile(String uid) async {
          if (userCache.containsKey(uid)) return userCache[uid]!;
          try {
            final doc = await db.collection('users').doc(uid).get();
            final data = doc.data();
            final name = data?['fullName'] ?? data?['name'] ?? 'Biri';
            final avatar = data?['profileImageUrl'] ?? 'https://picsum.photos/seed/$uid/100/100';
            userCache[uid] = {'name': name, 'avatar': avatar};
            return userCache[uid]!;
          } catch (_) {
            return {'name': 'Biri', 'avatar': 'https://picsum.photos/seed/$uid/100/100'};
          }
        }

        // Process Created Matches
        for (var doc in createdMatchesSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final creatorId = data['creatorId'] as String?;
          final createdAt = data['createdAt'] as Timestamp?;
          final matchId = doc.id;
          final venue = data['venue'] ?? 'Bir sahada';

          if (creatorId != null && followingUids.contains(creatorId) && createdAt != null) {
            final profile = await getUserProfile(creatorId);
            activities.add(ActivityModel(
              userId: creatorId,
              userName: profile['name']!,
              userAvatar: profile['avatar']!,
              action: 'bir maç oluşturdu. ($venue)',
              time: _timeAgoStr(createdAt.toDate()),
              timestamp: createdAt,
              matchId: matchId,
              isCreated: true,
            ));
          }
        }

        // Process Joined Matches
        for (var doc in joinedMatchesSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final players = List<String>.from(data['currentPlayers'] ?? []);
          final matchId = doc.id;
          final matchTitle = data['title'] ?? 'bir maç';
          // We don't have exact joinedAt timestamp usually, so use match createdAt 
          final matchCreatedAt = data['createdAt'] as Timestamp? ?? Timestamp.now();

          // Sadece son 7 bindeki ise devam et
          if (matchCreatedAt.toDate().isBefore(weekAgo)) continue;

          for (String playerUid in players) {
            // Eğer player = takipten biri ise VE maçın kurucusu değilse (kurucuysa "maç oluşturdu" deriz yukarıda)
            if (followingUids.contains(playerUid) && playerUid != data['creatorId']) {
              final profile = await getUserProfile(playerUid);
              activities.add(ActivityModel(
                userId: playerUid,
                userName: profile['name']!,
                userAvatar: profile['avatar']!,
                action: '"$matchTitle" maçına katıldı.',
                time: _timeAgoStr(matchCreatedAt.toDate()), // YAKLAŞIK ZAMAN
                timestamp: matchCreatedAt,
                matchId: matchId,
                isCreated: false,
              ));
            }
          }
        }

        // Zamana göre yeniden eskiye (descending) sırala
        activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Sadece en güncel 10 aktiviteyi göster
        friendActivities.value = activities.take(10).toList();
      } catch (e) {
        print("Aktiviteler çekilirken hata: $e");
      } finally {
        isActivitiesLoading.value = false;
      }
    });
  }

  String _timeAgoStr(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dakika önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else {
      return '${diff.inDays} gün önce';
    }
  }
}
