import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String action;
  final String time;
  final Timestamp timestamp;
  final String? matchId;
  final bool isCreated;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.action,
    required this.time,
    required this.timestamp,
    this.matchId,
    required this.isCreated,
  });
}
