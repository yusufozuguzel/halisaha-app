import 'package:cloud_firestore/cloud_firestore.dart';

/// User-facing validation; Firestore independently enforces these bounds.
class MatchMetadata {
  static List<String> formations(int capacity) => switch (capacity) {
    10 => ['1-2-1', '2-1-1', '1-1-2'],
    12 => ['2-2-1', '1-3-1', '2-1-2'],
    14 => ['2-3-1', '3-2-1', '2-2-2'],
    16 => ['3-3-1', '2-4-1', '3-2-2'],
    18 => ['3-4-1', '4-3-1', '3-3-2'],
    20 => ['4-4-1', '3-5-1', '4-3-2'],
    22 => ['4-4-2', '4-3-3', '3-5-2'],
    _ => [],
  };

  static String? error(Map<String, dynamic> data) {
    final title = data['title'];
    if (title is! String || title.trim().isEmpty || title.length > 120) {
      return 'Maç başlığı 1–120 karakter olmalıdır.';
    }
    for (final entry in {
      'venue': 200,
      'venueId': 256,
      'teamA_name': 60,
      'teamB_name': 60,
      'venuePhotoUrl': 2048,
    }.entries) {
      final value = data.containsKey(entry.key) ? data[entry.key] : '';
      if (value is! String || value.length > entry.value) {
        return 'Saha adı en fazla 200, takım adları en fazla 60 karakter olabilir. Saha bilgilerini kontrol edin.';
      }
    }
    if ((data['venueId'] as String? ?? '').contains('/')) {
      return 'Saha bilgilerini yeniden seçin.';
    }
    final photo = data['venuePhotoUrl'] as String? ?? '';
    if (photo.isNotEmpty && !photo.startsWith('https://')) {
      return 'Geçersiz saha fotoğrafı bağlantısı.';
    }
    final price = data.containsKey('price') ? data['price'] : 0;
    if (price is! num || !price.isFinite || price < 0 || price > 1000000) {
      return 'Ücret 0–1.000.000 arasında geçerli bir sayı olmalıdır.';
    }
    final lat = data['latitude'], lng = data['longitude'];
    if (!(lat == null && lng == null) &&
        !(lat is num &&
            lng is num &&
            lat.isFinite &&
            lng.isFinite &&
            lat >= -90 &&
            lat <= 90 &&
            lng >= -180 &&
            lng <= 180)) {
      return 'Saha konumunu yeniden seçin.';
    }
    final capacity = data['maxPlayers'];
    if (capacity is! int || formations(capacity).isEmpty) {
      return 'Maç biçimi 5x5–11x11 arasında olmalıdır.';
    }
    final formation = data.containsKey('formation') ? data['formation'] : '';
    if (formation != '' && !formations(capacity).contains(formation)) {
      return 'Diziliş maç biçimine uygun değil.';
    }
    final start = data['date'];
    if (start is! Timestamp) return 'Geçerli bir maç tarihi seçin.';
    final end = data.containsKey('endDate')
        ? data['endDate']
        : Timestamp.fromDate(start.toDate().add(const Duration(hours: 1)));
    if (end is! Timestamp) return 'Geçerli bir bitiş saati seçin.';
    final duration = end.toDate().difference(start.toDate());
    if (duration < const Duration(minutes: 30) ||
        duration > const Duration(hours: 24)) {
      return 'Maç süresi 30 dakika ile 24 saat arasında olmalıdır.';
    }
    if (!{'open', 'closed'}.contains(data['status']))
      return 'Geçersiz maç durumu.';
    return null;
  }
}
