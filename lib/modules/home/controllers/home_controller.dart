import 'package:get/get.dart';
import '../../match/models/match_model.dart';
import '../../match/services/match_service.dart';

class HomeController extends GetxController {
  // Backend servisimizi çağırıyoruz
  final MatchService _matchService = MatchService();

  // Firebase'den gelecek maçları tutacağımız reaktif (canlı) liste
  final RxList<MatchModel> upcomingMatches = <MatchModel>[].obs;

  // Veriler yüklenirken ekranda dönen top/loading efekti için
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Ana sayfa açılır açılmaz maçları çekmeye başla!
    fetchMatches();
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
}
