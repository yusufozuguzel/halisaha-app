import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsController extends GetxController {
  // Başlangıç değeri onInit'te uygulamanın güncel temasından okunur
  final RxBool isDarkMode = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Uygulamanın o anki aktif tema modunu oku ve Switch'i senkronize et
    isDarkMode.value = Get.isDarkMode;
  }

  void toggleDarkMode(bool value) {
    isDarkMode.value = value;
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }
}
