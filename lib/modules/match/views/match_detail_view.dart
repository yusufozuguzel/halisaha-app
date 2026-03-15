import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/match_detail_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MatchDetailView extends StatelessWidget {
  const MatchDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MatchDetailController());

    return Obx(() {
      // 1. DINAMIK YÜKLEME EKRANI (Aydınlık/Karanlık mod uyumlu AppColors.bg kullanıldı)
      if (controller.isLoading.value) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF2EED7B)),
          ),
        );
      }

      final match = controller.matchData.value;

      // 2. HATA VEYA MAÇ BULUNAMADI DURUMU
      if (match == null) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.text(context),
                size: 20,
              ),
              onPressed: () => Get.back(),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.subText(context).withOpacity(0.5),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Maç detayı bulunamadı\nveya silinmiş olabilir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subText(context),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EED7B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Geri Dön',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 3. BAŞARILI DURUM (Maç Detayı Render İşlemi)
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.text(context),
              size: 20,
            ),
            onPressed: () => Get.back(),
          ),
          title: Text(
            'Maç Detayı',
            style: TextStyle(
              color: AppColors.text(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,

          // 👇 EKLENEN YENİ KISIM TAM OLARAK BURASI 👇
          actions: [
            IconButton(
              icon: const Icon(
                Icons.share,
                color: Color(0xFF2EED7B),
              ), // Neon Yeşil İkon
              onPressed: () {
                final matchTitle = match['title'] ?? 'Efsane Maç';
                final matchDate = controller.formatDate(
                  match['date'] as Timestamp?,
                );
                // Get.arguments bizim liste sayfasından yolladığımız maç ID'si
                final matchLink =
                    "https://bizimuygulama.com/mac/${Get.arguments}";

                Share.share(
                  'Sahaya çıkıyoruz! ⚽\n\n"$matchTitle" maçında kadroda yerini al.\n📅 Tarih: $matchDate\n\nHemen katılmak için tıkla:\n$matchLink',
                );
              },
            ),
            const SizedBox(width: 8), // Sağdan biraz boşluk
          ],

          // 👆 EKLENEN KISIM BİTİŞ 👆
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Maç Adı (Title)
              Text(
                match['title'] ?? 'İsimsiz Maç',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),

              // Tarih ve Mekan Kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Color(0xFF2EED7B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          controller.formatDate(match['date'] as Timestamp?),
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF2EED7B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          match['venue'] ?? 'Mekan Belirtilmedi',
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Kadro (Oyuncular) Bilgisi
              Text(
                'Kadro Durumu',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.people_alt,
                          color: Color(0xFF2EED7B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Mevcut Oyuncular:',
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(match['currentPlayers'] as List?)?.length ?? 0} / ${match['maxPlayers'] ?? 14}',
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Oyuncu Listesi
              Builder(builder: (context) {
                final currentPlayers = (match['currentPlayers'] as List<dynamic>?) ?? [];
                if (currentPlayers.isEmpty) return const SizedBox.shrink();

                final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
                final isCreator = currentUserUid == match['createdBy'];

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentPlayers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final uid = currentPlayers[index].toString();

                    // Her satır kendi Obx'i içinde RxMap'ten veriyi okur.
                    // Böylece GetX sadece bu satır için güncelleme yapar,
                    // "improper use" hatası fırlatmaz.
                    return Obx(() {
                      final playerInfo = controller.participantDetails[uid];

                      if (playerInfo == null) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                              child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2EED7B)))),
                        );
                      }

                      // Avatar
                      final ppUrl = playerInfo['avatarUrl'] ?? playerInfo['profileImageUrl'] ?? playerInfo['photoUrl'] ?? playerInfo['avatar'] ?? playerInfo['image'];
                      final fallbackName = playerInfo['name']?.toString() ?? 'Bilinmiyor';
                      final initial = fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : '?';

                      ImageProvider? avatarImage;
                      if (ppUrl != null && ppUrl.toString().isNotEmpty) {
                        avatarImage = CachedNetworkImageProvider(ppUrl.toString());
                      }

                      final bool isMe = currentUserUid == uid;
                      final bool isMatchCreator = match['createdBy'] == uid;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card(context).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF2EED7B).withValues(alpha: 0.2),
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? Text(initial,
                                      style: const TextStyle(color: Color(0xFF2EED7B), fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    isMe ? 'Sen' : fallbackName,
                                    style: TextStyle(
                                      color: isMe ? const Color(0xFF2EED7B) : AppColors.text(context),
                                      fontSize: 16,
                                      fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  if (isMatchCreator) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                  ],
                                ],
                              ),
                            ),
                            if (isCreator && !isMe)
                              IconButton(
                                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                tooltip: 'Oyuncuyu Çıkar',
                                onPressed: () {
                                  Get.defaultDialog(
                                    title: 'Oyuncuyu Çıkar',
                                    middleText: '\n$fallbackName adlı oyuncuyu maçtan çıkarmak istediğinize emin misiniz?',
                                    titleStyle: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold),
                                    middleTextStyle: TextStyle(color: AppColors.text(context)),
                                    backgroundColor: AppColors.card(context),
                                    textCancel: 'İptal',
                                    textConfirm: 'Çıkar',
                                    confirmTextColor: Colors.white,
                                    buttonColor: Colors.redAccent,
                                    cancelTextColor: AppColors.text(context),
                                    onConfirm: () {
                                      Get.back();
                                      controller.kickPlayer(uid);
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    });
                  },
                );
              }),
            ],
          ),
        ),
      );
    });
  }
}
