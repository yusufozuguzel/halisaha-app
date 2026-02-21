import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_view.dart';
import 'discover_view.dart';
import 'profile_view.dart';

class MyMatchesView extends StatefulWidget {
  const MyMatchesView({super.key});

  @override
  State<MyMatchesView> createState() => _MyMatchesViewState();
}

class _MyMatchesViewState extends State<MyMatchesView> {
  bool _isUpcoming = true;

  static const Color _bgColor = Color(0xFF0F1712);
  static const Color _cardBg = Color(0xFF16221A);
  static const Color _neonGreen = Color(0xFF2EED7B);
  static const Color _textWhite = Colors.white;
  static const Color _textGrey = Color(0xFF8A9E94);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _neonGreen,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _neonGreen.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () {},
          child: const Icon(Icons.add, size: 32, color: Color(0xFF0F1712)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildTabToggle(),
              const SizedBox(height: 20),
              _buildMatchCard(
                leftBorderColor: _neonGreen,
                icon: Icons.sports_soccer,
                iconColor: _neonGreen,
                venueName: 'Gold Arena Halı Saha',
                location: 'Şişli, İstanbul',
                time: '20:00',
                dateLabel: 'Bugün',
                showBubble: true,
                avatarColors: [
                  const Color(0xFF5E6AD2),
                  const Color(0xFF8B5CF6),
                  const Color(0xFFEC4899),
                ],
                extraCount: '+8',
                statusText: 'kişi katılıyor',
              ),
              const SizedBox(height: 14),
              _buildMatchCard(
                leftBorderColor: const Color(0xFFF59E0B),
                icon: Icons.stadium_outlined,
                iconColor: const Color(0xFFF59E0B),
                venueName: 'Vadi İstanbul Arena',
                location: 'Sarıyer, İstanbul',
                time: '21:30',
                dateLabel: 'Yarın',
                showBubble: false,
                avatarColors: [
                  const Color(0xFFEF4444),
                  const Color(0xFF3B82F6),
                ],
                extraCount: '+3',
                statusText: '5 kişi eksik',
              ),
              const SizedBox(height: 14),
              _buildMatchCard(
                leftBorderColor: const Color(0xFF3B82F6),
                icon: Icons.sports_outlined,
                iconColor: const Color(0xFF3B82F6),
                venueName: 'Beşiktaş Çim Saha',
                location: 'Beşiktaş, İstanbul',
                time: '19:00',
                dateLabel: 'Cuma',
                showBubble: false,
                avatarColors: [const Color(0xFF6B7280)],
                extraCount: '+12',
                statusText: 'Kadro Tamam',
              ),
              const SizedBox(height: 20),
              _buildDashedAddButton(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Maçlarım',
          style: TextStyle(
            color: _textWhite,
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
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune, color: _textWhite, size: 22),
          ),
        ),
      ],
    );
  }

  // ── Tab Toggle ─────────────────────────────────────────────
  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTab('Gelecek Maçlar', true),
          _buildTab('Geçmiş Maçlar', false),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isUpcoming) {
    final isActive = _isUpcoming == isUpcoming;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isUpcoming = isUpcoming),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _neonGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? _bgColor : _textGrey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── Match Card ─────────────────────────────────────────────
  Widget _buildMatchCard({
    required Color leftBorderColor,
    required IconData icon,
    required Color iconColor,
    required String venueName,
    required String location,
    required String time,
    required String dateLabel,
    required bool showBubble,
    required List<Color> avatarColors,
    required String extraCount,
    required String statusText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Sol renkli dikey çizgi
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: leftBorderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // İçerik
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: ikon + isim + saat/gün
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: iconColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            venueName,
                            style: const TextStyle(
                              color: _textWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              time,
                              style: const TextStyle(
                                color: _textWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (showBubble)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _neonGreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    color: _bgColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  color: _textGrey,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        location,
                        style: const TextStyle(color: _textGrey, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Alt satır: avatarlar + durum + detaylar
                    Row(
                      children: [
                        _buildAvatarStack(avatarColors, extraCount),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: _textGrey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Detaylar',
                              style: TextStyle(
                                color: _textWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildAvatarStack(List<Color> colors, String extra) {
    const double size = 26;
    const double overlap = 16;
    final width = size + (colors.length - 1) * overlap + 30;
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < colors.length; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF16221A),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          Positioned(
            left: colors.length * overlap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF2D3E36),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF16221A), width: 1.5),
              ),
              child: Center(
                child: Text(
                  extra,
                  style: const TextStyle(
                    color: _textWhite,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dashed Add Button ──────────────────────────────────────
  Widget _buildDashedAddButton() {
    return GestureDetector(
      onTap: () {},
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: _textGrey.withValues(alpha: 0.4),
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
                  color: _neonGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: _neonGreen, size: 28),
              ),
              const SizedBox(height: 10),
              const Text(
                'Yeni maç planla',
                style: TextStyle(color: _textGrey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Nav (Maçlarım aktif) ────────────────────────────
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16221A),
        borderRadius: BorderRadius.only(
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
          color: const Color(0xFF16221A),
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavBarItem(
                Icons.home_filled,
                'Ana Sayfa',
                false,
                onTap: () => Get.offAll(
                  () => const HomeView(userName: 'Onur'),
                  transition: Transition.noTransition,
                ),
              ),
              _buildNavBarItem(
                Icons.sports_soccer,
                'Maçlarım',
                true,
                onTap: () {},
              ),
              const SizedBox(width: 48),
              _buildNavBarItem(
                Icons.explore_outlined,
                'Keşfet',
                false,
                onTap: () => Get.offAll(
                  () => const DiscoverView(),
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
    final color = isActive ? _neonGreen : Colors.white.withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: _neonGreen.withValues(alpha: 0.15),
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

// ── Dashed Border Painter ──────────────────────────────────────
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
