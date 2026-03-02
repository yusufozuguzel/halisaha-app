import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ProfileController extends GetxController {
  // Profil verileri — uygulama açık kaldığı sürece hafızada tutulur
  final RxString name = 'Recep Onur Demiray'.obs;
  final RxString position = 'ORTA SAHA'.obs;
  final Rx<File?> avatarFile = Rx<File?>(null);
  final RxString avatarUrl = 'https://picsum.photos/seed/profile1/200/200'.obs;

  // Yükleme durumu
  final RxBool isUploading = false.obs;

  /// Profili güncelle — isim, mevki ve (opsiyonel) avatar dosyasını
  /// sıkıştırıp base64'e çevirip Firestore'a yazar.
  Future<void> updateProfile({
    required String newName,
    required String newPosition,
    File? newAvatarFile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // İsim ve mevki güncelle
    if (newName.trim().isNotEmpty) name.value = newName.trim();
    if (newPosition.trim().isNotEmpty) {
      position.value = newPosition.trim().toUpperCase();
    }

    // Firestore güncellemeleri
    final Map<String, dynamic> updates = {};

    if (newName.trim().isNotEmpty) {
      updates['fullName'] = newName.trim();
      updates['name'] = newName.trim();
    }
    if (newPosition.trim().isNotEmpty) {
      updates['position'] = newPosition.trim().toUpperCase();
    }

    // Avatar dosyası varsa sıkıştır → base64 → Firestore'a yaz
    if (newAvatarFile != null) {
      isUploading.value = true;
      avatarFile.value = newAvatarFile;

      try {
        final String base64Str = await _compressAndEncode(newAvatarFile);
        updates['avatarType'] = 'base64';
        updates['avatarData'] = base64Str;
      } catch (e) {
        // Sıkıştırma başarısız olursa ham dosyayı dene
        try {
          final bytes = await newAvatarFile.readAsBytes();
          updates['avatarType'] = 'base64';
          updates['avatarData'] = base64Encode(bytes);
        } catch (_) {
          // Hata durumunda avatar güncellenmez
        }
      } finally {
        isUploading.value = false;
      }
    }

    // Firestore'a toplu güncelleme
    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  /// Resmi sıkıştırıp base64 string'e çevirir.
  Future<String> _compressAndEncode(File file) async {
    final Uint8List? compressedBytes =
        await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: 300,
          minHeight: 300,
          quality: 70,
          format: CompressFormat.jpeg,
        );

    if (compressedBytes != null && compressedBytes.isNotEmpty) {
      return base64Encode(compressedBytes);
    }

    // Sıkıştırma sonuç döndürmezse orijinal dosyayı kullan
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
}
