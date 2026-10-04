import 'package:get/get.dart';

class ContentFilterService extends GetxService {
  // A basic list of inappropriate words (profanity, slurs, etc.) in Turkish and English.
  // In a real production app, this list should be fetched dynamically from a backend
  // (like Firebase Remote Config or Firestore) to keep it updated without app releases.
  final List<String> _blacklist = [
    // --- Türkçe (Örnek/Temel) ---
    // Not: Gerçek bir uygulamada daha geniş ve dikkatli bir liste kullanılmalıdır.
    'amk', 'aq', 'amq', 'mk', 'sik', 'sikerim', 'siktir', 'orospu', 'pic', 'piç',
    'yavsak', 'yavşak', 'gavat', 'ibne', 'pezevenk', 'kahpe', 'yarrak', 'yarak',
    'amcik', 'amcık', 'meme', 'göt', 'got', 'am', 'serefsiz', 'şerefsiz',
    // --- English (Basic) ---
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy', 'cunt', 'whore',
    'slut', 'faggot', 'nigger', 'nigga', 'bastard'
  ];

  /// Checks if the given text contains any inappropriate words.
  /// Returns true if inappropriate content is found, false otherwise.
  bool hasProfanity(String text) {
    if (text.isEmpty) return false;
    
    // Convert text to lowercase and remove punctuation to prevent bypassing
    // (e.g., "a.m.k" or "s!kt!r")
    final normalizedText = text.toLowerCase().replaceAll(RegExp(r'[^\w\sğüşiöç]'), '');
    
    // Split into words
    final words = normalizedText.split(RegExp(r'\s+'));
    
    for (final word in words) {
      if (_blacklist.contains(word)) {
        return true;
      }
    }
    
    // Also check for substrings for severe words if needed, 
    // but word-by-word is safer against false positives.
    return false;
  }

  /// Checks multiple text fields. Throws an exception if any is inappropriate.
  void validateTexts(List<String> texts) {
    for (final text in texts) {
      if (hasProfanity(text)) {
        throw const ContentFilterException('Metin uygunsuz kelimeler içeriyor. Lütfen ifadenizi düzeltin.');
      }
    }
  }
}

class ContentFilterException implements Exception {
  final String message;
  const ContentFilterException(this.message);

  @override
  String toString() => message;
}
