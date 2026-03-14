import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        // İlk atamaları arkadan firestore'a yollayabiliriz.
        _firestore.collection('matches').doc(matchId).update({
            'positions': updatedPositions
        });
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

      updatedPositions.removeWhere((key, value) => value == uid);
      updatedPositions[newPositionKey] = uid;
      
      // Önce lokalde güncelle ki kullanıcı hemen görsün
      positions.value = updatedPositions;

      // Sonra Firestore'a yaz (Anında Senkronizasyon)
      try {
          await _firestore.collection('matches').doc(matchId).update({
              'positions': updatedPositions
          });
      } catch (e) {
          print("Pozisyon güncellenirken hata: $e");
          Get.snackbar('Hata', 'Konum değişikliği kaydedilemedi', snackPosition: SnackPosition.BOTTOM);
      }
  }

  Future<void> saveFormation() async {
      try {
          await _firestore.collection('matches').doc(matchId).update({
              'formation': selectedFormation.value,
              'positions': positions
          });
          Get.snackbar(
            'Başarılı', 
            'Diziliş ve saha yerleşimi güncellendi', 
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
              'positions.$positionKey': FieldValue.delete()
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
}
