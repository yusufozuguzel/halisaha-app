import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/notifications_controller.dart';

const kGreen = Color(0xFF2EED7B);

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationsController());

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, controller),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: controller.notificationsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: kGreen),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  return Obx(() {
                    final hiddenIds = controller.hiddenNotificationIds;
                    final matchInvites = controller.matchInvites.where((d) => !hiddenIds.contains(d.id)).toList();
                    final visibleDocs = docs.where((d) => !hiddenIds.contains(d.id)).toList();

                    if (visibleDocs.isEmpty && matchInvites.isEmpty) {
                      return _buildEmpty(context);
                    }

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 24, top: 8),
                      children: [
                        // 1) Maç Davetleri
                        ...matchInvites.map((doc) {
                          return _MatchInviteCard(doc: doc, controller: controller);
                        }),

                        // 2) Diğer Tüm Bildirimler
                        ...visibleDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final type = data['type'] as String? ?? '';

                          if (type == 'follow_request') {
                            return _FollowRequestCard(
                              doc: doc,
                              data: data,
                              controller: controller,
                            );
                          }

                          return _GenericCard(
                            context: context,
                            doc: doc,
                            data: data,
                            controller: controller,
                          );
                        }),
                      ],
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    NotificationsController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Geri butonu
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.overlay(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.text(context),
                size: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Bildirimler',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Tümünü Sil butonu
          GestureDetector(
            onTap: () async {
              await controller.clearAllNotifications();
            },
            child: const Text(
              'Tümünü Sil',
              style: TextStyle(
                color: kGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Boş Durum ───────────────────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: AppColors.subText(context).withOpacity(0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Bildirim yok',
            style: TextStyle(
              color: AppColors.subText(context),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Generic Notification Card ───────────────────────────────────────────────
class _GenericCard extends StatelessWidget {
  final BuildContext context;
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final NotificationsController controller;

  const _GenericCard({
    required this.context,
    required this.doc,
    required this.data,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final timestamp = data['createdAt'] as Timestamp?;

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        controller.deleteNotification(doc.id);
      },
      child: Container(

      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: kGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          color: AppColors.subText(context),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    color: AppColors.subText(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => controller.deleteNotification(doc.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Text(
                    'Sil',
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ))
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    final d = date.day.toString().padLeft(2, '0');
    final m = months[date.month];
    final h = date.hour.toString().padLeft(2, '0');
    final mn = date.minute.toString().padLeft(2, '0');
    if (diff.inDays == 1) return 'Dün, $h:$mn';
    return '$d $m, $h:$mn';
  }
}

// ─── Follow Request Notification Card ────────────────────────────────────────
class _FollowRequestCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final NotificationsController controller;

  const _FollowRequestCard({
    required this.doc,
    required this.data,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = data['senderName'] as String? ?? 'Biri';
    final senderUid = data['senderUid'] as String? ?? '';
    final message = '$senderName seninle arkadaş olmak istiyor.';
    final timestamp = data['createdAt'] as Timestamp?;
    final reqStatus = data['status'] as String? ?? 'pending';

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        controller.deleteNotification(doc.id);
      },
      child: Container(

      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: kGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arkadaşlık İsteği 👥',
                        style: TextStyle(
                          color: AppColors.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          color: AppColors.subText(context),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    color: AppColors.subText(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Status branch ────────────────────────────────
            if (reqStatus == 'pending') ...[
              // Kabul Et / Reddet
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await controller.acceptFollowRequest(
                          senderUid: senderUid,
                          notificationDocId: doc.id,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Kabul Et',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF0F1712),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await controller.rejectFollowRequest(
                          senderUid: senderUid,
                          notificationDocId: doc.id,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.isDark(context)
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Reddet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (reqStatus == 'accepted') ...[
              // Kabul edildi + Geri Takip Et
              Row(
                children: [
                  // Durum etiketi
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: kGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kGreen.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: kGreen,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Kabul Edildi',
                          style: TextStyle(
                            color: kGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Takip etme durumu kontrolü
                  Expanded(
                    child: Obx(() {
                      // Eğer bu kullanıcı için daha check yapılmadıysa veya verisi yoksa false döner
                      final isFollowing =
                          controller.followingStatus[senderUid]?.value ?? false;

                      if (isFollowing) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.subText(
                                context,
                              ).withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            'Arkadaşsınız',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.subText(
                                context,
                              ).withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }

                      // Henüz takip etmiyorsa aktif buton göster
                      return GestureDetector(
                        onTap: () async {
                          await controller.sendFollowBackRequest(
                            targetUid: senderUid,
                          );
                          // Butona tıklandıktan sonra durumu simüle et (veya backend zaten takipçi listesine ekleyecek)
                          controller.checkIfFollowing(senderUid);

                          Get.snackbar(
                            'Arkadaşlık İsteği Gönderildi',
                            '$senderName adlı oyuncuya arkadaşlık isteği gönderildi.',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kGreen.withOpacity(0.5)),
                          ),
                          child: const Text(
                            'Arkadaş Ekle',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ] else if (reqStatus == 'rejected') ...[
              // Reddedildi + silebilir
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Reddedildi',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => controller.deleteNotification(doc.id),
                    child: Text(
                      'Sil',
                      style: TextStyle(
                        color: AppColors.subText(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ))
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    final d = date.day.toString().padLeft(2, '0');
    final m = months[date.month];
    final h = date.hour.toString().padLeft(2, '0');
    final mn = date.minute.toString().padLeft(2, '0');
    if (diff.inDays == 1) return 'Dün, $h:$mn';
    return '$d $m, $h:$mn';
  }
}

// ─── Match Invite Request Notification Card ────────────────────────────────────────
class _MatchInviteCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final NotificationsController controller;

  const _MatchInviteCard({
    required this.doc,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final matchId = data['matchId'] as String? ?? '';
    final positionId = data['positionId'] as String? ?? '';
    final senderId = data['senderId'] as String? ?? '';
    final timestamp = data['createdAt'] as Timestamp?;

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        controller.deleteNotification(doc.id);
      },
      child: Container(

      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
        builder: (context, snapshot) {
          String senderName = "Bir oyuncu";
          String? avatarUrl;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            senderName = userData['fullName'] ?? userData['name'] ?? "Bir oyuncu";
            avatarUrl = userData['avatarUrl'] ?? userData['profileImageUrl'] ?? userData['photoUrl'];
          }

          return Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kGreen.withOpacity(0.12),
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.sports_soccer, color: kGreen, size: 20) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Maç Daveti ⚽',
                            style: TextStyle(
                              color: AppColors.text(context),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$senderName seni bir maça davet etti!',
                            style: TextStyle(
                              color: AppColors.subText(context),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        color: AppColors.subText(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          controller.acceptInvite(doc.id, matchId, positionId);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: kGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Kabul Et',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF0F1712),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          controller.rejectInvite(doc.id, matchId, positionId);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.isDark(context)
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFEEEEEE),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Reddet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      ))
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    const months = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final d = date.day.toString().padLeft(2, '0');
    final m = months[date.month];
    final h = date.hour.toString().padLeft(2, '0');
    final mn = date.minute.toString().padLeft(2, '0');
    if (diff.inDays == 1) return 'Dün, $h:$mn';
    return '$d $m, $h:$mn';
  }
}
