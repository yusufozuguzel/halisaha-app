import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// The app's existing image_picker dependency supplies this test seam.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:halisaha_app/core/services/profile_image_picker.dart';

class _Picker extends ImagePickerPlatform {
  PlatformException? failure;
  XFile? result;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    if (failure != null) throw failure!;
    return result;
  }
}

void main() {
  testWidgets('denied/restricted access, cancellation and limited selection', (
    tester,
  ) async {
    final original = ImagePickerPlatform.instance;
    final picker = _Picker();
    ImagePickerPlatform.instance = picker;
    addTearDown(() {
      ImagePickerPlatform.instance = original;
      Get.reset();
    });
    await tester.pumpWidget(GetMaterialApp(home: Scaffold(body: Container())));
    for (final code in [
      'camera_access_denied',
      'photo_access_denied',
      'photo_access_restricted',
    ]) {
      picker.failure = PlatformException(code: code);
      expect(await pickProfileImage(ImageSource.gallery), isNull);
      await tester.pumpAndSettle();
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    }
    picker.failure = null;
    expect(await pickProfileImage(ImageSource.gallery), isNull);
    picker.result = XFile('selected-photo.jpg');
    expect(
      (await pickProfileImage(ImageSource.gallery))?.path,
      'selected-photo.jpg',
    );
  });
}
