import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/match_detail_controller.dart';

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
            ],
          ),
        ),
      );
    });
  }
}
