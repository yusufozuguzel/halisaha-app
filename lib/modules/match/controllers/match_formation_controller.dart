import 'dart:async';
import '../../../core/services/match_participation.dart';
import '../../../core/utils/share_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../../routes/app_routes.dart';

class MatchFormationController extends GetxController {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSubscription;
  int _snapshotVersion = 0;
  Map<String, String>? _pendingBase;
  bool _formationEdited = false;
  final isSaving = false.obs;
  final String matchId;
  MatchFormationController({required this.matchId});

  final RxBool isLoading = true.obs;
  final Rxn<Map<String, dynamic>> matchData = Rxn<Map<String, dynamic>>();
  
  // Format seçimi
  final RxString selectedFormation = '2-3-1'.obs;
  // Firestore'daki 'positions' map'i. Key: Pozisyon id/index, Value: uid
  final RxMap<String, String> positions = <String, String>{}.obs; 
  // O maça ait oyuncuların detayları. uid -> {name, photoUrl vs}
  final RxMap<String, Map<String, dynamic>> playerDetails = <String, Map<String, dynamic>>{}.obs;
  // Davet edilen ve bekleyen oyuncuların map'i
  final RxMap<String, dynamic> pendingInvites = <String, dynamic>{}.obs;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Geçerli formatlar parametrik dolacak
  final RxList<String> availableFormations = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _listenToMatch();
  }

  @override
  void onClose() {
    _matchSubscription?.cancel();
    super.onClose();
  }

  void _listenToMatch() {
    _matchSubscription = _firestore.collection('matches').doc(matchId).snapshots().listen((snapshot) async {
      final version = ++_snapshotVersion;
      final data = snapshot.data();
      if (data == null) {
        matchData.value = null;
        positions.clear();
        pendingInvites.clear();
        isLoading.value = false;
        return;
      }
      matchData.value = data;
      _calculateAvailableFormations(data['maxPlayers'] ?? 14);
      if (!_formationEdited && data['formation'] is String) selectedFormation.value = data['formation'];
      positions.assignAll(MatchParticipation.slots(data, 'positions'));
      final pending = MatchParticipation.slots(data, 'pendingPositions');
      await _fetchPlayerDetails([...MatchParticipation.players(data), ...pending.values]);
      if (isClosed || version != _snapshotVersion) return;
      if (_pendingBase == null) {
        pendingInvites.assignAll({
          for (final e in pending.entries)
            e.key: {...?playerDetails[e.value], 'uid': e.value},
        });
      }
      isLoading.value = false;
    }, onError: (_) {
      if (isClosed) return;
      isLoading.value = false;
      Get.snackbar('Hata', 'Güncel kadro yüklenemedi.');
    });
  }

  void _calculateAvailableFormations(int maxPlayers) {
    int teamSize = maxPlayers ~/ 2;
    availableFormations.clear();

    if (teamSize == 5) {
      availableFormations.addAll(['1-2-1', '2-1-1', '1-1-2']);
      if (!availableFormations.contains(selectedFormation.value)) selectedFormation.value = '1-2-1';
    } else if (teamSize == 6) {
      availableFormations.addAll(['2-2-1', '1-3-1', '2-1-2']);
      if (!availableFormations.contains(selectedFormation.value)) selectedFormation.value = '2-2-1';
    } else if (teamSize == 7) {
      availableFormations.addAll(['2-3-1', '3-2-1', '2-2-2']);
      if (!availableFormations.contains(selectedFormation.value)) selectedFormation.value = '2-3-1';
    } else if (teamSize == 8) {
      availableFormations.addAll(['3-3-1', '2-4-1', '3-2-2']);
      if (!availableFormations.contains(selectedFormation.value)) selectedFormation.value = '3-3-1';
    } else if (teamSize == 9) {
       availableFormations.addAll(['3-4-1', '4-3-1', '3-3-2']);
       if (!availableFormations.contains(selectedFormation.value)) selectedFormation.value = '3-4-1';
    } else if (teamSize == 10) {
       availableFormations.addAll(['4-4-1', '3-5-1', '4-3-2']);
       if (!availableFormations.contains(selectedFormation.value)) selectedFormation.value = '4-4-1';
    } else if (teamSize == 11) {
       availableFormations.addAll(['4-4-2', '4-3-3', '3-5-2']);
       if (!availableFormations.contains(selectedFormation.value)) selectedFormation.value = '4-4-2';
    } else {
       availableFormations.addAll(['2-3-1', '3-2-1', '2-2-2']);
       if (!availableFormations.contains(selectedFormation.value)) selectedFormation.value = '2-3-1';
    }
  }

  Future<void> _fetchPlayerDetails(List<dynamic> uids) async {
    for (var uid in uids) {
      if (!playerDetails.containsKey(uid.toString())) {
        try {
          final userDoc = await _firestore.collection('users').doc(uid.toString()).get();
          if (userDoc.exists) {
            playerDetails[uid.toString()] = userDoc.data()!;
          } else {
             playerDetails[uid.toString()] = {
               'name': 'Görüntülenemiyor',
               'profileImageUrl': null
             };
          }
        } catch (e) {
          print("Oyuncu çekilirken hata: $e");
        }
      }
    }
  }

  void changeFormation(String form) {
    if (!isCaptain || isSaving.value) return;
    _formationEdited = true;
    selectedFormation.value = form;
  }

  Future<void> moveToPosition(String key) async {
    if (isSaving.value) return;
    try {
      await MatchParticipation().move(matchId, key);
    } catch (e) {
      Get.snackbar('İşlem tamamlanamadı', e is MatchActionException ? e.message : 'Pozisyon kaydedilemedi.');
    }
  }

  Future<void> saveFormation() async {
    if (isSaving.value) return;
    isSaving.value = true;
    try {
      final desired = <String, String>{
        for (final e in pendingInvites.entries) e.key: e.value['uid'] as String,
      };
      final base = _pendingBase ?? MatchParticipation.slots(matchData.value ?? {}, 'pendingPositions');
      await MatchParticipation().saveFormation(matchId, selectedFormation.value, base, desired);
      _pendingBase = null;
      _formationEdited = false;
      if (!isClosed) {
        Get.snackbar('Başarılı', 'Diziliş ve davetler kaydedildi.');
        Get.offAllNamed(Routes.HOME);
      }
    } catch (e) {
      if (!isClosed) {
        Get.snackbar('Kayıt tamamlanamadı',
          '${e is MatchActionException ? e.message : 'Lütfen tekrar deneyin.'} Bazı davetler kaydedilmiş olabilir; tekrar denemek bunları çoğaltmaz.');
      }
    } finally {
      if (!isClosed) isSaving.value = false;
    }
  }

  Future<void> kickPlayerFromFormation(String targetUid, String positionKey) async {
    try {
      await MatchParticipation().kick(matchId, targetUid);
      Get.snackbar('Başarılı', 'Oyuncu maçtan çıkarıldı.');
    } catch (e) {
      Get.snackbar('İşlem tamamlanamadı', e is MatchActionException ? e.message : 'Oyuncu çıkarılamadı.');
    }
  }

  bool get isCaptain {
      return matchData.value?['createdBy'] == currentUserId;
  }

  Future<void> showFriendsBottomSheet(String positionId) async {
    final currentUid = currentUserId;
    if (currentUid.isEmpty) return;
    
    Get.bottomSheet(
      Container(
        height: Get.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF16221A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            const Text('Arkadaşlarını Davet Et', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // "Bu Mevkiye Ben Geçeceğim" Butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Get.back();
                  moveToPosition(positionId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2EED7B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2EED7B).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2EED7B).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF2EED7B), size: 20),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Bu Mevkiye Ben Geçeceğim',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').doc(currentUid).collection('friends').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF2EED7B)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Davet edilecek arkadaş bulunamadı.', style: TextStyle(color: Colors.white54)));
                  }
                  
                  final friendsList = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: friendsList.length,
                    itemBuilder: (context, index) {
                      final friendUid = friendsList[index].id;
                      
                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('users').doc(friendUid).get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return const SizedBox.shrink();
                          
                          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                          final name = userData['fullName'] ?? userData['name'] ?? 'İsimsiz Oyuncu';
                          final photoUrl = userData['avatarUrl'] ?? userData['profileImageUrl'] ?? userData['photoUrl'];
                          
                          ImageProvider? imageProvider;
                          if (photoUrl != null && photoUrl.toString().trim().isNotEmpty) {
                            imageProvider = NetworkImage(photoUrl.toString().trim());
                          }
                          
                          return Obx(() {
                              final List<dynamic> currentPlayers = matchData.value?['currentPlayers'] ?? [];
                              final List<dynamic> invitedPlayers = matchData.value?['invitedPlayers'] ?? [];
                              
                              final bool isAlreadyInMatch = currentPlayers.contains(friendUid);
                              final bool isAlreadyPendingLocal = pendingInvites.values.any((p) => p['uid'] == friendUid);
                              final bool isAlreadyInvited = invitedPlayers.contains(friendUid) || isAlreadyPendingLocal;

                              Widget trailingWidget;
                              if (isAlreadyInMatch || isAlreadyInvited) {
                                trailingWidget = Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isAlreadyInMatch ? 'Maçta' : (isAlreadyPendingLocal ? 'Eklendi' : 'Davet Edildi'),
                                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                );
                              } else {
                                trailingWidget = SizedBox(
                                  height: 36, // ListTile içi buton formunu uyumlu yapmak için
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2EED7B),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      sendInvite(friendUid, positionId, userData);
                                    },
                                    child: const Text('Davet Et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.white12,
                                      backgroundImage: imageProvider,
                                      child: imageProvider == null ? const Icon(Icons.person, color: Colors.white54) : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    trailingWidget,
                                  ],
                                ),
                              );
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void cancelLocalInvite(String positionId) {
    if (!isCaptain || isSaving.value) return;
    _pendingBase ??= MatchParticipation.slots(matchData.value ?? {}, 'pendingPositions');
    if (pendingInvites.containsKey(positionId)) {
      pendingInvites.remove(positionId);
    }
  }

  void sendInvite(String friendUid, String positionId, Map<String, dynamic> friendData) {
    if (!isCaptain || isSaving.value) return;
    _pendingBase ??= MatchParticipation.slots(matchData.value ?? {}, 'pendingPositions');
    final currentUid = currentUserId;
    if (currentUid.isEmpty) return;

    final Map<String, dynamic> dataToSave = Map<String, dynamic>.from(friendData);
    dataToSave['uid'] = friendUid;
    pendingInvites[positionId] = dataToSave;
    
    Get.back();
  }

  Future<void> shareMatch() async {
    final mData = matchData.value;
    if (mData == null) return;

    final String title = mData['title'] ?? 'Maç';
    final String venueName = mData['venue'] ?? 'Saha Belirtilmemiş';
    
    String formattedDate = '';
    String timeStr = '';

    if (mData['date'] is Timestamp) {
      final dt = (mData['date'] as Timestamp).toDate();
      formattedDate = "${dt.day}/${dt.month}/${dt.year}";
      timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      
      if (mData['endDate'] is Timestamp) {
         final edt = (mData['endDate'] as Timestamp).toDate();
         timeStr += " - ${edt.hour.toString().padLeft(2, '0')}:${edt.minute.toString().padLeft(2, '0')}";
      }
    }

    await Share.share(
      matchInvitationText(
        title: title,
        date: '$formattedDate $timeStr',
        venue: venueName,
      ),
      subject: 'Halı Saha Maç Daveti',
    );
  }
}
