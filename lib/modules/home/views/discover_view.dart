import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'home_view.dart';
import 'my_matches_view.dart';
import 'profile_view.dart';
import '../../match/views/match_formation_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../match/controllers/match_create_controller.dart';
import '../../match/views/match_create_view.dart';
import '../controllers/discover_controller.dart';

// ============================================================
// Page
// ============================================================
class DiscoverView extends GetView<DiscoverController> {
  DiscoverView({super.key}) {
    // Controller hafızada yoksa oluştur
    if (!Get.isRegistered<DiscoverController>()) {
      Get.put(DiscoverController());
    }
  }

  final ScrollController _popularMatchesController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const _green = Color(0xFF2EED7B);

  void _showFilterSheet() {
    Get.bottomSheet(
      const _FilterSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bg(context);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: GestureDetector(
        onTap: () {
          Get.put(MatchCreateController());
          Get.to(
            () => const MatchCreateView(),
            transition: Transition.downToUp,
            duration: const Duration(milliseconds: 300),
          );
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _green.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.add, size: 32, color: bg),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildNearbyFields(context),
              const SizedBox(height: 28),
              _buildPopularMatches(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header + Search ─────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
    final card = AppColors.card(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Keşfet',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => Get.snackbar(
                  'Harita',
                  'Harita görünümü açılıyor...',
                  backgroundColor: card,
                  colorText: textColor,
                  borderRadius: 12,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 2),
                  icon: const Icon(Icons.map, color: _green),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _green.withOpacity(0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, color: _green, size: 15),
                      SizedBox(width: 5),
                      Text(
                        'Haritada Göster',
                        style: TextStyle(
                          color: _green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => controller.onSearchChanged(value),
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Saha veya Şehir Ara',
                      hintStyle: TextStyle(color: subText, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: subText, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _showFilterSheet,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Icon(Icons.tune, color: subText, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Nearby Fields ───────────────────────────────────────────────────────
  Widget _buildNearbyFields(BuildContext context) {
    final textColor = AppColors.text(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Yakındaki Sahalar',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                'Tümü',
                style: TextStyle(
                  color: _green.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Obx(() {
          if (controller.isVenuesLoading.value) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: _green)),
            );
          }

          if (controller.nearbyVenues.isEmpty) {
            return SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Yakınınızda kayıtlı saha bulunamadı.',
                  style: TextStyle(
                    color: AppColors.subText(context),
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            );
          }

          return Column(
            children: controller.nearbyVenues
                .map((venue) => _buildFieldCard(context, venue))
                .toList(),
          );
        }),
      ],
    );
  }

  Widget _buildFieldCard(BuildContext context, Map<String, dynamic> venue) {
    final card = AppColors.card(context);
    final name = venue['name'] ?? 'Bilinmiyor';
    final city = venue['city'] ?? '';
    final distanceMeters = venue['distanceInMeters'] as double?;
    final distanceStr = distanceMeters != null
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : null;

    // Gerçek fotoğrafı çekmeye çalışıyoruz
    String imageUrl =
        venue['photoUrl']?.toString() ?? venue['image']?.toString() ?? '';
    if (imageUrl == 'null') imageUrl = '';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: imageUrl.isNotEmpty
                    // EĞER GERÇEK FOTOĞRAF VARSA ONU GÖSTER
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.overlay(context),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: _green,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildMapPlaceholder(
                              context,
                              name,
                            ), // Hata olursa Harita'ya düş
                      )
                    // EĞER GERÇEK FOTOĞRAF YOKSA ŞIK BİR HARİTA ÖNİZLEMESİ ÇİZ
                    : _buildMapPlaceholder(context, name),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 30, 14, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withOpacity(0.65),
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              distanceStr != null
                                  ? '$city • 📍 $distanceStr'
                                  : city,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12,
                                decoration: TextDecoration.none,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔥 ŞIK HARİTA TASARIMI 🔥
  Widget _buildMapPlaceholder(BuildContext context, String name) {
    return Container(
      color: const Color(0xFF0D1B13), // Koyu yeşil/siyah harita zemini
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka plandaki şık ızgara deseni (Harita izlenimi verir)
          CustomPaint(size: Size.infinite, painter: _GridPainter()),
          // Ortada stadyum/saha pin ikonu
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _green.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.stadium_outlined,
                  color: _green,
                  size: 36,
                ),
              ),
              const SizedBox(height: 8),
              // Konum işareti
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Konumu Haritada Gör',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Popular Matches ─────────────────────────────────────────
  Widget _buildPopularMatches(BuildContext context) {
    final textColor = AppColors.text(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Açık Maçlar',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _popularMatchesController.animateTo(
                      _popularMatchesController.offset - 250,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: _arrowBtn(context, Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _popularMatchesController.animateTo(
                      _popularMatchesController.offset + 250,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: _arrowBtn(context, Icons.arrow_forward),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }

            if (controller.openMatches.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: _green.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Şu an yakın tarihte planlanmış\naçık bir maç bulunmuyor.\nİlk maçı sen oluştur!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.subText(context),
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              controller: _popularMatchesController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: controller.openMatches.length,
              itemBuilder: (_, index) {
                final matchData = controller.openMatches[index];
                return _buildMatchCard(context, matchData);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _arrowBtn(BuildContext context, IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.overlay(context),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.subText(context), size: 16),
    );
  }

  Widget _buildMatchCard(BuildContext context, Map<String, dynamic> matchData) {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
    final card = AppColors.card(context);

    final title = matchData['title'] ?? 'İsimsiz Maç';
    final venue = matchData['venue'] ?? 'Bilinmeyen Saha';
    final dateString = controller.formatDate(matchData['date']);
    final price = matchData['price']?.toString() ?? '0';

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final List<dynamic> currentPlayers = matchData['currentPlayers'] ?? [];

    final bool isUserJoined = currentPlayers.contains(currentUserId);
    final bool isCreator = matchData['createdBy'] == currentUserId;

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Açık',
                  style: TextStyle(
                    color: _green,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Text(
                '$price TL',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            venue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: subText,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateString,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _green,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_outline, color: subText, size: 14),
              const SizedBox(width: 4),
              Text(
                '${(matchData['currentPlayers'] as List?)?.length ?? 1} / ${matchData['maxPlayers'] ?? 14}',
                style: TextStyle(
                  color: subText,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isCreator) ...[
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Get.to(
                        () => const MatchFormationView(),
                        arguments: matchData['id'],
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1712),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.5),
                        ),
                      ),
                      child: const Text(
                        'Kadroyu Düzenle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => controller.cancelMatch(matchData['id']),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1712),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.7)),
                      ),
                      child: const Text(
                        'İptal Et',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                InkWell(
                  onTap: () {
                    if (isUserJoined) {
                      controller.leaveMatch(matchData['id'], currentPlayers);
                    } else {
                      controller
                          .joinMatch(
                            matchData['id'],
                            currentPlayers,
                            matchData['maxPlayers'] ?? 14,
                          )
                          .then((_) {
                            Get.to(
                              () => const MatchFormationView(),
                              arguments: matchData['id'],
                            );
                          });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1712),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUserJoined
                            ? Colors.orangeAccent.shade700
                            : _green.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      isUserJoined ? 'Maçtan Ayrıl' : 'Maça Katıl',
                      style: TextStyle(
                        color: isUserJoined
                            ? Colors.orangeAccent.shade700
                            : _green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        decoration: TextDecoration.none,
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

  // ── Bottom Nav (Keşfet aktif) ─────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    final navBg = AppColors.navBg(context);
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
              _navItem(
                context,
                Icons.home_filled,
                'Ana Sayfa',
                false,
                onTap: () => Get.offAll(
                  () => const HomeView(userName: 'Onur'),
                  transition: Transition.noTransition,
                ),
              ),
              _navItem(
                context,
                Icons.sports_soccer,
                'Maçlarım',
                false,
                onTap: () => Get.offAll(
                  () => MyMatchesView(),
                  transition: Transition.noTransition,
                ),
              ),
              const SizedBox(width: 48),
              _navItem(
                context,
                Icons.explore_outlined,
                'Keşfet',
                true,
                onTap: () {},
              ),
              _navItem(
                context,
                Icons.person_outline,
                'Profil',
                false,
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

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive, {
    required VoidCallback onTap,
  }) {
    final color = isActive ? _green : AppColors.navInactive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: _green.withOpacity(0.15),
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
                decoration: TextDecoration.none,
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

// ============================================================
// Filter Bottom Sheet
// ============================================================
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({super.key});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _green = Color(0xFF2EED7B);

  double _distance = 5;
  double _maxPrice = 1500;
  String _fieldType = 'Hepsi';

  @override
  Widget build(BuildContext context) {
    final sheetBg = AppColors.isDark(context)
        ? const Color(0xFF16221A)
        : Colors.white;
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Filtrele',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 22),

          _label('Mesafe: ${_distance.toInt()} km', subText),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _green,
              inactiveTrackColor: AppColors.border(context),
              thumbColor: _green,
              overlayColor: _green.withOpacity(0.2),
            ),
            child: Slider(
              value: _distance,
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) => setState(() => _distance = v),
            ),
          ),
          const SizedBox(height: 14),

          _label('Maks. Fiyat: ₺${_maxPrice.toInt()}', subText),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _green,
              inactiveTrackColor: AppColors.border(context),
              thumbColor: _green,
              overlayColor: _green.withOpacity(0.2),
            ),
            child: Slider(
              value: _maxPrice,
              min: 500,
              max: 3000,
              divisions: 25,
              onChanged: (v) => setState(() => _maxPrice = v),
            ),
          ),
          const SizedBox(height: 18),

          _label('Saha Tipi', subText),
          const SizedBox(height: 10),
          Row(
            children: ['Hepsi', 'Halı Saha', 'Çim Saha', 'Salon']
                .map(
                  (t) => GestureDetector(
                    onTap: () => setState(() => _fieldType = t),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _fieldType == t
                            ? _green
                            : AppColors.overlay(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _fieldType == t
                              ? _green
                              : AppColors.border(context),
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: _fieldType == t
                              ? const Color(0xFF0F1712)
                              : textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                Get.back();
                Get.snackbar(
                  'Filtre Uygulandı',
                  '${_distance.toInt()} km • ₺${_maxPrice.toInt()} • $_fieldType',
                  backgroundColor: sheetBg,
                  colorText: textColor,
                  borderRadius: 12,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                  icon: const Icon(Icons.tune, color: _green),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Uygula',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F1712),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.none,
      ),
    );
  }
}

// ── Harita Izgarası Çizen Özel Sınıf ──
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2EED7B).withOpacity(0.05)
      ..strokeWidth = 1.0;

    const double step = 20.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
