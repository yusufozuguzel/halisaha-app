import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../match/models/match_model.dart';
import '../../match/services/match_service.dart';

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

  @override
  void onInit() {
    super.onInit();
    // Ana sayfa açılır açılmaz maçları çekmeye başla!
    fetchMatches();
    fetchNextMatch();
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
                doc.data() as Map<String, dynamic>,
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
}
