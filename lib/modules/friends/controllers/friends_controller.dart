import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../home/controllers/notifications_controller.dart';
import '../../home/controllers/profile_controller.dart';

// ── Data model ──────────────────────────────────────────────
class UserModel {
  final String uid;
  final String name;
  final String position;
  final String avatarType;
  final String avatarData;

  const UserModel({
    required this.uid,
    required this.name,
    required this.position,
    required this.avatarType,
    required this.avatarData,
  });

  factory UserModel.fromFirestore(String uid, Map<String, dynamic> d) {
    return UserModel(
      uid: uid,
      name: d['fullName'] ?? d['name'] ?? 'İsimsiz Oyuncu',
      position: d['position'] ?? '',
      avatarType: d['avatarType'] ?? 'icon',
      avatarData: d['avatarData'] ?? '0',
    );
  }
}

// ── Controller ───────────────────────────────────────────────
class FriendsController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? get _myUid => _auth.currentUser?.uid;

  // ── State ─────────────────────────────────────────────────
  final RxList<UserModel> following = <UserModel>[].obs;
  final RxList<UserModel> pendingRequests = <UserModel>[].obs;
  final RxList<UserModel> searchResults = <UserModel>[].obs;

  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxBool isLoading = true.obs;

  // ── Subscriptions ─────────────────────────────────────────
  final List<Function()> _subs = [];

  @override
  void onInit() {
    super.onInit();
    _subscribeFollowing();
    _subscribeRequests();

    // Debounce: arama 400ms sonra tetiklensin
    debounce(
      searchQuery,
      (_) => _runSearch(),
      time: const Duration(milliseconds: 400),
    );
  }

  @override
  void onClose() {
    for (final c in _subs) {
      c();
    }
    super.onClose();
  }

  // ── Following list ────────────────────────────────────────
  void _subscribeFollowing() {
    final myUid = _myUid;
    if (myUid == null) {
      isLoading.value = false;
      return;
    }

    final sub = _db
        .collection('users')
        .doc(myUid)
        .collection('following')
        .snapshots()
        .listen((snap) async {
          isLoading.value = true;
          final result = <UserModel>[];
          for (final doc in snap.docs) {
            final uid = doc.id;
            try {
              final userDoc = await _db.collection('users').doc(uid).get();
              if (userDoc.exists) {
                result.add(UserModel.fromFirestore(uid, userDoc.data() ?? {}));
              }
            } catch (_) {}
          }
          following.assignAll(result);
          isLoading.value = false;
        });
    _subs.add(sub.cancel);
  }

  // ── Pending follow requests ───────────────────────────────
  void _subscribeRequests() {
    final myUid = _myUid;
    if (myUid == null) return;

    final sub = _db
        .collection('users')
        .doc(myUid)
        .collection('followRequests')
        .snapshots()
        .listen((snap) async {
          final result = <UserModel>[];
          for (final doc in snap.docs) {
            final fromUid = doc['from'] as String? ?? doc.id;
            try {
              final userDoc = await _db.collection('users').doc(fromUid).get();
              if (userDoc.exists) {
                result.add(
                  UserModel.fromFirestore(fromUid, userDoc.data() ?? {}),
                );
              }
            } catch (_) {}
          }
          pendingRequests.assignAll(result);
        });
    _subs.add(sub.cancel);
  }

  // ── Firestore search (name prefix match) ──────────────────
  Future<void> _runSearch() async {
    final query = searchQuery.value.trim();
    if (query.length < 2) {
      searchResults.clear();
      isSearching.value = false;
      return;
    }

    isSearching.value = true;
    try {
      // Firestore'da büyük-küçük harf duyarsız prefix araması:
      // fullName >= query  AND  fullName <= query + '\uf8ff'
      final snap = await _db
          .collection('users')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      final myUid = _myUid;
      final results = snap.docs
          .where((d) => d.id != myUid) // kendini gösterme
          .map((d) => UserModel.fromFirestore(d.id, d.data()))
          .toList();

      searchResults.assignAll(results);
    } catch (e) {
      searchResults.clear();
    } finally {
      isSearching.value = false;
    }
  }

  // ── Filtered views (search over following list) ───────────
  List<UserModel> get filteredFollowing {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.length < 2) return following;
    return following
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) ||
              u.position.toLowerCase().contains(q),
        )
        .toList();
  }

  List<UserModel> get filteredRequests {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.length < 2) return pendingRequests;
    return pendingRequests
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) ||
              u.position.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Accept follow request ─────────────────────────────────
  Future<void> acceptRequest(String fromUid) async {
    try {
      final ctrl = Get.find<ProfileController>();
      await ctrl.acceptFollowRequest(fromUid);
    } catch (_) {
      // ProfileController yoksa doğrudan Firestore batch yap
      final myUid = _myUid;
      if (myUid == null) return;
      final batch = _db.batch();
      batch.set(
        _db.collection('users').doc(myUid).collection('followers').doc(fromUid),
        {'uid': fromUid, 'since': FieldValue.serverTimestamp()},
      );
      batch.set(
        _db.collection('users').doc(fromUid).collection('following').doc(myUid),
        {'uid': myUid, 'since': FieldValue.serverTimestamp()},
      );
      batch.update(_db.collection('users').doc(myUid), {
        'followersCount': FieldValue.increment(1),
      });
      batch.update(_db.collection('users').doc(fromUid), {
        'followingCount': FieldValue.increment(1),
      });
      batch.delete(
        _db
            .collection('users')
            .doc(myUid)
            .collection('followRequests')
            .doc(fromUid),
      );
      await batch.commit();
    }
  }

  // ── Reject follow request ─────────────────────────────────
  Future<void> rejectRequest(String fromUid) async {
    final myUid = _myUid;
    if (myUid == null) return;
    await _db
        .collection('users')
        .doc(myUid)
        .collection('followRequests')
        .doc(fromUid)
        .delete();
  }

  // ── Send match invite (opens bottom sheet) ────────────────
  Future<void> sendMatchInvite({
    required BuildContext context,
    required String targetUid,
    required String targetName,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return;

    // Kullanıcının kurduğu, tarihi geçmemiş maçları getir
    final now = Timestamp.now();
    QuerySnapshot snap;
    try {
      snap = await _db
          .collection('matches')
          .where('createdBy', isEqualTo: myUid)
          .where('date', isGreaterThanOrEqualTo: now)
          .orderBy('date')
          .limit(10)
          .get();
    } catch (e) {
      Get.snackbar('Hata', 'Maçlar yüklenemedi: $e');
      return;
    }

    if (snap.docs.isEmpty) {
      Get.snackbar(
        'Maç Bulunamadı',
        'Davet gönderebilmek için önce bir maç kurman gerekiyor.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Bottom sheet'i aç
    // ignore: use_build_context_synchronously
    Get.bottomSheet(
      _MatchInviteSheet(
        matches: snap.docs,
        targetUid: targetUid,
        targetName: targetName,
        myUid: myUid,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

// ── Match Invite Bottom Sheet ────────────────────────────────
class _MatchInviteSheet extends StatelessWidget {
  final List<QueryDocumentSnapshot> matches;
  final String targetUid;
  final String targetName;
  final String myUid;

  const _MatchInviteSheet({
    required this.matches,
    required this.targetUid,
    required this.targetName,
    required this.myUid,
  });

  static const _green = Color(0xFF2EED7B);

  Future<void> _sendInvite(
    BuildContext context,
    QueryDocumentSnapshot matchDoc,
  ) async {
    final data = matchDoc.data() as Map<String, dynamic>;
    final matchId = matchDoc.id;
    final title = data['title'] ?? 'Maç';
    final date = data['date'] as Timestamp?;

    // Notif gönder
    try {
      final notifCtrl = Get.find<NotificationsController>();
      await notifCtrl.addNotificationToUser(
        targetUid: targetUid,
        title: 'Maç Daveti ⚽',
        message: 'Seni "$title" maçına davet etti.',
        // extra payload — addNotificationToUser imzamıza type/matchId ekleyeceğiz
      );

      // NotificationsController imzasını extend etmek yerine doğrudan Firestore
      // üzerinden type ve matchId alanlarını da yazıyoruz:
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .add({
            'title': 'Maç Daveti ⚽',
            'message': 'Seni "$title" maçına davet etti.',
            'type': 'match_invite',
            'matchId': matchId,
            'matchTitle': title,
            'matchDate': date,
            'fromUid': myUid,
            'createdAt': FieldValue.serverTimestamp(),
          });

      Get.back(); // bottom sheet kapat
      Get.snackbar(
        'Davet Gönderildi ✅',
        '$targetName adlı oyuncuya "$title" için davet gönderildi!',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('Hata', 'Davet gönderilemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF16221A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F1712);
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hangi maça davet edelim?',
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$targetName adlı oyuncuya davet gönderilecek',
            style: TextStyle(
              color: subColor,
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 16),
          ...matches.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final title = d['title'] ?? 'İsimsiz Maç';
            final venue = d['venue'] ?? '';
            final ts = d['date'] as Timestamp?;
            final date = ts != null
                ? '${ts.toDate().day}/${ts.toDate().month}  '
                      '${ts.toDate().hour.toString().padLeft(2, '0')}:'
                      '${ts.toDate().minute.toString().padLeft(2, '0')}'
                : '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _sendInvite(context, doc),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F1712)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sports_soccer,
                          color: _green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (venue.isNotEmpty || date.isNotEmpty)
                              Text(
                                [
                                  if (venue.isNotEmpty) venue,
                                  if (date.isNotEmpty) date,
                                ].join(' • '),
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 12,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.send_rounded, color: _green, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
