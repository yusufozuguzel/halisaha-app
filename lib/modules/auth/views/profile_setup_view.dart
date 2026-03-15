import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/profile_setup_controller.dart';

class ProfileSetupView extends GetView<ProfileSetupController> {
  const ProfileSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1712),
      appBar: AppBar(
        title: const Text(
          "Profilini Tamamla",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                "Seni daha yakından tanıyalım ⚽",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Profilini doldurarak takımlara katılma şansını artır.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                "Avatar Seçimi",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              _buildAvatarSection(),

              const SizedBox(height: 32),
              const Text(
                "Ad Soyad",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _CustomTextField(
                controller: controller.fullNameController,
                hintText: "Ahmet Yılmaz",
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 20),

              const Text(
                "Mevki",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.positions
                    .map((pos) => _buildPositionChip(pos))
                    .toList(),
              ),

              const SizedBox(height: 20),
              const Text(
                "Kullandığı Ayak",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildFootDropdown(),

              const SizedBox(height: 20),
              const Text(
                "Şehir",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _CustomTextField(
                controller: controller.cityController,
                hintText: "İstanbul",
                prefixIcon: Icons.location_city_outlined,
              ),

              const SizedBox(height: 40),
              Obx(
                () => ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.saveProfile(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EED7B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: const Color(
                      0xFF2EED7B,
                    ).withOpacity(0.5),
                  ),
                  child: controller.isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Kaydet ve Başla",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        SizedBox(
          height: 80,
          child: Obx(
            () => ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount:
                  controller.defaultIcons.length +
                  (controller.avatarUrl.value.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (controller.avatarUrl.value.isNotEmpty && index == 0) {
                  // The Custom Avatar is selected and sits at front
                  return _buildCustomAvatarCard();
                }

                return Obx(() {
                  // Offset for icons list if custom avatar is present
                  final int iconIndex =
                      controller.avatarUrl.value.isNotEmpty
                      ? index - 1
                      : index;

                  final isSelected =
                      controller.avatarUrl.value.isEmpty &&
                      controller.selectedIconIndex.value == iconIndex;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => controller.selectIcon(iconIndex),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16221A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2EED7B)
                                : Colors.white.withOpacity(0.06),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          controller.defaultIcons[iconIndex],
                          color: isSelected
                              ? const Color(0xFF2EED7B)
                              : Colors.white.withOpacity(0.4),
                          size: 32,
                        ),
                      ),
                    ),
                  );
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => controller.pickImageFromGallery(),
          icon: const Icon(
            Icons.photo_library_outlined,
            color: Color(0xFF2EED7B),
            size: 18,
          ),
          label: const Text(
            "Veya Galeriden Seç",
            style: TextStyle(
              color: Color(0xFF2EED7B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: const Color(0xFF2EED7B).withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomAvatarCard() {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16221A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2EED7B), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: controller.avatarUrl.value,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
    );
  }

  Widget _buildPositionChip(String pos) {
    return Obx(() {
      final isSelected = controller.selectedPosition.value == pos;
      return GestureDetector(
        onTap: () => controller.selectedPosition.value = pos,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2EED7B).withOpacity(0.1)
                : const Color(0xFF16221A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2EED7B)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Text(
            pos,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF2EED7B)
                  : Colors.white.withOpacity(0.7),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildFootDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Obx(
        () => DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: controller.selectedFoot.value,
            dropdownColor: const Color(0xFF16221A),
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white.withOpacity(0.4),
            ),
            isExpanded: true,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            items: controller.feet.map((String foot) {
              return DropdownMenuItem<String>(value: foot, child: Text(foot));
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                controller.selectedFoot.value = newValue;
              }
            },
          ),
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;

  const _CustomTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(prefixIcon, color: Colors.white.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2EED7B)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
