import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/match_create_controller.dart';

class MatchCreateView extends GetView<MatchCreateController> {
  const MatchCreateView({super.key});

  // ─── Color Palette ──────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F1712);
  static const _card = Color(0xFF162318);
  static const _cardBorder = Color(0xFF2A3D2F);
  static const _neon = Color(0xFF2EED7B);
  static const _neonDim = Color(0xFF1A3325);
  static const _labelColor = Color(0xFF8BAF92);
  static const _textWhite = Color(0xFFE8F5EC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildProgressStepper(),
                const SizedBox(height: 28),
                _buildSectionHeader(Icons.info_outline, 'GENEL BİLGİLER'),
                const SizedBox(height: 16),
                _buildGeneralInfoSection(context),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  Icons.calendar_month_outlined,
                  'ZAMAN VE KONUM',
                ),
                const SizedBox(height: 16),
                _buildTimeLocationSection(context),
                const SizedBox(height: 28),
                _buildSectionHeader(Icons.group_outlined, 'TAKIMLAR'),
                const SizedBox(height: 16),
                _buildTeamsSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  // ─── AppBar ─────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      centerTitle: true,
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorder),
          ),
          child: const Icon(Icons.chevron_left, color: _neon, size: 22),
        ),
      ),
      title: const Text(
        'Yeni Maç Oluştur',
        style: TextStyle(
          color: _textWhite,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ─── Progress Stepper ───────────────────────────────────────────────────────
  Widget _buildProgressStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _stepCircle(1, 'DETAYLAR', true),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_neon, Color(0xFF2A3D2F)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _stepCircle(2, 'DAVET', false),
        ],
      ),
    );
  }

  Widget _stepCircle(int number, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _neon : _card,
            border: Border.all(color: isActive ? _neon : _cardBorder, width: 2),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(
                color: isActive ? _bg : _labelColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive ? _neon : _labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ─── Section Header ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(icon, color: _neon, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: _neon,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─── General Info Section ───────────────────────────────────────────────────
  Widget _buildGeneralInfoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Maç Adı'),
          const SizedBox(height: 8),
          _styledTextField(
            controller: controller.titleController,
            hint: 'Örn: Cuma Akşamı Derbisi',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Kişi Sayısı (Max)'),
                    const SizedBox(height: 8),
                    _styledTextField(
                      controller: controller.maxPlayersController,
                      hint: 'Örn: 14',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Maç Ücreti'),
                    const SizedBox(height: 8),
                    _styledTextField(
                      controller: controller.priceController,
                      hint: 'Örn: 1500',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Time & Location Section ─────────────────────────────────────────────────
  Widget _buildTimeLocationSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Tarih'),
                    const SizedBox(height: 8),
                    Obx(() {
                      final date = controller.selectedDate.value;
                      final label = date != null
                          ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                          : 'mm/dd/yy';
                      return _pickerButton(
                        icon: Icons.calendar_today_outlined,
                        label: label,
                        onTap: () => controller.pickDate(context),
                        isSet: date != null,
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Saat'),
                    const SizedBox(height: 8),
                    Obx(() {
                      final time = controller.selectedTime.value;
                      final label = time != null
                          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                          : '--:--';
                      return _pickerButton(
                        icon: Icons.access_time_rounded,
                        label: label,
                        onTap: () => controller.pickTime(context),
                        isSet: time != null,
                        trailingIcon: Icons.watch_later_outlined,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _fieldLabel('Saha Adı / Konum'),
          const SizedBox(height: 8),
          _locationField(),
          const SizedBox(height: 14),
          _mapPlaceholder(),
        ],
      ),
    );
  }

  Widget _pickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSet,
    IconData? trailingIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSet ? _neon : _cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSet ? _neon : _labelColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSet ? _textWhite : _labelColor,
                  fontSize: 14,
                ),
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: _labelColor, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── 24-Hour Time Helper (Removed as it is now in-lined) ───────────────

  Widget _locationField() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: _neon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller.venueController,
              style: const TextStyle(color: _textWhite, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Halı saha adını girin veya seçin',
                hintStyle: TextStyle(color: _labelColor, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showLocationBottomSheet(Get.context!),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _neonDim,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _neon.withOpacity(0.4)),
              ),
              child: const Icon(Icons.map_outlined, color: _neon, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MapPatternPainter()),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _bg.withOpacity(0.55)],
                ),
              ),
            ),
            // Tıklanabilir — BottomSheet açar
            Center(
              child: GestureDetector(
                onTap: () => _showLocationBottomSheet(Get.context!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _bg.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _neon.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.map_outlined, color: _neon, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Haritada Görüntüle',
                        style: TextStyle(
                          color: _textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Location BottomSheet ─────────────────────────────────────────────────────
  void _showLocationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Color(0xFF162318),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3D2F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: _neon,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Konum Seç',
                    style: TextStyle(
                      color: _textWhite,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1712),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2A3D2F)),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: _labelColor,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1712),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A3D2F)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: _labelColor, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: _textWhite, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Saha adı veya konum ara...',
                          hintStyle: TextStyle(
                            color: _labelColor,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Map area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _MapPatternPainter()),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0F1712).withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                      // Pin
                      const Center(
                        child: Icon(
                          Icons.location_pin,
                          color: _neon,
                          size: 40,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _neon,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _neon.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF0F1712),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Bu Konumu Seç',
                        style: TextStyle(
                          color: Color(0xFF0F1712),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Teams Section ───────────────────────────────────────────────────────────
  Widget _buildTeamsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('KİŞİ SAYISI (MAX)'),
                const SizedBox(height: 8),
                _styledTextField(
                  controller: controller.maxPlayersController,
                  hint: 'Örn: 14',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 12, right: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _neonDim,
                border: Border.all(color: _neon, width: 1.5),
              ),
              child: const Center(
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: _neon,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _fieldLabel('MAÇ ÜCRETİ'),
                ),
                const SizedBox(height: 8),
                _styledTextField(
                  controller: controller.priceController,
                  hint: 'Örn: 150',
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Button ───────────────────────────────────────────────────────────
  Widget _buildBottomButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bg.withOpacity(0), _bg, _bg],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: GestureDetector(
          onTap: () async {
            await controller.createMatch();
          },
          child: Obx(
            () => Container(
              height: 56,
              decoration: BoxDecoration(
                color: _neon,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withOpacity(0.40),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (controller.isLoading.value)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Color(0xFF0F1712),
                        strokeWidth: 2.5,
                      ),
                    )
                  else ...[
                    const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFF0F1712),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Oluştur',
                      style: TextStyle(
                        color: Color(0xFF0F1712),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _labelColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: TextField(
          controller: controller,
          textAlign: textAlign,
          style: const TextStyle(color: _textWhite, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _labelColor, fontSize: 13),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

// ─── Map Pattern Painter ──────────────────────────────────────────────────────
class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF162318);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw a football pitch outline
    final linePaint = Paint()
      ..color = const Color(0xFF2EED7B).withOpacity(0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer boundary
    final outerRect = Rect.fromLTRB(16, 10, size.width - 16, size.height - 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(4)),
      linePaint,
    );

    // Centre line
    canvas.drawLine(Offset(cx, 10), Offset(cx, size.height - 10), linePaint);

    // Centre circle
    canvas.drawCircle(Offset(cx, cy), 24, linePaint);
    canvas.drawCircle(
      Offset(cx, cy),
      2.5,
      Paint()..color = const Color(0xFF2EED7B).withOpacity(0.25),
    );

    // Goal areas
    final goalW = 44.0;
    final goalH = 22.0;
    // Left goal area
    canvas.drawRect(
      Rect.fromLTRB(16, cy - goalH / 2, 16 + goalW, cy + goalH / 2),
      linePaint,
    );
    // Right goal area
    canvas.drawRect(
      Rect.fromLTRB(
        size.width - 16 - goalW,
        cy - goalH / 2,
        size.width - 16,
        cy + goalH / 2,
      ),
      linePaint,
    );

    // Grid dots
    final dotPaint = Paint()..color = const Color(0xFF2EED7B).withOpacity(0.07);
    for (double x = 20; x < size.width; x += 18) {
      for (double y = 14; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
