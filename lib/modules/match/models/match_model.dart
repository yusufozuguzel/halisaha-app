import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String id;
  final String title;
  final DateTime date;
  final int maxPlayers;

  MatchModel({
    required this.id,
    required this.title,
    required this.date,
    required this.maxPlayers,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'maxPlayers': maxPlayers,
    };
  }

  factory MatchModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchModel(
      id: id,
      title: map['title'],
      date: (map['date'] as Timestamp).toDate(),
      maxPlayers: map['maxPlayers'],
    );
  }
}
