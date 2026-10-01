import '../../../core/services/match_participation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final id = Get.arguments as String?;
    if (id == null) return;
    try {
      await MatchParticipation().kick(id, targetUid);
      Get.snackbar('Başarılı', 'Oyuncu maçtan çıkarıldı.');
    } catch (e) {
      Get.snackbar('İşlem tamamlanamadı', e is MatchActionException ? e.message : 'Lütfen tekrar deneyin.');
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
