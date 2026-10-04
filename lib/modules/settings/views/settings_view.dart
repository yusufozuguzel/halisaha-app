import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../../moderation/views/moderation_view.dart';
import '../../../widgets/support_contact.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../widgets/delete_account_sheet.dart';


class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  static const _green = Color(0xFF2EED7B);

  @override
  Widget build(BuildContext context) {
    // Temanın brightness'ına göre renk hesaplamaları
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1712) : Colors.white;
    final cardColor = isDark
        ? const Color(0xFF16221A)
        : const Color(0xFFF5F5F5);
    final appBarBg = isDark ? const Color(0xFF16221A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.08);

    return Obx(() {
      final darkMode = controller.isDarkMode.value;

      return Scaffold(
        backgroundColor: bgColor,

        // ── AppBar ──────────────────────────────────────────
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: BoxDecoration(
              color: appBarBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // Geri Butonu
                    InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: textColor,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Ayarlar',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Body ─────────────────────────────────────────────
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Destek ve İtiraz'),
              subtitle: const Text(SupportContact.email),
              onTap: () => SupportContact.show(context),
            ),
            if (controller.isModerator.value)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Şikayetleri İncele'),
                onTap: () => Get.to(() => const ModerationView()),
              ),
            // Bölüm Başlığı
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'GÖRÜNÜM',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // ── Karanlık / Aydınlık Mod Tile ────────────────
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                // İkon Kutusu
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: darkMode
                        ? _green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    darkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: darkMode ? _green : Colors.orange,
                    size: 20,
                  ),
                ),
                // Başlık: Switch açıksa "Karanlık Mod", kapalıysa "Aydınlık Mod"
                title: Text(
                  darkMode ? 'Karanlık Mod' : 'Aydınlık Mod',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Alt başlık: Açık / Kapalı durumu
                subtitle: Text(
                  darkMode ? 'Açık' : 'Kapalı',
                  style: TextStyle(
                    color: darkMode ? _green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Switch
                trailing: Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: darkMode,
                    onChanged: controller.toggleDarkMode,
                    activeThumbColor: _green,
                    activeTrackColor: _green.withValues(alpha: 0.25),
                    inactiveThumbColor: Colors.orange,
                    inactiveTrackColor: Colors.orange.withValues(alpha: 0.15),
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () => controller.toggleDarkMode(!darkMode),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Gizlilik Politikası ve Koşullar'),
              onTap: () async {
                final url = Uri.parse('https://yusufozuguzel.github.io/depar-web/gizlilik.html');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text('Çıkış Yap', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Get.dialog(
                  AlertDialog(
                    title: const Text('Çıkış Yap'),
                    content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: const Text('İptal')),
                      TextButton(
                        onPressed: () {
                          Get.back();
                          Get.find<AuthController>().logout();
                        },
                        child: const Text('Çıkış Yap', style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Hesabı Sil', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                try {
                  final requiresPwd = controller.deletionRequiresPassword;
                  Get.bottomSheet(
                    DeleteAccountSheet(
                      requiresPassword: requiresPwd,
                      onDelete: controller.deleteUserAccount,
                    ),
                    backgroundColor: isDark ? const Color(0xFF16221A) : Colors.white,
                    isScrollControlled: true,
                  );
                } catch (_) {
                  Get.snackbar('Hata', 'İşlem gerçekleştirilemedi.');
                }
              },
            ),
          ],
        ),
      );
    });
  }
}
