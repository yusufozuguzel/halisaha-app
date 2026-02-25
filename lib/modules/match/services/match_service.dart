import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createMatch(MatchModel match) async {
    await _firestore.collection('matches').add(match.toMap());
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
