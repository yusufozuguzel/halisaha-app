import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsController extends GetxController {
  final _storage = GetStorage();
  final RxBool isDarkMode = true.obs;
  final RxBool isModerator = false.obs;

  @override
  void onInit() {
    super.onInit();
    bool storedTheme = _storage.read('isDarkMode') ?? true;
    isDarkMode.value = storedTheme;
    _loadModeratorRole();
  }

  Future<void> _loadModeratorRole() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(
        true,
      );
      isModerator.value = token?.claims?['moderator'] == true;
    } catch (_) {
      isModerator.value = false;
    }
  }

  void toggleDarkMode(bool value) {
    isDarkMode.value = value;
    _storage.write('isDarkMode', value);
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }
}
