import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔥 void yerine String döndürüyoruz 🔥
  Future<String> createMatch(MatchModel match) async {
    // Veriyi ekliyoruz ve oluşan referansı (docRef) tutuyoruz
    DocumentReference docRef = await _firestore
        .collection('matches')
        .add(match.toMap());

    // Oluşan o eşsiz ID'yi controller'a geri gönderiyoruz
    return docRef.id;
  }

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
}
