import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/block_controller.dart';
import '../../../core/theme/app_theme.dart';

/// Engellenen kullanıcıların profil bilgilerini tutan model
class _BlockedUserInfo {
  final String uid;
  final String name;
  final String? avatarUrl;
  final String? avatarData;

  const _BlockedUserInfo({
    required this.uid,
    required this.name,
    this.avatarUrl,
    this.avatarData,
  });
}

class BlockedUsersView extends StatefulWidget {
  const BlockedUsersView({super.key});

  @override
  State<BlockedUsersView> createState() => _BlockedUsersViewState();
}

class _BlockedUsersViewState extends State<BlockedUsersView> {
  static const _green = Color(0xFF2EED7B);
  late final BlockController _blockCtrl;

  // UID → profil bilgisi cache
  final Map<String, _BlockedUserInfo> _profileCache = {};
  bool _fetchingProfiles = false;

  @override
  void initState() {
    super.initState();
    _blockCtrl = Get.isRegistered<BlockController>()
        ? Get.find<BlockController>()
        : Get.put(BlockController());

    // UIDs hazır olduğunda profilleri çek
    _blockCtrl.blockedUserIds.listen((_) => _fetchProfiles());
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    if (_fetchingProfiles) return;
    _fetchingProfiles = true;

    final uids = List<String>.from(_blockCtrl.blockedUserIds);
    final db = FirebaseFirestore.instance;

    for (final uid in uids) {
      if (_profileCache.containsKey(uid)) continue;
      try {
        final doc = await db.collection('users').doc(uid).get();
        if (doc.exists) {
          final d = doc.data()!;
          if (mounted) {
            setState(() {
              _profileCache[uid] = _BlockedUserInfo(
                uid: uid,
                name: d['fullName'] ?? d['name'] ?? 'Bilinmeyen Kullanıcı',
                avatarUrl: d['avatarUrl'] as String?,
                avatarData: d['avatarData']?.toString(),
              );
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _profileCache[uid] = _BlockedUserInfo(uid: uid, name: 'Silinmiş Hesap');
            });
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _profileCache[uid] = _BlockedUserInfo(uid: uid, name: 'Erişilemiyor');
          });
        }
      }
    }

    _fetchingProfiles = false;
  }

  @override
  Widget build(BuildContext context) {
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
        if (_blockCtrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2EED7B)),
          );
        }

        if (_blockCtrl.blockedUserIds.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _blockCtrl.blockedUserIds.length,
          itemBuilder: (context, index) {
            final uid = _blockCtrl.blockedUserIds[index];
            final info = _profileCache[uid];
            return _buildBlockedUserTile(uid, info, context);
          },
        );
      }),
    );
  }

  Widget _buildBlockedUserTile(String uid, _BlockedUserInfo? info, BuildContext context) {
    // Avatar widget
    Widget avatar;
    final avatarUrl = info?.avatarUrl ?? '';
    if (avatarUrl.isNotEmpty) {
      avatar = CachedNetworkImage(
        imageUrl: avatarUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const Icon(Icons.person, color: _green),
      );
    } else {
      const icons = [Icons.person, Icons.sports_soccer, Icons.sports_martial_arts, Icons.face];
      final idx = int.tryParse(info?.avatarData ?? '0') ?? 0;
      avatar = Icon(icons[idx % icons.length], color: _green, size: 24);
    }

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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withOpacity(0.15),
              border: Border.all(color: _green.withOpacity(0.3)),
            ),
            child: ClipOval(child: avatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: info == null
                ? Text(
                    '${uid.substring(0, 8)}...',
                    style: TextStyle(
                      color: AppColors.subText(context),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(
                    info.name,
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          ElevatedButton(
            onPressed: () => _showUnblockDialog(uid, info?.name ?? uid, context),
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

  void _showUnblockDialog(String uid, String name, BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card(context),
        title: const Text('Engeli Kaldır?'),
        content: Text(
          '$name adlı kullanıcının engeli kaldırılacak. Onaylıyor musun?',
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
              _blockCtrl.unblockUser(uid);
              _profileCache.remove(uid);
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
