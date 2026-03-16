import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'my_matches_view.dart';
import 'notifications_view.dart' hide kGreen;
import '../controllers/home_controller.dart';
import 'discover_view.dart';
import 'profile_view.dart';
import '../../../routes/app_routes.dart';
import '../../friends/views/friends_view.dart';
import '../../../core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';

// 👇 BİZİM EFSANE FORMU İÇERİ ALIYORUZ 👇
import '../../match/controllers/match_create_controller.dart';
import '../../match/views/match_create_view.dart';

class HomeView extends StatefulWidget {
  final String userName;
  const HomeView({super.key, required this.userName});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ScrollController _scrollController = ScrollController();
  late Color _bg;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 👇 YÖNLENDİRME METODUMUZ (HER İKİ BUTON DA BUNU KULLANACAK) 👇
  void _goToCreateMatch() {
    // Beynini (Controller'ı) hazırlayıp efsane form sayfasına geçiyoruz
    Get.put(MatchCreateController());
    Get.to(
      () => const MatchCreateView(),
      transition: Transition.downToUp, // Alttan yukarı şık bir animasyon
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    _bg = AppColors.bg(context);

    Get.put(HomeController());

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 32),
              _buildNextMatchCard(),
              const SizedBox(height: 32),
              _buildDailyFields(),
              const SizedBox(height: 32),
              _buildFriendActivities(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      // 👇 ORTADAKİ DEVASA YEŞİL "+" BUTONU 👇
      floatingActionButton: GestureDetector(
        onTap: _goToCreateMatch, // Direkt bizim metodu çağırıyor
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF2EED7B), // kGreen
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2EED7B).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.add, size: 32, color: _bg),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ── Bottom Navigation Bar ───────────────────────────────────
  Widget _buildBottomNavigationBar() {
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
              _buildNavBarItem(
                Icons.home_filled,
                'Ana Sayfa',
                true,
                onTap: () {},
              ),
              _buildNavBarItem(
                Icons.sports_soccer,
                'Maçlarım',
                false,
                onTap: () => Get.offAll(
                  () => MyMatchesView(),
                  transition: Transition.noTransition,
                ),
              ),
              const SizedBox(width: 48),
              _buildNavBarItem(
                Icons.explore_outlined,
                'Keşfet',
                false,
                onTap: () => Get.offAll(
                  () => DiscoverView(),
                  transition: Transition.noTransition,
                ),
              ),
              _buildNavBarItem(
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

  Widget _buildNavBarItem(
    IconData icon,
    String label,
    bool isActive, {
    required VoidCallback onTap,
  }) {
    final color = isActive ? kGreen : AppColors.navInactive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: kGreen.withValues(alpha: 0.15),
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

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
    final bg = AppColors.bg(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF2EED7B)),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final fullName = data['fullName'] ?? data['name'] ?? widget.userName;
        final avatarData = data['avatarData'] ?? '0';
        final avatarUrl = data['avatarUrl'] ?? '';

        Widget avatarWidget;
        if (avatarUrl.isNotEmpty) {
          avatarWidget = ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (context, error, stackTrace) =>
                  Icon(Icons.person, color: textColor, size: 24),
            ),
          );
        } else {
          final iconIndex = int.tryParse(avatarData.toString()) ?? 0;
          final List<IconData> defaultIcons = [
            Icons.person,
            Icons.sports_soccer,
            Icons.sports_martial_arts,
            Icons.face,
          ];
          avatarWidget = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.overlay(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              defaultIcons[iconIndex % defaultIcons.length],
              color: textColor,
              size: 24,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: textColor.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: avatarWidget,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2EED7B),
                        shape: BoxShape.circle,
                        border: Border.all(color: bg, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hoş geldin,',
                    style: TextStyle(
                      color: subText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$fullName 👋',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Friends icon button
              GestureDetector(
                onTap: () => Get.to(
                  () => const FriendsView(),
                  transition: Transition.fadeIn,
                  duration: const Duration(milliseconds: 300),
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.overlay(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_alt_outlined,
                    color: textColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Notifications icon button
              GestureDetector(
                onTap: () => Get.to(
                  () => const NotificationsView(),
                  transition: Transition.fadeIn,
                  duration: const Duration(milliseconds: 300),
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.overlay(context),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: textColor,
                        size: 22,
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Quick Actions ───────────────────────────────────────────
  Widget _buildQuickActions() {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Expanded(
            // --- SOL KART: YENİ MAÇ BAŞLAT ---
            child: GestureDetector(
              onTap: _goToCreateMatch,
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kGreen.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, color: kDarkBg, size: 22),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Organizasyon',
                          style: TextStyle(
                            color: kDarkBg,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Yeni Maç\nBaşlat',
                          style: TextStyle(
                            color: kDarkBg,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            // 👇 SAĞ KART: UYGULAMAYI PAYLAŞ (QR YERİNE) 👇
            child: GestureDetector(
              onTap: () {
                // Uygulamanın genel davet linki
                SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Halı saha ve futsal maçlarını efsane bir şekilde organize ettiğimiz yeni uygulamamızı denedin mi? Hemen katıl: https://bizimuygulama.com/indir',
                  ),
                );
              },
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.overlay(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.overlay(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.share_outlined,
                        color: kGreen,
                        size: 20,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bağlantı Gönder',
                          style: TextStyle(
                            color: subText,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Arkadaşlarını\nDavet Et',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Next Match Card ─────────────────────────────────────────
  // ── Next Match Card (🔥 GERÇEK FİREBASE VERİSİ 🔥) ────────────
  Widget _buildNextMatchCard() {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);

    // Yukarıda ayağa kaldırdığımız controller'ı buluyoruz
    final homeController = Get.find<HomeController>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sıradaki Maç',
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
                  color: kGreen.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 👇 Obx ile Firebase'i canlı canlı dinliyoruz! 👇
        Obx(() {
          // 1. Veri yükleniyorsa dönen top göster
          if (homeController.isNextMatchLoading.value) {
            return const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2EED7B)),
              ),
            );
          }

          // 2. Eğer sıradaki maç yoksa
          final nextMatch = homeController.nextMatch.value;
          if (nextMatch == null) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.overlay(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Yaklaşan bir maçın bulunmuyor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subText,
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _goToCreateMatch,
                    child: const Text(
                      'Hemen bir maç kur veya katıl!',
                      style: TextStyle(
                        color: Color(0xFF2EED7B),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 3. Veri varsa ekrana çiz
          final dateStr =
              "${nextMatch.date.day.toString().padLeft(2, '0')}/${nextMatch.date.month.toString().padLeft(2, '0')}/${nextMatch.date.year}";
          final timeStr =
              "${nextMatch.date.hour.toString().padLeft(2, '0')}:${nextMatch.date.minute.toString().padLeft(2, '0')}";

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://picsum.photos/seed/field1/800/400',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Color(0xFF2EED7B),
                                  size: 8,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Yaklaşıyor',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nextMatch.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Kapasite: ${nextMatch.maxPlayers} Kişi',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 100,
                                height: 32,
                                child: Stack(
                                  children: [
                                    _buildAvatarPlaceholder(
                                      0,
                                      'https://picsum.photos/seed/av2/100/100',
                                    ),
                                    _buildAvatarPlaceholder(
                                      24,
                                      'https://picsum.photos/seed/av3/100/100',
                                    ),
                                    Positioned(
                                      left: 48,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Get.toNamed(
                                  Routes.MATCH_DETAIL,
                                  arguments: nextMatch.id,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Detaylar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(double left, String url) {
    return Positioned(
      left: left,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }

  // ── Daily Fields ────────────────────────────────────────────
  Widget _buildDailyFields() {
    final textColor = AppColors.text(context);
    final homeController = Get.find<HomeController>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Günün Sahaları',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _scrollController.animateTo(
                      _scrollController.offset - 250,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: _buildArrowButton(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _scrollController.animateTo(
                      _scrollController.offset + 250,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: _buildArrowButton(Icons.arrow_forward),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: Obx(() {
            if (homeController.isVenuesLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2EED7B)),
              );
            }

            if (homeController.dailyVenues.isEmpty) {
              return Center(
                child: Text(
                  'Henüz kayıtlı saha bulunamadı.',
                  style: TextStyle(
                    color: AppColors.subText(context),
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              );
            }

            return ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemCount: homeController.dailyVenues.length,
              itemBuilder: (_, index) {
                final venue = homeController.dailyVenues[index];
                return _buildFieldCard(
                  venue['name'] ?? 'Bilinmiyor',
                  venue['city'] ?? '',
                  '⚽',
                  'https://picsum.photos/seed/${venue['id']}/800/400',
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildArrowButton(IconData icon) {
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

  Widget _buildFieldCard(
    String name,
    String location,
    String rating,
    String imageUrl,
  ) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFC107), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  location,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Friend Activities ───────────────────────────────────────
  Widget _buildFriendActivities() {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
    final homeController = Get.find<HomeController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arkadaşların Neler Yapıyor?',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (homeController.isActivitiesLoading.value) {
              return const Center(child: CircularProgressIndicator(color: kGreen));
            }

            final activities = homeController.friendActivities;

            // --- EMPTY STATE ---
            if (activities.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.overlay(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 48,
                      color: subText.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz kimseyi takip etmiyorsun\nveya arkadaşların şu an aktif değil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subText,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }

            // --- DYNAMIC FEED ---
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildActivityItem(
                  name: activity.userName,
                  action: activity.action,
                  time: activity.time,
                  avatarUrl: activity.userAvatar,
                  showJoinButton: activity.matchId != null,
                  icon: activity.isCreated ? Icons.add_circle : Icons.check_circle,
                  iconColor: activity.isCreated ? Colors.blue : kGreen,
                  matchId: activity.matchId,
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String name,
    required String action,
    required String time,
    required String avatarUrl,
    required bool showJoinButton,
    required IconData icon,
    required Color iconColor,
    String? matchId,
  }) {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.overlay(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2),
                  ),
                  child: Icon(icon, color: Colors.white, size: 10),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: textColor,
                    ),
                    children: [
                      TextSpan(
                        text: name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: action,
                        style: TextStyle(color: textColor.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: subText,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
                  if (showJoinButton) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        if (matchId != null) {
                          Get.toNamed('/match-detail', arguments: matchId);
                        }
                      },
                      child: Text(
                        'Katıl',
                      style: TextStyle(
                        color: kGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
