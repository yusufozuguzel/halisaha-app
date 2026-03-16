import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/block_controller.dart';
import '../../../core/theme/app_theme.dart';

class BlockedUsersView extends GetView<BlockController> {
  const BlockedUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller'ı sayfaya bağlıyoruz
    if (!Get.isRegistered<BlockController>()) {
      Get.put(BlockController());
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text(
          'Engellenen Kişiler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.bg(context),
        centerTitle: true,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2EED7B)),
          );
        }

        if (controller.blockedUserIds.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.blockedUserIds.length,
          itemBuilder: (context, index) {
            final uid = controller.blockedUserIds[index];
            return _buildBlockedUserTile(uid, context);
          },
        );
      }),
    );
  }

  Widget _buildBlockedUserTile(String uid, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2EED7B).withOpacity(0.2),
            child: const Icon(Icons.person, color: Color(0xFF2EED7B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kullanıcı: ${uid.substring(0, 8)}...', // Şimdilik ID gösteriyoruz, sonra isim çekeriz
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => _showUnblockDialog(uid, context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              foregroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Engeli Kaldır',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 80,
            color: AppColors.subText(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz kimseyi engellemedin.',
            style: TextStyle(color: AppColors.subText(context), fontSize: 15),
          ),
        ],
      ),
    );
  }

  void _showUnblockDialog(String uid, BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card(context),
        title: const Text('Engeli Kaldır?'),
        content: const Text(
          'Bu kullanıcının engeli kaldırılacak. Onaylıyor musun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'İptal',
              style: TextStyle(color: AppColors.subText(context)),
            ),
          ),
          TextButton(
            onPressed: () {
              controller.unblockUser(uid);
              Get.back();
            },
            child: const Text(
              'Kaldır',
              style: TextStyle(
                color: Color(0xFF2EED7B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
