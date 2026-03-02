import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import 'home_view.dart';
import 'my_matches_view.dart';
import 'discover_view.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// PROFILE VIEW
// ============================================================
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // Dinamik renkler — build() içinde hesaplanır
  late Color _bg;
  late Color _card;

  static const _green = kGreen;

  // Controller — permanent:true olduğu için her zaman aynı örneği döner
  late final ProfileController _ctrl;

  // Radar chart verileri (değişmez, local tutulabilir)
  final Map<String, double> _radarValues = {
    'ŞUT': 0.78,
    'HIZ': 0.65,
    'DEFANS': 0.50,
    'PAS': 0.88,
  };

  @override
  void initState() {
    super.initState();
    // Controller zaten Get.put(permanent:true) ile kaydedilmiş;
    // yoksa burada da oluştur (fallback).
    _ctrl = Get.put(ProfileController(), permanent: true);
  }

  // ── Edit Profile Bottom Sheet ──────────────────────────────
  void _showEditSheet() {
    // Controller'dan güncel verileri al
    final nameCtrl = TextEditingController(text: _ctrl.name.value);
    final posCtrl = TextEditingController(text: _ctrl.position.value);
    File? tempAvatar = _ctrl.avatarFile.value;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = AppColors.isDark(ctx);
          final sheetBg = isDark ? const Color(0xFF16221A) : Colors.white;
          final inputBg = isDark
              ? const Color(0xFF0F1712)
              : const Color(0xFFF0F4F1);
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Avatar + başlık — Row tam genişlik, avatar sol kenara çivilendi
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1) CircleAvatar — sabit 52×52, asla esnemiyor
                      Obx(() {
                        final f = _ctrl.avatarFile.value;
                        return GestureDetector(
                          onTap: _showImagePickerSheet,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: f != null
                                    ? FileImage(f) as ImageProvider
                                    : NetworkImage(_ctrl.avatarUrl.value),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(
                                color: _green.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: _green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.isDark(ctx)
                                        ? const Color(0xFF16221A)
                                        : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: kDarkBg,
                                  size: 10,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      // 2) Boşluk
                      const SizedBox(width: 16),
                      // 3) Başlık — Expanded sayesinde kalan alanı doldurur,
                      //    avatarı asla itmez. maxLines + ellipsis taşmayı önler.
                      Expanded(
                        child: Text(
                          'Profili Düzenle',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.text(ctx),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _editField(
                    'İsim',
                    nameCtrl,
                    Icons.person_outline,
                    ctx,
                    inputBg: inputBg,
                  ),
                  const SizedBox(height: 14),
                  _editField(
                    'Mevki',
                    posCtrl,
                    Icons.sports_soccer,
                    ctx,
                    inputBg: inputBg,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () {
                        // Controller'a kaydet (kalıcı state)
                        _ctrl.updateProfile(
                          newName: nameCtrl.text,
                          newPosition: posCtrl.text,
                          newAvatarFile: tempAvatar,
                        );
                        Get.back();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Kaydet',
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
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _editField(
    String label,
    TextEditingController ctrl,
    IconData icon,
    BuildContext ctx, {
    required Color inputBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.subText(ctx),
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(ctx)),
          ),
          child: TextField(
            controller: ctrl,
            style: TextStyle(color: AppColors.text(ctx), fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.subText(ctx), size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Image Picker via Camera ─────────────────────────────────
  void _showImagePickerSheet() {
    Get.bottomSheet(
      Builder(
        builder: (ctx) {
          final sheetBg = AppColors.isDark(ctx)
              ? const Color(0xFF16221A)
              : Colors.white;
          return Container(
            padding: const EdgeInsets.only(
              top: 24,
              bottom: 32,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Profil Fotoğrafı Seç',
                  style: TextStyle(
                    color: AppColors.text(ctx),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 24),
                _pickerOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Kamera ile Çek',
                  ctx: ctx,
                  onTap: () async {
                    Get.back();
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (picked != null) {
                      _ctrl.updateProfile(
                        newName: _ctrl.name.value,
                        newPosition: _ctrl.position.value,
                        newAvatarFile: File(picked.path),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _pickerOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Galeriden Seç',
                  ctx: ctx,
                  onTap: () async {
                    Get.back();
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      _ctrl.updateProfile(
                        newName: _ctrl.name.value,
                        newPosition: _ctrl.position.value,
                        newAvatarFile: File(picked.path),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _pickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required BuildContext ctx,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.isDark(ctx)
              ? const Color(0xFF0F1712)
              : const Color(0xFFF0F4F1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(ctx)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _green, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: AppColors.text(ctx),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: AppColors.subText(ctx), size: 20),
          ],
        ),
      ),
    );
  }

  // ── Logout Dialog ──────────────────────────────────────────
  void _showLogoutDialog() {
    Get.defaultDialog(
      title: 'Çıkış Yap',
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
      middleText: 'Uygulamadan çıkmak istediğinize emin misiniz?',
      middleTextStyle: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 14,
      ),
      backgroundColor: const Color(0xFF16221A),
      radius: 16,
      barrierDismissible: true,
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'İptal',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      confirm: TextButton(
        onPressed: () {
          Get.back();
          Get.find<AuthController>().logout();
          Get.snackbar(
            'Çıkış',
            'Güvenli şekilde çıkış yapıldı.',
            backgroundColor: const Color(0xFF16221A),
            colorText: Colors.white70,
            borderRadius: 12,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.withOpacity(0.4)),
          ),
          child: const Text(
            'Çıkış',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
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
            children: [
              _buildProfileCard(),
              const SizedBox(height: 16),
              _buildRadarSection(),
              const SizedBox(height: 16),
              _buildStatRow(),
              const SizedBox(height: 20),
              _buildMenuItems(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile Card ───────────────────────────────────────────
  Widget _buildProfileCard() {
    final textColor = AppColors.text(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Stack(
        children: [
          // Obx ile controller'dan veri oku
          Obx(() {
            final f = _ctrl.avatarFile.value;
            return Column(
              children: [
                GestureDetector(
                  onTap: _showImagePickerSheet,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _card,
                          image: DecorationImage(
                            image: f != null
                                ? FileImage(f) as ImageProvider
                                : NetworkImage(_ctrl.avatarUrl.value),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: _green.withOpacity(0.5),
                            width: 3,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg, width: 2),
                          ),
                          child: Icon(Icons.camera_alt, color: _bg, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _ctrl.name.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _ctrl.position.value,
                        style: const TextStyle(
                          color: _green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: _showEditSheet,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.edit_outlined,
                  color: AppColors.subText(context),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Radar Section ──────────────────────────────────────────
  Widget _buildRadarSection() {
    final textColor = AppColors.text(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OYUNCU ÖZELLİKLERİ',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  decoration: TextDecoration.none,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Genel: 84',
                  style: TextStyle(
                    color: _green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(painter: _RadarPainter(values: _radarValues)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Sezon 2023',
                style: TextStyle(
                  color: AppColors.subText(context),
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stat Row ───────────────────────────────────────────────
  Widget _buildStatRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _statBox(
              value: '24',
              label: 'OYNANAN MAÇ',
              valueFontSize: 32,
              valueColor: AppColors.text(context),
              labelColor: AppColors.subText(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2310),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFC107).withOpacity(0.3),
                ),
              ),
              child: const Column(
                children: [
                  Text(
                    '3',
                    style: TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Color(0xFFFFC107), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'MVP',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statBox(
              value: '9.8',
              label: 'FAİR-PLAY',
              valueFontSize: 28,
              valueColor: _green,
              labelColor: AppColors.subText(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required String value,
    required String label,
    required double valueFontSize,
    required Color valueColor,
    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  // ── Menu Items ─────────────────────────────────────────────
  Widget _buildMenuItems() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _menuItem(
            icon: Icons.settings_outlined,
            iconColor: AppColors.subText(context),
            label: 'Ayarlar',
            onTap: () => Get.toNamed(Routes.SETTINGS),
          ),
          const SizedBox(height: 10),
          _menuItem(
            icon: Icons.history_rounded,
            iconColor: AppColors.subText(context),
            label: 'Maç Geçmişi',
            onTap: () => Get.offAll(
              () => const MyMatchesView(),
              transition: Transition.noTransition,
            ),
          ),
          const SizedBox(height: 10),
          _menuItem(
            icon: Icons.logout_rounded,
            iconColor: Colors.redAccent,
            label: 'Çıkış Yap',
            labelColor: Colors.redAccent,
            showArrow: false,
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color? labelColor,
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
    final textColor = labelColor ?? AppColors.text(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
            if (showArrow)
              Icon(
                Icons.chevron_right,
                color: AppColors.subText(context),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────
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
              _navItem(
                Icons.explore_outlined,
                'Keşfet',
                false,
                onTap: () => Get.offAll(
                  () => const DiscoverView(),
                  transition: Transition.noTransition,
                ),
              ),
              _navItem(Icons.person_outline, 'Profil', true, onTap: () {}),
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
// RADAR CHART — CustomPainter
// ============================================================
class _RadarPainter extends CustomPainter {
  final Map<String, double> values;
  const _RadarPainter({required this.values});

  static const _labels = ['ŞUT', 'HIZ', 'DEFANS', 'PAS'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2 * 0.72;
    const sides = 4;
    const angleStep = 2 * math.pi / sides;
    const startAngle = -math.pi / 2;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 4; ring++) {
      final r = maxR * ring / 4;
      final path = Path();
      for (int i = 0; i < sides; i++) {
        final angle = startAngle + i * angleStep;
        final p = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0)
          path.moveTo(p.dx, p.dy);
        else
          path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..strokeWidth = 1;

    for (int i = 0; i < sides; i++) {
      final angle = startAngle + i * angleStep;
      canvas.drawLine(
        center,
        Offset(
          center.dx + maxR * math.cos(angle),
          center.dy + maxR * math.sin(angle),
        ),
        axisPaint,
      );
    }

    final dataPoints = <Offset>[];
    for (int i = 0; i < sides; i++) {
      final label = _labels[i];
      final v = (values[label] ?? 0.5).clamp(0.0, 1.0);
      final angle = startAngle + i * angleStep;
      dataPoints.add(
        Offset(
          center.dx + maxR * v * math.cos(angle),
          center.dy + maxR * v * math.sin(angle),
        ),
      );
    }

    final fillPaint = Paint()
      ..color = kGreen.withOpacity(0.22)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = kGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dataPath = Path();
    for (int i = 0; i < dataPoints.length; i++) {
      if (i == 0)
        dataPath.moveTo(dataPoints[i].dx, dataPoints[i].dy);
      else
        dataPath.lineTo(dataPoints[i].dx, dataPoints[i].dy);
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    final dotPaint = Paint()..color = kGreen;
    for (final p in dataPoints) {
      canvas.drawCircle(p, 5, dotPaint);
    }

    final labelOffset = maxR * 1.22;
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + i * angleStep;
      final lp = Offset(
        center.dx + labelOffset * math.cos(angle),
        center.dy + labelOffset * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lp.dx - tp.width / 2, lp.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.values != values;
}
