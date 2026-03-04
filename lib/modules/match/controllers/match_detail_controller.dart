import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchDetailController extends GetxController {
  // Yükleme animasyonu için
  final RxBool isLoading = true.obs;

  // Firebase'den gelecek maç verisi (Map formatında)
  final Rxn<Map<String, dynamic>> matchData = Rxn<Map<String, dynamic>>();

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
              matchData.value = snapshot.data();
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
