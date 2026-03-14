import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_view.dart';
import 'discover_view.dart';
import 'profile_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../match/controllers/my_matches_controller.dart';
import '../../match/controllers/match_create_controller.dart';
import '../../match/views/match_create_view.dart';

// 👇 İŞTE EKSİK OLAN KAHRAMANLARIMIZ 👇
import '../../match/views/match_detail_view.dart';
import '../../match/services/match_service.dart';

class MyMatchesView extends GetView<MyMatchesController> {
  MyMatchesView({super.key}) {
    // Controller hafızada yoksa oluştur (Örn: doğrudan sayfaya gidildiğinde)
    Get.put(MyMatchesController());
  }

  final RxBool _isUpcoming = true.obs;

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.bg(context);
    final neonGreen = const Color(0xFF2EED7B);
    final navBg = AppColors.navBg(context);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: GestureDetector(
        onTap: () {
          Get.delete<MatchCreateController>();
          Get.to(
            () => const MatchCreateView(),
            binding: BindingsBuilder(() {
              Get.lazyPut<MatchCreateController>(() => MatchCreateController());
            }),
            transition: Transition.downToUp,
            duration: const Duration(milliseconds: 300),
          );
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: neonGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: neonGreen.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.add, size: 32, color: bgColor),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(
        context,
        navBg: navBg,
        neonGreen: neonGreen,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _buildHeader(context),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildTabToggle(context, neonGreen: neonGreen),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return Center(
                    child: CircularProgressIndicator(color: neonGreen),
                  );
                }

                final isUpcomingTab = _isUpcoming.value;
                final displayedMatches = isUpcomingTab
                    ? controller.upcomingMatches
                    : controller.pastMatches;

                if (displayedMatches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isUpcomingTab
                              ? Icons.sports_soccer_outlined
                              : Icons.history,
                          size: 64,
                          color: neonGreen.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isUpcomingTab
                              ? 'Henüz planlanmış bir maçın bulunmuyor.'
                              : 'Henüz tamamlanmış bir maçın bulunmuyor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.text(context).withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                        if (isUpcomingTab) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: _buildDashedAddButton(
                              context,
                              neonGreen: neonGreen,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  itemCount: displayedMatches.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final match = displayedMatches[index];

                    final title = match['title'] ?? 'Bilinmeyen Maç';
                    final venue = match['venue'] ?? 'Bilinmeyen Saha';
                    final price = match['price']?.toString() ?? '0';
                    final maxPlayers = match['maxPlayers']?.toString() ?? '?';
                    final currentPlayers =
                        match['currentPlayers'] as List<dynamic>?;
                    final currentCount =
                        currentPlayers?.length.toString() ?? '1';
                    final timestamp = match['date'];

                    final dateString = controller.formatDate(timestamp);

                    return _buildMatchCard(
                      context: context,
                      neonGreen: neonGreen,
                      title: title,
                      venue: venue,
                      dateText: dateString,
                      quotaText: '$currentCount / $maxPlayers',
                      priceText: '$price TL',
                      matchId: match['id']?.toString() ?? '',
                      currentPlayers: currentPlayers ?? [],
                      matchData: match, // <-- Tüm veriyi geçiyoruz
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Maçlarım',
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune, color: AppColors.text(context), size: 22),
          ),
        ),
      ],
    );
  }

  // ── Tab Toggle ──────────────────────────────────────────────
  Widget _buildTabToggle(BuildContext context, {required Color neonGreen}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTab(context, 'Gelecek Maçlar', true, neonGreen),
          _buildTab(context, 'Geçmiş Maçlar', false, neonGreen),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    String label,
    bool isUpcoming,
    Color neonGreen,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _isUpcoming.value = isUpcoming,
        child: Obx(() {
          final isActive = _isUpcoming.value == isUpcoming;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? neonGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF0F1712)
                    : AppColors.labelColor(context),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Match Card ──────────────────────────────────────────────
  Widget _buildMatchCard({
    required BuildContext context,
    required Color neonGreen,
    required String title,
    required String venue,
    required String dateText,
    required String quotaText,
    required String priceText,
    required String matchId,
    required List<dynamic> currentPlayers,
    required Map<String, dynamic> matchData,
  }) {
    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.card(context);
    final textWhite = AppColors.text(context);
    final textGrey = AppColors.labelColor(context);
    final darkGreenBlack = const Color(0xFF0F1712);

    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Kullanıcının ID'si ile maçın kurucusunun ID'sini (createdBy) karşılaştır
    final bool isCreator = matchData['createdBy'] == currentUserId;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? darkGreenBlack : cardBg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: neonGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sports_soccer, color: neonGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: textWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: neonGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: neonGreen.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            dateText,
                            style: TextStyle(
                              color: neonGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        venue,
                        style: TextStyle(color: textGrey, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        // 1. Satır: Kontenjan ve Fiyat (Sola dayalı)
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              color: textGrey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Kontenjan: $quotaText',
                              style: TextStyle(color: textGrey, fontSize: 12),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.payments_outlined,
                              color: textGrey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              priceText,
                              style: TextStyle(color: textGrey, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 2. Satır: Aksiyon Butonları (Sağa dayalı)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 👇 DETAY BUTONUNA FİREBASE BAĞLANDI 👇
                            GestureDetector(
                              onTap: () {
                                Get.to(
                                  () => const MatchDetailView(),
                                  arguments: matchId,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: darkGreenBlack,
                                  border: Border.all(
                                    color: neonGreen.withOpacity(0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Detaylar',
                                  style: TextStyle(
                                    color: neonGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            // 👇 KURUCU İSE DÜZENLE VE SİL, OYUNCU İSE AYRIL BUTONU 👇
                            if (isCreator) ...[
                              const SizedBox(width: 8),
                              // ✏️ DÜZENLE BUTONU
                              GestureDetector(
                                onTap: () {
                                  Get.delete<MatchCreateController>();
                                  Get.to(
                                    () => const MatchCreateView(),
                                    binding: BindingsBuilder(() {
                                      Get.lazyPut<MatchCreateController>(
                                        () => MatchCreateController(),
                                      );
                                    }),
                                    arguments: matchData,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: darkGreenBlack,
                                    border: Border.all(
                                      color: Colors.blueAccent.withOpacity(0.4),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blueAccent,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => controller.cancelMatch(matchId),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: darkGreenBlack,
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.4),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    await MatchService().leaveMatch(matchId);
                                    Get.snackbar(
                                      "Başarılı",
                                      "Maçtan ayrıldın!",
                                      backgroundColor: Colors.green[100],
                                      colorText: Colors.green[900],
                                    );
                                  } catch (e) {
                                    Get.snackbar(
                                      "Hata",
                                      "Ayrılırken bir sorun oluştu.",
                                      backgroundColor: Colors.red[100],
                                      colorText: Colors.red[900],
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: darkGreenBlack,
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.4),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.exit_to_app,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dashed Add Button ───────────────────────────────────────
  Widget _buildDashedAddButton(
    BuildContext context, {
    required Color neonGreen,
  }) {
    final textGrey = AppColors.labelColor(context);
    return GestureDetector(
      onTap: () {
        Get.delete<MatchCreateController>();
        Get.to(
          () => const MatchCreateView(),
          binding: BindingsBuilder(() {
            Get.lazyPut<MatchCreateController>(() => MatchCreateController());
          }),
          transition: Transition.downToUp,
          duration: const Duration(milliseconds: 300),
        );
      },
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: textGrey.withOpacity(0.4),
          borderRadius: 16,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: neonGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: neonGreen, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                'Yeni maç planla',
                style: TextStyle(color: textGrey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Nav (Maçlarım aktif) ────────────────────────────
  Widget _buildBottomNavigationBar(
    BuildContext context, {
    required Color navBg,
    required Color neonGreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomAppBar(
          color: navBg,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavBarItem(
                context,
                Icons.home_filled,
                'Ana Sayfa',
                false,
                neonGreen,
                onTap: () => Get.offAll(
                  () => const HomeView(userName: 'Oyuncu'),
                  transition: Transition.noTransition,
                ),
              ),
              _buildNavBarItem(
                context,
                Icons.sports_soccer,
                'Maçlarım',
                true,
                neonGreen,
                onTap: () {},
              ),
              const SizedBox(width: 48),
              _buildNavBarItem(
                context,
                Icons.explore_outlined,
                'Keşfet',
                false,
                neonGreen,
                onTap: () => Get.offAll(
                  () => DiscoverView(),
                  transition: Transition.noTransition,
                ),
              ),
              _buildNavBarItem(
                context,
                Icons.person_outline,
                'Profil',
                false,
                neonGreen,
                onTap: () => Get.offAll(
                  () => const ProfileView(),
                  transition: Transition.noTransition,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
    Color neonGreen, {
    required VoidCallback onTap,
  }) {
    final color = isActive ? neonGreen : AppColors.navInactive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: neonGreen.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Dashed Border Painter ───────────────────────────────────────
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  const _DashedBorderPainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 7.0;
    const dashSpace = 5.0;

    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rRect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
