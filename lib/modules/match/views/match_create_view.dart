import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/match_create_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/venue_map_widget.dart';

class MatchCreateView extends GetView<MatchCreateController> {
  const MatchCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildProgressStepper(context),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  Icons.info_outline,
                  'GENEL BİLGİLER',
                  context,
                ),
                const SizedBox(height: 16),
                _buildGeneralInfoSection(context),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  Icons.calendar_month_outlined,
                  'ZAMAN VE KONUM',
                  context,
                ),
                const SizedBox(height: 16),
                _buildTimeLocationSection(context),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  Icons.shield_outlined,
                  'TAKIM İSİMLERİ',
                  context,
                ),
                const SizedBox(height: 16),
                _buildTeamNamesSection(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildBottomButton(context),
        ],
      ),
    );
  }

  // ─── AppBar ─────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bg(context),
      elevation: 0,
      centerTitle: true,
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: const Icon(
            Icons.chevron_left,
            color: Color(0xFF2EED7B),
            size: 22,
          ),
        ),
      ),
      title: Obx(
        () => Text(
          controller.isEditing.value ? 'Maçı Düzenle' : 'Yeni Maç Oluştur',
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ─── Progress Stepper ───────────────────────────────────────────────────────
  Widget _buildProgressStepper(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _stepCircle(1, 'DETAYLAR', true, context),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF2EED7B), AppColors.border(context)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _stepCircle(2, 'DAVET', false, context),
        ],
      ),
    );
  }

  Widget _stepCircle(
    int number,
    String label,
    bool isActive,
    BuildContext context,
  ) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF2EED7B) : AppColors.card(context),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF2EED7B)
                  : AppColors.border(context),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(
                color: isActive
                    ? AppColors.bg(context)
                    : AppColors.subText(context),
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
            color: isActive
                ? const Color(0xFF2EED7B)
                : AppColors.subText(context),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ─── Section Header ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader(
    IconData icon,
    String title,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2EED7B), size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2EED7B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Team Names Section ──────────────────────────────────────────────────────
  Widget _buildTeamNamesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 1. Takım ──────────────────────────────────────
          Expanded(
            child: _styledTextField(
              controller: controller.teamAController,
              hint: '1. Takım Adı',
              context: context,
            ),
          ),
          // ── VS Badge ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.overlay(context),
                border: Border.all(color: const Color(0xFF2EED7B), width: 1.5),
              ),
              child: const Center(
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Color(0xFF2EED7B),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          // ── 2. Takım ──────────────────────────────────────
          Expanded(
            child: _styledTextField(
              controller: controller.teamBController,
              hint: '2. Takım Adı',
              context: context,
              textAlign: TextAlign.right,
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
          _fieldLabel('Maç Adı', context),
          const SizedBox(height: 8),
          _styledTextField(
            controller: controller.titleController,
            hint: 'Örn: Cuma Akşamı Derbisi',
            context: context,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // ── Maç Formatı Dropdown ──────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Maç Formatı', context),
                    const SizedBox(height: 8),
                    Obx(() {
                      const formats = [
                        '5x5',
                        '6x6',
                        '7x7',
                        '8x8',
                        '9x9',
                        '10x10',
                        '11x11',
                      ];
                      return Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.isDark(context)
                                ? AppColors.border(context)
                                : Colors.black12,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.selectedFormat.value,
                            menuMaxHeight: 300,
                            dropdownColor: AppColors.isDark(context)
                                ? const Color(0xFF16221A)
                                : Colors.white,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.subText(context),
                              size: 20,
                            ),
                            isExpanded: true,
                            style: TextStyle(
                              color: AppColors.text(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            items: formats
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.people_outline,
                                          color: Color(0xFF2EED7B),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(f),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                controller.selectedFormat.value = val;
                              }
                            },
                          ),
                        ),
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
                    _fieldLabel('Maç Ücreti', context),
                    const SizedBox(height: 8),
                    _styledTextField(
                      controller: controller.priceController,
                      hint: 'Örn: 1500',
                      context: context,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
          // 🔥 1. SATIR: TARİH (Tek parça geniş)
          _fieldLabel('Tarih', context),
          const SizedBox(height: 8),
          Obx(() {
            final date = controller.selectedDate.value;
            final label = date != null
                ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                : 'Maç Tarihini Seçin';
            return _pickerButton(
              icon: Icons.calendar_today_outlined,
              label: label,
              onTap: () => controller.pickDate(context),
              isSet: date != null,
              context: context,
            );
          }),
          const SizedBox(height: 16),

          // 🔥 2. SATIR: BAŞLANGIÇ VE BİTİŞ SAATLERİ YAN YANA
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Başlama Saati', context),
                    const SizedBox(height: 8),
                    Obx(() {
                      final time = controller.selectedStartTime.value;
                      final label = time != null
                          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                          : '--:--';
                      return _pickerButton(
                        icon: Icons.access_time_rounded,
                        label: label,
                        onTap: () =>
                            controller.pickTime(context, isStart: true),
                        isSet: time != null,
                        context: context,
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
                    _fieldLabel('Bitiş Saati', context),
                    const SizedBox(height: 8),
                    Obx(() {
                      final time = controller.selectedEndTime.value;
                      final label = time != null
                          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                          : '--:--';
                      return _pickerButton(
                        icon: Icons.watch_later_outlined,
                        label: label,
                        onTap: () =>
                            controller.pickTime(context, isStart: false),
                        isSet: time != null,
                        context: context,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _fieldLabel('Saha Adı / Konum', context),
          const SizedBox(height: 8),

          // 1. Arama Kutusu (Tekil)
          _locationField(context),

          // 2. Otomatik Tamamlama Listesi (Autocomplete)
          Obx(() {
            if (controller.searchQuery.value.isEmpty ||
                controller.selectedLat.value != null) {
              return const SizedBox.shrink();
            }

            final results = controller.filteredLocations;
            if (results.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2EED7B).withOpacity(0.3),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final loc = results[index];
                  return InkWell(
                    onTap: () {
                      controller.setLocation(
                        loc['name'],
                        loc['lat'],
                        loc['lng'],
                        source: loc['source'],
                        id: loc['id'],
                        address: loc['address'],
                      );
                      FocusScope.of(context).unfocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: loc['source'] == 'google'
                                ? Colors.blueAccent
                                : const Color(0xFF2EED7B),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc['name'],
                                  style: TextStyle(
                                    color: AppColors.text(context),
                                    fontSize: 13,
                                  ),
                                ),
                                if (loc['source'] == 'google' &&
                                    loc['address'] != null)
                                  Text(
                                    loc['address'],
                                    style: TextStyle(
                                      color: AppColors.subText(context),
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          const SizedBox(height: 14),

          // 3. Haritada Görüntüle Butonu
          _mapPlaceholder(context),
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
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSet
                ? const Color(0xFF2EED7B)
                : (AppColors.isDark(context)
                      ? AppColors.border(context)
                      : Colors.black12),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSet
                  ? const Color(0xFF2EED7B)
                  : AppColors.subText(context),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSet
                      ? AppColors.text(context)
                      : AppColors.subText(context),
                  fontSize: 14,
                ),
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: AppColors.subText(context), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _locationField(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.isDark(context)
              ? AppColors.border(context)
              : Colors.grey.shade300,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: Color(0xFF2EED7B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: controller.onVenueSearchChanged,
              controller: controller.venueController,
              style: TextStyle(color: AppColors.text(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Halı saha adını girin veya seçin',
                hintStyle: TextStyle(
                  color: AppColors.subText(context),
                  fontSize: 13,
                ),
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
                color: AppColors.overlay(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF2EED7B).withOpacity(0.4),
                ),
              ),
              child: const Icon(
                Icons.map_outlined,
                color: Color(0xFF2EED7B),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPlaceholder(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.isDark(context)
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _MapPatternPainter(
                cardColor: AppColors.isDark(context)
                    ? AppColors.card(context)
                    : Colors.white,
                isDark: AppColors.isDark(context),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.bg(context).withOpacity(0.55),
                  ],
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: () {
                  debugPrint('DEBUG MAÇ: Seçilen Saha Lat: ${controller.selectedLat.value}');
                  debugPrint('DEBUG MAÇ: Seçilen Saha Lng: ${controller.selectedLng.value}');
                  
                  if (controller.selectedLat.value == null || controller.selectedLng.value == null) {
                    Get.snackbar(
                      'Uyarı',
                      'Lütfen önce bir saha seçin',
                      backgroundColor: Colors.amber.shade700,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    );
                    return;
                  }

                  Get.bottomSheet(
                    Container(
                      height: Get.height,
                      decoration: BoxDecoration(
                        color: AppColors.bg(context),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SafeArea(
                        child: Column(
                          children: [
                            Container(
                              height: 5,
                              width: 40,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.border(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Saha Konumu',
                                    style: TextStyle(
                                      color: AppColors.text(context),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: AppColors.text(context)),
                                    onPressed: () => Get.back(),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Obx(() {
                                final lat = controller.selectedLat.value;
                                final lng = controller.selectedLng.value;
                                
                                if (lat == null || lng == null) {
                                  return const SizedBox.shrink();
                                }
                                
                                return VenueMapWidget(
                                  venues: [{
                                    'id': controller.selectedVenueId.value,
                                    'name': controller.venueController.text.isNotEmpty ? controller.venueController.text : 'Seçilen Saha',
                                    'lat': lat,
                                    'lng': lng,
                                  }],
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    isScrollControlled: true,
                    enableDrag: false,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg(context).withOpacity(0.82),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF2EED7B).withOpacity(0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        color: Color(0xFF2EED7B),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Haritada Görüntüle',
                        style: TextStyle(
                          color: AppColors.text(context),
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
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: AppColors.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF2EED7B),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Konum Seç',
                      style: TextStyle(
                        color: AppColors.text(context),
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
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.isDark(context)
                                ? AppColors.border(context)
                                : Colors.black12,
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          Icons.close,
                          color: AppColors.subText(context),
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
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.isDark(context)
                          ? AppColors.border(context)
                          : Colors.black12,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: AppColors.subText(context),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onChanged: controller.onVenueSearchChanged,
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Saha adı veya konum ara...',
                            hintStyle: TextStyle(
                              color: AppColors.subText(context),
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
              const SizedBox(height: 12),

              // 📍 Yakınımdaki Sahaları Bul
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: controller.isLocationLoading.value
                          ? null
                          : () => controller.sortByDistance(),
                      icon: controller.isLocationLoading.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF2EED7B),
                              ),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(
                        controller.isLocationLoading.value
                            ? 'Konum alınıyor...'
                            : 'Yakınımdaki Sahaları Bul',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.isDark(context)
                            ? const Color(0xFF1A2E1F)
                            : const Color(0xFFE8F9ED),
                        foregroundColor: const Color(0xFF2EED7B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: const Color(0xFF2EED7B).withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🔥 YENİ VE DÜZELTİLMİŞ: SAHALAR LİSTESİ 🔥
              Expanded(
                child: Obx(() {
                  final currentLat = controller.selectedLat.value;
                  final currentLng = controller.selectedLng.value;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: controller.filteredLocations.length,
                    itemBuilder: (context, index) {
                      final loc = controller.filteredLocations[index];
                      final isSelected =
                          currentLat == loc['lat'] && currentLng == loc['lng'];

                      return GestureDetector(
                        onTap: () async {
                          await controller.setLocation(
                            loc['name'],
                            loc['lat'],
                            loc['lng'],
                            source: loc['source'],
                            id: loc['id'],
                            address: loc['address'],
                            photoUrl: loc['photoUrl'],
                          );
                          Get.back(); // Seçim sonrası pencereyi kapat
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2EED7B)
                                  : AppColors.border(context),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2EED7B).withOpacity(0.2)
                                      : AppColors.overlay(context),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  loc['source'] == 'google'
                                      ? Icons.public
                                      : Icons.location_on,
                                  color: isSelected
                                      ? const Color(0xFF2EED7B)
                                      : (loc['source'] == 'google'
                                            ? Colors.blueAccent
                                            : AppColors.subText(context)),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc['name'],
                                      style: TextStyle(
                                        color: AppColors.text(context),
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    if (loc['source'] == 'google' &&
                                        loc['address'] != null)
                                      Text(
                                        loc['address'],
                                        style: TextStyle(
                                          color: AppColors.subText(context),
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (loc['distanceInMeters'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '📍 ${((loc['distanceInMeters'] as double) / 1000).toStringAsFixed(1)} km',
                                          style: const TextStyle(
                                            color: Color(0xFF2EED7B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF2EED7B),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),

              // Confirm button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2EED7B),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2EED7B).withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: AppColors.bg(context),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bu Konumu Seç',
                          style: TextStyle(
                            color: AppColors.bg(context),
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
      ),
    );
  }

  // ─── Bottom Button ───────────────────────────────────────────────────────────
  Widget _buildBottomButton(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bg(context).withOpacity(0),
              AppColors.bg(context),
              AppColors.bg(context),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: GestureDetector(
          onTap: () async {
            await controller.createAndShareMatch();
          },
          child: Obx(
            () => Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2EED7B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2EED7B).withOpacity(0.40),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (controller.isLoading.value)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.bg(context),
                        strokeWidth: 2.5,
                      ),
                    )
                  else ...[
                    Icon(
                      controller.isEditing.value
                          ? Icons.edit_note_rounded
                          : Icons.rocket_launch_rounded,
                      color: AppColors.bg(context),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      controller.isEditing.value ? 'Güncelle' : 'Oluştur',
                      style: TextStyle(
                        color: AppColors.bg(context),
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
  Widget _fieldLabel(String text, BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.subText(context),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    required BuildContext context,
    TextAlign textAlign = TextAlign.start,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.isDark(context)
              ? AppColors.border(context)
              : Colors.black12,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: TextField(
          controller: controller,
          textAlign: textAlign,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(color: AppColors.text(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.subText(context),
              fontSize: 13,
            ),
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
  final Color cardColor;
  final bool isDark;

  _MapPatternPainter({required this.cardColor, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? cardColor : Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF2EED7B).withOpacity(isDark ? 0.18 : 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final outerRect = Rect.fromLTRB(16, 10, size.width - 16, size.height - 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(4)),
      linePaint,
    );

    canvas.drawLine(Offset(cx, 10), Offset(cx, size.height - 10), linePaint);
    canvas.drawCircle(Offset(cx, cy), 24, linePaint);
    canvas.drawCircle(
      Offset(cx, cy),
      2.5,
      Paint()..color = const Color(0xFF2EED7B).withOpacity(isDark ? 0.25 : 0.8),
    );

    final goalW = 44.0;
    final goalH = 22.0;
    canvas.drawRect(
      Rect.fromLTRB(16, cy - goalH / 2, 16 + goalW, cy + goalH / 2),
      linePaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        size.width - 16 - goalW,
        cy - goalH / 2,
        size.width - 16,
        cy + goalH / 2,
      ),
      linePaint,
    );

    final dotPaint = Paint()
      ..color = const Color(0xFF2EED7B).withOpacity(isDark ? 0.07 : 0.5);
    for (double x = 20; x < size.width; x += 18) {
      for (double y = 14; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
