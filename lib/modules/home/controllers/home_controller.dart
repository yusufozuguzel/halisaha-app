import 'package:get/get.dart';
import 'dart:async';
import '../../friends/controllers/block_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../match/models/match_model.dart';
import '../../match/services/match_service.dart';
import '../models/activity_model.dart';

class HomeController extends GetxController {
  // Backend servisimizi çağırıyoruz
  final MatchService _matchService = MatchService();

  // Firebase'den gelecek maçları tutacağımız reaktif (canlı) liste
  final RxList<MatchModel> _allMatches = <MatchModel>[].obs;
  final BlockController _blocks = BlockController.shared;
  final List<StreamSubscription> _subscriptions = [];
  int _feedRevision = 0;
  List<MatchModel> get upcomingMatches => _allMatches.where((m) => _blocks.visible(m.ownerId)).toList();

  // Veriler yüklenirken ekranda dönen top/loading efekti için
  final RxBool isLoading = true.obs;

  // Kullanıcının sıradaki (yaklaşan en yakın) maçı
  final Rx<MatchModel?> nextMatch = Rx<MatchModel?>(null);
  final RxBool isNextMatchLoading = true.obs;

  // --- Günün Sahaları ---
  final RxList<Map<String, dynamic>> dailyVenues = <Map<String, dynamic>>[].obs;
  final RxBool isVenuesLoading = true.obs;

  // --- Arkadaşların Neler Yapıyor? (Social Feed) ---
  final RxList<ActivityModel> _allActivities = <ActivityModel>[].obs;
  final RxSet<String> _hiddenActivities = <String>{}.obs;
  List<ActivityModel> get friendActivities => _allActivities.where((a) =>
      !_hiddenActivities.contains(a.id) && _blocks.visible(a.userId) &&
      _blocks.visible(a.matchOwnerId)).take(10).toList();
  final RxBool isActivitiesLoading = true.obs;
  final int _feedDaysLimit = 7; // Son 7 günün aktiviteleri

  @override
  void onClose() {
    _stopActivityStreams();
    for (final subscription in _subscriptions) { subscription.cancel(); }
    super.onClose();
  }

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
    _subscriptions.add(_matchService.getMatches().listen((matches) {
      if (isClosed) return;
      _allMatches.assignAll(matches);
      isLoading.value = false;
    }, onError: (_) { if (!isClosed) isLoading.value = false; }));
  }

  void fetchNextMatch() {
    isNextMatchLoading.value = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isNextMatchLoading.value = false;
      return;
    }

    _subscriptions.add(FirebaseFirestore.instance
        .collection('matches')
        .where('currentPlayers', arrayContains: user.uid)
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date')
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) {
            if (isClosed) return;
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
        ));
  }

  // Match and profile streams keep removed/redacted content out of cached feeds.
  final List<StreamSubscription> _activitySubscriptions = [];

  void _stopActivityStreams() {
    ++_feedRevision;
    for (final subscription in _activitySubscriptions) { subscription.cancel(); }
    _activitySubscriptions.clear();
    _allActivities.clear();
  }

  void fetchFriendActivities() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { isActivitiesLoading.value = false; return; }
    final db = FirebaseFirestore.instance;
    _subscriptions.add(db.collection('users').doc(uid).collection('friends').snapshots().listen((snapshot) {
      if (isClosed) return;
      _stopActivityStreams();
      final revision = _feedRevision;
      final ids = snapshot.docs.map((d) => d.id).take(10).toList();
      if (ids.isEmpty) { isActivitiesLoading.value = false; return; }
      final profiles = <String, Map<String, dynamic>>{};
      final games = <String, Map<String, dynamic>>{};
      final weekAgo = DateTime.now().subtract(Duration(days: _feedDaysLimit));
      void publish() {
        if (isClosed || revision != _feedRevision) return;
        final activities = <ActivityModel>[];
        for (final entry in games.entries) {
          final data = entry.value;
          final created = data['createdAt'];
          if (created is! Timestamp || created.toDate().isBefore(weekAgo)) continue;
          final owner = (data['createdBy'] ?? data['creatorId']) as String?;
          final players = (data['currentPlayers'] as List? ?? []).whereType<String>().toSet();
          if (owner != null) players.add(owner);
          for (final player in players.where(ids.contains)) {
            final profile = profiles[player];
            if (profile == null) continue;
            final isCreator = player == owner;
            activities.add(ActivityModel(id: '${player}_${entry.key}', userId: player,
              userName: profile['fullName'] ?? profile['name'] ?? 'Kullanıcı',
              userAvatar: profile['avatarUrl'] ?? '',
              action: isCreator ? "bir maç oluşturdu. (${data['venue'] ?? 'Bir sahada'})"
                : '"${data['title'] ?? 'bir maç'}" maçına katıldı.',
              time: _timeAgoStr(created.toDate()), timestamp: created,
              matchId: entry.key, matchOwnerId: owner, isCreated: isCreator));
          }
        }
        activities.sort((a,b) => b.timestamp.compareTo(a.timestamp));
        _allActivities.assignAll(activities);
        isActivitiesLoading.value = false;
      }
      for (final player in ids) {
        _activitySubscriptions.add(db.doc('users/$player').snapshots().listen((profile) {
          if (isClosed || revision != _feedRevision) return;
          if (profile.exists) { profiles[player] = profile.data()!; }
          else { profiles.remove(player); }
          publish();
        }, onError: (_) {
          if (isClosed || revision != _feedRevision) return;
          profiles.remove(player); publish();
        }));
      }
      // Supported rosters always contain the creator; one stream avoids stale
      // duplicates when two separate queries deliver a deletion at different times.
      _activitySubscriptions.add(db.collection('matches')
        .where('currentPlayers', arrayContainsAny: ids).snapshots().listen((matches) {
          if (isClosed || revision != _feedRevision) return;
          games.clear();
          for (final doc in matches.docs) { games[doc.id] = doc.data(); }
          publish();
        }, onError: (_) {
          if (isClosed || revision != _feedRevision) return;
          games.clear(); publish();
        }));
    }, onError: (_) {
      if (isClosed) return;
      _stopActivityStreams();
      isActivitiesLoading.value = false;
    }));
  }

  void hideActivity(String activityId) {
    final index = friendActivities.indexWhere((a) => a.id == activityId);
    if (index == -1) return;

    final activity = friendActivities[index];
    _hiddenActivities.add(activityId);

    Get.snackbar(
      'Aktivite gizlendi.',
      '',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.grey.shade800,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      mainButton: TextButton(
        onPressed: () {
          if (isClosed) return;
          _hiddenActivities.remove(activity.id);
          Get.back(); // Snackbar'ı kapat
        },
        child: const Text(
          'Geri Al',
          style: TextStyle(
            color: Color(0xFF2EED7B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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
