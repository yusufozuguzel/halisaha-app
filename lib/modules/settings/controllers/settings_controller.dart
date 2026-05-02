import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SettingsController extends GetxController {
  final _storage = GetStorage();
  final RxBool isDarkMode = true.obs;

  @override
  void onInit() {
    super.onInit();
    bool storedTheme = _storage.read('isDarkMode') ?? true;
    isDarkMode.value = storedTheme;
  }

  void toggleDarkMode(bool value) {
    isDarkMode.value = value;
    _storage.write('isDarkMode', value);
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }
}
