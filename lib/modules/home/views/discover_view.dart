import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_view.dart';
import 'my_matches_view.dart';
import 'profile_view.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// Data Models
// ============================================================
class _FieldData {
  final String name, location, distance, rating, price, imageUrl;
  _FieldData({
    required this.name,
    required this.location,
    required this.distance,
    required this.rating,
    required this.price,
    required this.imageUrl,
  });
}

class _MatchData {
  final String title, venue, time, statusLabel, playerCount;
  final Color statusColor;
  final List<String> avatarUrls;
  _MatchData({
    required this.title,
    required this.venue,
    required this.time,
    required this.statusLabel,
    required this.statusColor,
    required this.playerCount,
    required this.avatarUrls,
  });
}

// ============================================================
// Page
// ============================================================
class DiscoverView extends StatefulWidget {
  const DiscoverView({super.key});

  @override
  State<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<DiscoverView> {
  // Dinamik renkler — build() içinde hesaplanır
  late Color _bg;
  late Color _card;
  static const _green = kGreen;

  final ScrollController _popularMatchesController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // ---- Dummy Data ----
  final List<_FieldData> _fields = [
    _FieldData(
      name: 'Gold Arena Halı Saha',
      location: 'Şişli, İstanbul',
      distance: '1.2 km',
      rating: '4.9',
      price: '₺1200',
      imageUrl: 'https://picsum.photos/seed/dfield1/800/400',
    ),
    _FieldData(
      name: 'Vadi İstanbul Arena',
      location: 'Sarıyer, İstanbul',
      distance: '3.5 km',
      rating: '4.8',
      price: '₺1400',
      imageUrl: 'https://picsum.photos/seed/dfield2/800/400',
    ),
  ];

  late final List<_MatchData> _popularMatches = [
    _MatchData(
      title: 'Salı Akşamı Derbisi',
      venue: 'Kadıköy Spor Kompleksi',
      time: '20:00',
      statusLabel: '2/14 Oyuncu',
      statusColor: const Color(0xFF3B82F6),
      playerCount: '+7',
      avatarUrls: [
        'https://picsum.photos/seed/dav1/100/100',
        'https://picsum.photos/seed/dav2/100/100',
      ],
    ),
    _MatchData(
      title: 'Gece Karşılaşması',
      venue: 'Beşiktaş Çim Saha',
      time: '22:00',
      statusLabel: 'Son 1 Kişi',
      statusColor: const Color(0xFFF59E0B),
      playerCount: '+11',
      avatarUrls: [
        'https://picsum.photos/seed/dav3/100/100',
        'https://picsum.photos/seed/dav4/100/100',
      ],
    ),
    _MatchData(
      title: 'Hafta Sonu Turnuva',
      venue: 'Ataşehir Arena',
      time: '10:00',
      statusLabel: 'Açık Kayıt',
      statusColor: _green,
      playerCount: '+4',
      avatarUrls: ['https://picsum.photos/seed/dav5/100/100'],
    ),
  ];

  @override
  void dispose() {
    _popularMatchesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    Get.bottomSheet(
      _FilterSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _applyToMatch(_MatchData match) {
    Get.snackbar(
      'Katılım',
      '${match.title} maçına katılım isteği gönderildi!',
      backgroundColor: const Color(0xFF1C3A24),
      colorText: _green,
      borderRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle, color: _green),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    _bg = AppColors.bg(context);
    _card = AppColors.card(context);

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: GestureDetector(
        onTap: () => Get.toNamed(Routes.MATCH_CREATE),
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
          child: Icon(Icons.add, size: 32, color: _bg),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildNearbyFields(),
              const SizedBox(height: 28),
              _buildPopularMatches(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header + Search ─────────────────────────────────────────
  Widget _buildHeader() {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
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
                  backgroundColor: _card,
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
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: TextField(
                    controller: _searchController,
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
                    color: _card,
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

  // ── Nearby Fields ───────────────────────────────────────────
  Widget _buildNearbyFields() {
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
        ..._fields.map((f) => _buildFieldCard(f)).toList(),
      ],
    );
  }

  Widget _buildFieldCard(_FieldData field) {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: _card,
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
                child: Image.network(field.imageUrl, fit: BoxFit.cover),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFC107),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        field.rating,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
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
                        field.name,
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
                          Text(
                            '${field.location} • ${field.distance}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12,
                              decoration: TextDecoration.none,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saatlik Ücret',
                      style: TextStyle(
                        color: subText,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: field.price,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' / 60dk',
                            style: TextStyle(color: subText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Get.snackbar(
                    'Rezervasyon',
                    'Saha detaylarına gidiliyor...',
                    backgroundColor: const Color(0xFF1C3A24),
                    colorText: _green,
                    borderRadius: 12,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 3),
                    icon: const Icon(Icons.event_available, color: _green),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Rezervasyon',
                      style: TextStyle(
                        color: kDarkBg,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Popular Matches ─────────────────────────────────────────
  Widget _buildPopularMatches() {
    final textColor = AppColors.text(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popüler Maçlar',
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
                    child: _arrowBtn(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _popularMatchesController.animateTo(
                      _popularMatchesController.offset + 250,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: _arrowBtn(Icons.arrow_forward),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 178,
          child: ListView.separated(
            controller: _popularMatchesController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: _popularMatches.length,
            itemBuilder: (_, i) => _buildMatchCard(_popularMatches[i]),
          ),
        ),
      ],
    );
  }

  Widget _arrowBtn(IconData icon) {
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

  Widget _buildMatchCard(_MatchData match) {
    final textColor = AppColors.text(context);
    final subText = AppColors.subText(context);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
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
                  color: match.statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  match.statusLabel,
                  style: TextStyle(
                    color: match.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Text(
                match.time,
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
            match.title,
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
            match.venue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: subText,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 26,
                child: Stack(
                  children: [
                    for (int i = 0; i < match.avatarUrls.length && i < 2; i++)
                      Positioned(
                        left: i * 18.0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: NetworkImage(match.avatarUrls[i]),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(color: _card, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                match.playerCount,
                style: TextStyle(
                  color: subText,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _applyToMatch(match),
                borderRadius: BorderRadius.circular(8),
                child: const Text(
                  'Katıl',
                  style: TextStyle(
                    color: _green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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

  // ── Bottom Nav (Keşfet aktif) ───────────────────────────────
  Widget _buildBottomNav() {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(
                Icons.home_filled,
                'Ana Sayfa',
                false,
                onTap: () => Get.offAll(
                  () => const HomeView(userName: 'Onur'),
                  transition: Transition.noTransition,
                ),
              ),
              _navItem(
                Icons.sports_soccer,
                'Maçlarım',
                false,
                onTap: () => Get.offAll(
                  () => const MyMatchesView(),
                  transition: Transition.noTransition,
                ),
              ),
              const SizedBox(width: 48),
              _navItem(Icons.explore_outlined, 'Keşfet', true, onTap: () {}),
              _navItem(
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
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
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _green = kGreen;

  double _distance = 5;
  double _maxPrice = 1500;
  String _fieldType = 'Hepsi';

  @override
  Widget build(BuildContext context) {
    final sheetBg = AppColors.isDark(context) ? kDarkCard : Colors.white;
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
                          color: _fieldType == t ? kDarkBg : textColor,
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
                    color: kDarkBg,
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
