import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import 'home_view.dart';
import 'my_matches_view.dart';
import 'discover_view.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../match/controllers/match_create_controller.dart';
import '../../match/views/match_create_view.dart';

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

  static const _green = Color(0xFF2EED7B);

  // Editable profile state (Yusuf'un Firebase Stream'i ile güncellenecek)
  String _name = '...';
  String _position = '...';

  // Controller — permanent:true olduğu için her zaman aynı örneği döner
  late final ProfileController _ctrl;

  @override
  void initState() {
    super.initState();
    // Her profilView açıldığında controller'ı sıfırla;
    // böylece onInit() her seferinde doğru Get.arguments'ı okur.
    Get.delete<ProfileController>(force: true);
    _ctrl = Get.put(ProfileController());
  }

  // ── Edit Profile Bottom Sheet ──────────────────────────────
  void _showEditSheet() {
    // Hem Firebase'den gelen son veriyi hem de Controller'ı kullan
    final nameCtrl = TextEditingController(text: _name);
    final posCtrl = TextEditingController(text: _position);
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
                        color: AppColors.border(ctx),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Avatar + başlık — Senin tasarımın: Row tam genişlik, avatar sola çakılı
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (_) {
                          // Edit sheet'teki avatar: Firestore stream'inden okunan veriyi kullan
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null)
                            return const SizedBox(width: 52, height: 52);
                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .snapshots(),
                            builder: (ctx2, snap) {
                              Widget innerAvatar;
                              if (snap.hasData) {
                                final d =
                                    snap.data!.data()
                                        as Map<String, dynamic>? ??
                                    {};
                                final aType = d['avatarType'] ?? 'icon';
                                final aData = d['avatarData'] ?? '0';
                                if (aType == 'base64' &&
                                    aData.toString().isNotEmpty) {
                                  try {
                                    innerAvatar = ClipRRect(
                                      borderRadius: BorderRadius.circular(26),
                                      child: Image.memory(
                                        base64Decode(aData),
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.person,
                                          color: AppColors.text(ctx),
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  } catch (_) {
                                    innerAvatar = Icon(
                                      Icons.person,
                                      color: AppColors.text(ctx),
                                      size: 24,
                                    );
                                  }
                                } else {
                                  final iconIdx =
                                      int.tryParse(aData.toString()) ?? 0;
                                  const defaultIcons = [
                                    Icons.person,
                                    Icons.sports_soccer,
                                    Icons.sports_martial_arts,
                                    Icons.face,
                                  ];
                                  innerAvatar = Icon(
                                    defaultIcons[iconIdx % defaultIcons.length],
                                    color: AppColors.text(ctx),
                                    size: 24,
                                  );
                                }
                              } else {
                                innerAvatar = Icon(
                                  Icons.person,
                                  color: AppColors.text(ctx),
                                  size: 24,
                                );
                              }
                              return GestureDetector(
                                onTap: _showImagePickerSheet,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.overlay(ctx),
                                    border: Border.all(
                                      color: _green.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(child: innerAvatar),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: _green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: sheetBg,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: Color(0xFF0F1712),
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      // Başlık — Expanded sayesinde taşmayı önler
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
                      onTap: () async {
                        // Hem GetX Controller'ı hem de yerel state'i güncelle
                        await _ctrl.updateProfile(
                          newName: nameCtrl.text,
                          newPosition: posCtrl.text,
                          newAvatarFile: tempAvatar,
                        );
                        setState(() {
                          _name = nameCtrl.text.trim().isEmpty
                              ? _name
                              : nameCtrl.text.trim();
                          _position = posCtrl.text.trim().isEmpty
                              ? _position
                              : posCtrl.text.trim().toUpperCase();
                        });
                        Get.back();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Kaydet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.bg(ctx),
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
                    color: AppColors.border(ctx),
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
                      await _ctrl.updateProfile(
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
                      await _ctrl.updateProfile(
                        newName: _ctrl.name.value,
                        newPosition: _ctrl.position.value,
                        newAvatarFile: File(picked.path),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _pickerOption(
                  icon: Icons.face_retouching_natural,
                  label: 'Hazır Avatar Seç',
                  ctx: ctx,
                  onTap: () {
                    Get.back(); // Önceki menüyü kapat
                    _showAvatarSelectionSheet(); // Yeni avatar menüsünü aç
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

  // 👇 YENİ METOT: HAZIR AVATAR SEÇİM EKRANI 👇
  void _showAvatarSelectionSheet() {
    final List<IconData> defaultIcons = [
      Icons.person,
      Icons.sports_soccer,
      Icons.sports_martial_arts,
      Icons.face,
    ];

    Get.bottomSheet(
      Builder(
        builder: (ctx) {
          final sheetBg = AppColors.isDark(ctx)
              ? const Color(0xFF16221A)
              : Colors.white;
          return Container(
            padding: const EdgeInsets.only(
              top: 24,
              bottom: 40,
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
                    color: AppColors.border(ctx),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Hazır Avatar Seç',
                  style: TextStyle(
                    color: AppColors.text(ctx),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 24),

                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: List.generate(defaultIcons.length, (index) {
                    return GestureDetector(
                      onTap: () async {
                        Get.back(); // Menüyü kapat
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({
                                'avatarType': 'icon',
                                'avatarData': index.toString(),
                              });
                          Get.snackbar(
                            'Başarılı',
                            'Avatarın güncellendi! 😎',
                            backgroundColor: Colors.green[100],
                            colorText: Colors.green[900],
                          );
                        }
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.overlay(ctx),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2EED7B).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          defaultIcons[index],
                          color: AppColors.text(ctx),
                          size: 36,
                        ),
                      ),
                    );
                  }),
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
            Icon(icon, color: const Color(0xFF2EED7B), size: 24),
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
        onTap: () {
          Get.put(MatchCreateController());
          Get.to(
            () => MatchCreateView(),
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
          child: Icon(
            Icons.add,
            size: 32,
            color: AppColors.isDark(context)
                ? const Color(0xFF0F1712)
                : Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              // Geri butonu — sadece başkasının profili açmışsa göster
              if (!_ctrl.isOwnProfile)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8),
                    child: IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.text(context),
                        size: 22,
                      ),
                      tooltip: 'Geri',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.card(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.border(context)),
                        ),
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(42, 42),
                      ),
                    ),
                  ),
                ),
              _buildProfileCard(),
              const SizedBox(height: 20),
              if (_ctrl.isOwnProfile) _buildMenuItems(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Instagram-style Profile Card ───────────────────────────
  Widget _buildProfileCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_ctrl.targetUid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData
            ? (snapshot.data!.data() as Map<String, dynamic>? ?? {})
            : <String, dynamic>{};

        final fullName = data['fullName'] ?? data['name'] ?? '...';
        final pos = data['position'] ?? '';
        final avatarType = data['avatarType'] ?? 'icon';
        final avatarData = data['avatarData'] ?? '0';

        // Sync local state for bottom sheet
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            setState(() {
              _name = fullName;
              _position = pos;
            });
        });

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row: Avatar + Stats ───────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: _ctrl.isOwnProfile ? _showImagePickerSheet : null,
                    child: Stack(
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _card,
                            border: Border.all(
                              color: _green.withOpacity(0.5),
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(41),
                            child: _buildAvatarWidget(
                              avatarType,
                              avatarData,
                              size: 82,
                            ),
                          ),
                        ),
                        if (_ctrl.isOwnProfile)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _green,
                                shape: BoxShape.circle,
                                border: Border.all(color: _bg, width: 2),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: _bg,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Stats row
                  Expanded(
                    child: Obx(
                      () => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _inlineStatCol(
                            value: _ctrl.matchesCount.value.toString(),
                            label: 'Maç',
                          ),
                          _inlineStatCol(
                            value: _ctrl.followersCount.value.toString(),
                            label: 'Takipçi',
                          ),
                          _inlineStatCol(
                            value: _ctrl.followingCount.value.toString(),
                            label: 'Takip',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Name ─────────────────────────────────────
              Text(
                fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              if (pos.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                // ── Position Badge ────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
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
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pos.toString().toUpperCase(),
                        style: const TextStyle(
                          color: _green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // ── Action Buttons ────────────────────────────
              _buildActionButtons(),

              // ── Own profile: edit pencil inline ──────────
              if (_ctrl.isOwnProfile)
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: _showEditSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            color: AppColors.subText(context),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Düzenle',
                            style: TextStyle(
                              color: AppColors.subText(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Inline stat column (Maç / Takipçi / Takip) ─────────────
  Widget _inlineStatCol({required String value, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: AppColors.subText(context),
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  // ── Action buttons row ─────────────────────────────────────
  Widget _buildActionButtons() {
    // Kendi profilimiz
    if (_ctrl.isOwnProfile) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _showEditSheet,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text(context),
            side: BorderSide(color: AppColors.border(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: const Text(
            'Profili Düzenle',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
    }

    // Başkasının profili
    return Obx(() {
      final following = _ctrl.isFollowing.value;
      final reqSent = _ctrl.isRequestSent.value;
      final loading = _ctrl.isLoading.value;

      // ── Takip Et butonu ─────────────────────────────────
      Widget followBtn;
      if (following) {
        followBtn = OutlinedButton(
          onPressed: loading ? null : _ctrl.unfollow,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text(context),
            side: BorderSide(color: AppColors.border(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: const Text(
            'Takip Ediliyor',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        );
      } else if (reqSent) {
        followBtn = OutlinedButton(
          onPressed: loading ? null : _ctrl.cancelFollowRequest,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.subText(context),
            side: BorderSide(color: AppColors.border(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: const Text(
            'İstek Gönderildi',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        );
      } else {
        followBtn = ElevatedButton(
          onPressed: loading ? null : _ctrl.sendFollowRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: const Color(0xFF0F1712),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: const Text(
            'Takip Et',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        );
      }

      return SizedBox(width: double.infinity, child: followBtn);
    });
  }

  /// Builds the avatar widget from Firestore avatarType/avatarData.
  Widget _buildAvatarWidget(
    String avatarType,
    dynamic avatarData, {
    double size = 82,
  }) {
    final textColor = AppColors.text(context);
    if (avatarType == 'base64' && avatarData.toString().isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(avatarData.toString()),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person, color: textColor, size: size * 0.4),
        );
      } catch (_) {
        return Icon(Icons.person, color: textColor, size: size * 0.4);
      }
    } else {
      final iconIndex = int.tryParse(avatarData.toString()) ?? 0;
      const defaultIcons = [
        Icons.person,
        Icons.sports_soccer,
        Icons.sports_martial_arts,
        Icons.face,
      ];
      return Container(
        width: size,
        height: size,
        color: AppColors.overlay(context),
        child: Icon(
          defaultIcons[iconIndex % defaultIcons.length],
          color: textColor,
          size: size * 0.4,
        ),
      );
    }
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
              () => MyMatchesView(),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
                  () => MyMatchesView(),
                  transition: Transition.noTransition,
                ),
              ),
              const SizedBox(width: 48),
              _navItem(
                Icons.explore_outlined,
                'Keşfet',
                false,
                onTap: () => Get.offAll(
                  () => DiscoverView(),
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
