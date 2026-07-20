class AppValidators {
  static String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre boş bırakılamaz.';
    }
    if (value.length < 8) {
      return 'Şifre en az 8 karakter olmalıdır.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Şifre en az 1 büyük harf içermelidir.';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Şifre en az 1 özel karakter içermelidir.';
    }
    return null; // Valid
  }
}
