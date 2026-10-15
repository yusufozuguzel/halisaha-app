import '../../../core/services/write_policy.dart';
import '../../../core/services/match_participation.dart';
import '../../../core/services/match_metadata.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/match_model.dart';

class MatchService {
  // İşte Flutter'ın bulamadığı o sihirli satır burası! 👇
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Maç Oluşturma
  Future<String> createMatch(MatchModel match) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Maç oluşturmak için giriş yapın.');
    final data = <String, dynamic>{
      ...match.toMap(),
      'createdBy': uid,
      'creatorId': uid,
      'currentPlayers': [uid],
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    };
    final issue = MatchMetadata.error(data);
    if (issue != null) throw MatchActionException(issue);
    if (!match.date.isAfter(DateTime.now())) {
      throw const MatchActionException('Geçmiş tarihe maç kurulamaz.');
    }
    final limited = await WritePolicy().prepare(uid);
    final docRef = _firestore.collection('matches').doc();
    final batch = _firestore.batch()..set(docRef, data);
    if (limited)
      batch.set(
        _firestore.doc(writeLimitPath(uid, 'matchCreate')),
        writeLimitData(docRef.id),
      );
    await batch.commit();
    return docRef.id;
  }

  // Maçları Dinleme (Canlı Akış)
  Stream<List<MatchModel>> getMatches() {
    return _firestore
        .collection('matches')
        .where('date', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('date')
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // 🔥 YENİ: Maçtan Ayrılma Fonksiyonu 🔥
  Future<void> leaveMatch(String matchId) =>
      MatchParticipation().leave(matchId);
}
