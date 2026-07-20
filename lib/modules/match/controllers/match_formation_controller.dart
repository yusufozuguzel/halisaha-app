import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../../routes/app_routes.dart';

class MatchFormationController extends GetxController {
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

  void _listenToMatch() {
    _firestore.collection('matches').doc(matchId).snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        matchData.value = data;

        // Formasyonları kapasiteye göre hesapla
        int maxP = data['maxPlayers'] ?? 14;
        _calculateAvailableFormations(maxP);

        // İlk girişte formasyonu ve pozisyonları DB'den al
        if (isLoading.value) {
            if (data.containsKey('formation') && availableFormations.contains(data['formation'])) {
                selectedFormation.value = data['formation'];
            }
            if (data.containsKey('positions')) {
              final Map<String, dynamic> posData = data['positions'] as Map<String, dynamic>;
              positions.clear();
              posData.forEach((key, value) {
                positions[key] = value.toString();
              });
            }
        } else {
            // Şimdilik DB'den okumaya devam edelim, kendi hareketimiz Save ile gidecek.
            if (data.containsKey('positions')) {
              // Sadece bizim olmayan değişiklikleri yansıtabiliriz ama şu anlık basit tutuyoruz
            }
        }

        // currentPlayers listesindeki kullanıcıları çek
        final List<dynamic> currentPlayers = data['currentPlayers'] ?? [];
        await _fetchPlayerDetails(currentPlayers);
        
        // pendingPositions'daki kullanıcıları çek ve pendingInvites map'ini doldur
        if (data.containsKey('pendingPositions')) {
           final Map<String, dynamic> pendingPosData = data['pendingPositions'] as Map<String, dynamic>;
           List<dynamic> pendingUids = pendingPosData.values.toList();
           await _fetchPlayerDetails(pendingUids);
           
           Map<String, dynamic> newPendingInvites = {};
           pendingPosData.forEach((posKey, uidStr) {
              final uid = uidStr.toString();
              if (playerDetails.containsKey(uid)) {
                 final pData = Map<String, dynamic>.from(playerDetails[uid]!);
                 pData['uid'] = uid;
                 newPendingInvites[posKey] = pData;
              }
           });
           pendingInvites.value = newPendingInvites;
        }
        
        // Eğer giren oyuncu henüz bir pozisyonda değilse boş bir yere (veya kaptansa özel yere) ata
        // Bunu da sadece ilk seferde yapıyoruz, aksi halde sürekli update loop'a girebilir.
        if (isLoading.value) {
           _assignPlayersIfNeeded(currentPlayers, data['createdBy']);
        }
      }
      isLoading.value = false;
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

  void _assignPlayersIfNeeded(List<dynamic> currentPlayers, String? captainUid) {
    if (currentPlayers.isEmpty) return;

    bool madeChanges = false;
    Map<String, String> updatedPositions = Map.from(positions);
    Set<String> playersInPositions = updatedPositions.values.toSet();

    for (var pUid in currentPlayers) {
        String uid = pUid.toString();
        if (!playersInPositions.contains(uid)) {
            String? slot;
            if (uid == captainUid) {
               // Kaptanı kaleci yerine daha merkez bir pozisyona (örn. formasyonun ortasına) veya ilk boş forvete atamaya çalışalım.
               // Şimdilik en büyük index (ilerideki) boş slotu veya ortalardaki boş slotu bulalım.
               slot = _findCentralEmptySlot(updatedPositions);
            } else {
               slot = _findEmptySlot(updatedPositions);
            }
            
            if (slot != null) {
                updatedPositions[slot] = uid;
                madeChanges = true;
                playersInPositions.add(uid);
            }
        }
    }

    if (madeChanges) {
        positions.value = updatedPositions;
        // Sadece değişen slotları dot-notation ile güncelle (güvenlik kurallarına takılmaz)
        final Map<String, dynamic> dotUpdates = {};
        updatedPositions.forEach((slot, uid) {
          dotUpdates['positions.$slot'] = uid;
        });
        if (dotUpdates.isNotEmpty) {
          _firestore.collection('matches').doc(matchId).update(dotUpdates);
        }
    }
  }

  String? _findEmptySlot(Map<String, String> currentPositions) {
      int maxPlayersPerTeam = (matchData.value?['maxPlayers'] ?? 14) ~/ 2; 
      for (int i = 0; i < maxPlayersPerTeam; i++) {
          if (!currentPositions.containsKey(i.toString())) {
             return i.toString();
          }
      }
      return null;
  }

  String? _findCentralEmptySlot(Map<String, String> currentPositions) {
      int maxPlayersPerTeam = (matchData.value?['maxPlayers'] ?? 14) ~/ 2; 
      // Kaptanı ortalara (örn maxPlayersPerTeam / 2 civarına) atamaya çalış
      int centerIndex = maxPlayersPerTeam ~/ 2; // Örn 7 için 3, 11 için 5
      
      // Merkezden başlayıp dışarı doğru boş yer ara
      if (!currentPositions.containsKey(centerIndex.toString())) {
          return centerIndex.toString();
      }
      
      // Merkez doluysa 1'den (GK hariç) başlayarak boş yer bul (Kaptan GK olmasın)
      for (int i = 1; i < maxPlayersPerTeam; i++) {
          if (!currentPositions.containsKey(i.toString())) {
             return i.toString();
          }
      }
      
      // Hiç yer yoksa mecbur 0'a (GK) bak
      if (!currentPositions.containsKey('0')) {
          return '0';
      }
      return null;
  }

  void changeFormation(String form) {
      selectedFormation.value = form;
      // Artık sadece lokalde güncelliyoruz, Kaydet'e basılınca DB'ye gidecek.
  }

  Future<void> moveToPosition(String newPositionKey) async {
      String uid = currentUserId;
      Map<String, String> updatedPositions = Map.from(positions);
      
      if (updatedPositions[newPositionKey] == uid) return;
      
      if (updatedPositions.containsKey(newPositionKey)) {
         Get.snackbar('Hata', 'Bu pozisyon dolu', snackPosition: SnackPosition.BOTTOM);
         return;
      }

      // Kullanıcının eski slotunu bul
      String? oldSlot;
      updatedPositions.forEach((key, value) {
        if (value == uid) oldSlot = key;
      });

      // Lokalde güncelle
      if (oldSlot != null) updatedPositions.remove(oldSlot);
      updatedPositions[newPositionKey] = uid;
      positions.value = updatedPositions;

      // Firestore: sadece değişen iki alanı dot-notation ile yaz
      // (Tüm map'i ezmek yerine sadece kendi slotlarını güncelle)
      try {
          final Map<String, dynamic> updates = {
            'positions.$newPositionKey': uid,
          };
          if (oldSlot != null) {
            updates['positions.$oldSlot'] = FieldValue.delete();
          }
          await _firestore.collection('matches').doc(matchId).update(updates);
      } catch (e) {
          print("Pozisyon güncellenirken hata: $e");
          Get.snackbar('Hata', 'Konum değişikliği kaydedilemedi: $e', snackPosition: SnackPosition.BOTTOM);
      }
  }

  Future<void> saveFormation() async {
      try {
          final batch = _firestore.batch();
          final matchRef = _firestore.collection('matches').doc(matchId);

          Map<String, String> pendingToSave = {};
          List<String> uidsToInvite = [];
          
          final Map<String, dynamic>? currentPendingPos = matchData.value?['pendingPositions'] as Map<String, dynamic>?;

          pendingInvites.forEach((key, value) {
             final uid = value['uid']?.toString();
             if (uid != null && uid.isNotEmpty) {
                 pendingToSave[key] = uid;
                 if (!uidsToInvite.contains(uid)) {
                     uidsToInvite.add(uid);
                 }
                 
                 // Sadece yeni eklenen davetler için bildirim fırlat
                 bool isNew = true;
                 if (currentPendingPos != null && currentPendingPos[key] == uid) {
                     isNew = false;
                 }
                 
                 if (isNew) {
                     final notifRef = _firestore.collection('notifications').doc();
                     batch.set(notifRef, {
                        'type': 'match_invite',
                        'senderId': currentUserId,
                        'receiverId': uid,
                        'matchId': matchId,
                        'positionId': key,
                        'status': 'pending',
                        'isRead': false,
                        'createdAt': FieldValue.serverTimestamp(),
                     });
                 }
             }
          });

          final Map<String, dynamic> updates = {
              'formation': selectedFormation.value,
              'positions': positions
          };
          
          if (pendingToSave.isNotEmpty) {
              updates['pendingPositions'] = pendingToSave;
              updates['invitedPlayers'] = FieldValue.arrayUnion(uidsToInvite);
          } else {
              updates['pendingPositions'] = FieldValue.delete();
          }

          batch.update(matchRef, updates);
          await batch.commit();

          Get.snackbar(
            'Başarılı', 
            'Diziliş ve davetler kaydedildi', 
            backgroundColor: const Color(0xFF1E2A22), 
            colorText: const Color(0xFF2EED7B),
            snackPosition: SnackPosition.BOTTOM
          );
          Get.offAllNamed(Routes.HOME); // Başarıyla kaydedilince ana sayfaya dön
      } catch (e) {
          Get.snackbar(
            'Hata', 
            'Kaydedilirken hata oluştu: $e', 
            backgroundColor: const Color(0xFF8B0000), 
            colorText: const Color(0xFFFFFFFF),
            snackPosition: SnackPosition.BOTTOM
          );
      }
  }

  Future<void> kickPlayerFromFormation(String targetUid, String positionKey) async {
      try {
          if (!isCaptain) return;
          
          final docRef = _firestore.collection('matches').doc(matchId);
          await docRef.update({
              'currentPlayers': FieldValue.arrayRemove([targetUid]),
              'invitedPlayers': FieldValue.arrayRemove([targetUid]),
              'positions.$positionKey': FieldValue.delete(),
              'pendingPositions.$positionKey': FieldValue.delete()
          });
          
          // Lokal durumu hemen güncelle
          Map<String, String> updatedPositions = Map.from(positions);
          updatedPositions.remove(positionKey);
          positions.value = updatedPositions;
          playerDetails.remove(targetUid);
          
          Get.snackbar(
            'Başarılı', 
            'Oyuncu maçtan ve saha dizilişinden çıkarıldı.', 
            backgroundColor: const Color(0xFF1E2A22), 
            colorText: const Color(0xFF2EED7B),
            snackPosition: SnackPosition.BOTTOM
          );
      } catch (e) {
          print("Oyuncu atılırken hata: $e");
          Get.snackbar(
            'Hata', 
            'Oyuncu çıkarılamadı: $e', 
            backgroundColor: Colors.red[900], 
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM
          );
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
    if (pendingInvites.containsKey(positionId)) {
      pendingInvites.remove(positionId);
    }
  }

  void sendInvite(String friendUid, String positionId, Map<String, dynamic> friendData) {
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

    final String deepLink = 'https://halisaha.app/join/$matchId';

    await Share.share(
      '⚽ Yeni bir maça davetlisin!\n\nMaç: $title\n📅 $formattedDate - ⏰ $timeStr\n📍 $venueName\n\nMaça katılmak için hemen tıkla:\n$deepLink',
      subject: 'Halı Saha Maç Daveti',
    );
  }
}
