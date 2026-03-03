import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/notifications_controller.dart';

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

                  if (docs.isEmpty) {
                    return _buildEmpty(context);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildCard(
                        context: context,
                        docId: doc.id,
                        title: data['title'] ?? '',
                        message: data['message'] ?? '',
                        timestamp: data['createdAt'] as Timestamp?,
                        controller: controller,
                      );
                    },
                  );
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
              Get.snackbar(
                'Temizlendi',
                'Tüm bildirimler silindi.',
                backgroundColor: AppColors.isDark(context)
                    ? const Color(0xFF1C2B21)
                    : const Color(0xFFE8F5EC),
                colorText: kGreen,
                borderRadius: 12,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
                icon: const Icon(Icons.done_all, color: kGreen),
              );
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

  // ─── Bildirim Kartı ──────────────────────────────────────────────────────────
  Widget _buildCard({
    required BuildContext context,
    required String docId,
    required String title,
    required String message,
    required Timestamp? timestamp,
    required NotificationsController controller,
  }) {
    return Container(
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
            // Üst satır: ikon + başlık + zaman
            Row(
              children: [
                // Bildirim İkonu
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
                // Başlık + Mesaj
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
                // Tarih / Saat
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
            // Sil butonu
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => controller.deleteNotification(docId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
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

  // ─── Zaman Formatlama (intl paketi kullanmadan) ──────────────────────────────
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';

    final months = [
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

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (diff.inDays == 1) return 'Dün, $hour:$minute';

    return '$day $month, $hour:$minute';
  }
}
