import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MatchDetailController extends GetxController {
  // Yükleme animasyonu için
  final RxBool isLoading = true.obs;

  // Firebase'den gelecek maç verisi (Map formatında)
  final Rxn<Map<String, dynamic>> matchData = Rxn<Map<String, dynamic>>();

  // Katılımcıların detaylarını tutan harita (UID -> Kullanıcı Bilgileri)
  final RxMap<String, Map<String, dynamic>> participantDetails = <String, Map<String, dynamic>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    // 1. Listeden "Get.to(..., arguments: match.id)" ile yolladığımız o ID'yi burada yakalıyoruz!
    final String? matchId = Get.arguments as String?;

    if (matchId != null) {
      _fetchMatchDetails(matchId);
    } else {
      isLoading.value = false;
      Get.snackbar(
        "Hata",
        "Maç ID'si bulunamadı!",
        backgroundColor: Get.theme.colorScheme.error,
      );
    }
  }

  // 2. Firebase'den o maça ait HER ŞEYİ canlı olarak dinliyoruz
  void _fetchMatchDetails(String matchId) {
    FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .snapshots() // snapshots() sayesinde sayfadayken biri katılırsa anında güncellenir!
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data()!;
              matchData.value = data;
              // Katılımcıların profil verilerini çek
              final currentPlayers = data['currentPlayers'] as List<dynamic>? ?? [];
              _fetchParticipantDetails(currentPlayers);
            } else {
              matchData.value = null;
            }
            isLoading.value = false;
          },
          onError: (error) {
            print("Maç detayı çekilirken hata: $error");
            isLoading.value = false;
          },
        );
  }

  // Katılımcıların detaylarını çeker
  Future<void> _fetchParticipantDetails(List<dynamic> uids) async {
    for (var uid in uids) {
      if (!participantDetails.containsKey(uid.toString())) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid.toString()).get();
          if (userDoc.exists) {
            participantDetails[uid.toString()] = userDoc.data()!;
          } else {
            participantDetails[uid.toString()] = {
              'name': 'Görüntülenemiyor',
            };
          }
        } catch (e) {
          print("Katılımcı detayı çekilirken hata: $e");
        }
      }
    }
  }

  // Kurucunun bir oyuncuyu maçtan atması
  Future<void> kickPlayer(String targetUid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final currentMatchId = Get.arguments as String?;
      if (currentMatchId == null) return;

      final docRef = FirebaseFirestore.instance.collection('matches').doc(currentMatchId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data()!;
      // Sadece kurucu kick atabilir
      if (data['createdBy'] != user.uid) {
        Get.snackbar("Yetkisiz İşlem", "Sadece maçı kuran kişi oyuncu çıkarabilir.", backgroundColor: Get.theme.colorScheme.error);
        return;
      }

      final Map<String, dynamic> updates = {
         'currentPlayers': FieldValue.arrayRemove([targetUid]),
         'invitedPlayers': FieldValue.arrayRemove([targetUid]),
      };

      if (data.containsKey('positions')) {
          final Map<String, dynamic> posData = data['positions'] as Map<String, dynamic>;
          String? userSlot;
          for (var entry in posData.entries) {
              if (entry.value == targetUid) {
                  userSlot = entry.key;
                  break;
              }
          }
          if (userSlot != null) {
              updates['positions.$userSlot'] = FieldValue.delete();
          }
      }

      if (data.containsKey('pendingPositions')) {
          final Map<String, dynamic> pendingData = data['pendingPositions'] as Map<String, dynamic>;
          String? pendingSlot;
          for (var entry in pendingData.entries) {
              if (entry.value == targetUid) {
                  pendingSlot = entry.key;
                  break;
              }
          }
          if (pendingSlot != null) {
              updates['pendingPositions.$pendingSlot'] = FieldValue.delete();
          }
      }

      await docRef.update(updates);
      Get.snackbar("Başarılı", "Oyuncu maçtan çıkarıldı.", backgroundColor: const Color(0xFF1E2A22), colorText: const Color(0xFF2EED7B));
    } catch (e) {
      print("Oyuncu atılırken hata: $e");
      Get.snackbar("Hata", "İşlem sırasında bir sorun oluştu: $e", backgroundColor: Get.theme.colorScheme.error);
    }
  }

  // 3. View'da (Arayüzde) kullandığın o "formatDate" fonksiyonu
  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Tarih Belirtilmedi";
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$day/$month/$year - Saat: $hour:$minute";
  }
}
