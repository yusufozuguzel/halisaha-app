import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class MatchService {
  // İşte Flutter'ın bulamadığı o sihirli satır burası! 👇
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Maç Oluşturma
  Future<String> createMatch(MatchModel match) async {
    DocumentReference docRef = await _firestore
        .collection('matches')
        .add(match.toMap());
    return docRef.id;
  }

  // Maçları Dinleme (Canlı Akış)
  Stream<List<MatchModel>> getMatches() {
    return _firestore
        .collection('matches')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // 🔥 YENİ: Maçtan Ayrılma Fonksiyonu 🔥
  Future<void> leaveMatch(String matchId) async {
    try {
      // Gerçek Auth entegre olana kadar şimdilik geçici ID kullanıyoruz.
      final String currentUserId = 'temp_user_id';

      // Firebase'de o maçın 'currentPlayers' listesinden bu kullanıcıyı sil
      await _firestore.collection('matches').doc(matchId).update({
        'currentPlayers': FieldValue.arrayRemove([currentUserId]),
      });
    } catch (e) {
      print("Maçtan ayrılırken hata: $e");
      rethrow;
    }
  }
}
