class PlaceCredit {
  const PlaceCredit(this.text, this.url);
  final String text;
  final Uri? url;
}

List<String> _strings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : const [];

bool isGooglePlacesImage(String value) {
  final uri = Uri.tryParse(value);
  return uri?.host == 'maps.googleapis.com' &&
      uri!.path.startsWith('/maps/api/');
}

bool isStaticMapImage(String value) =>
    isGooglePlacesImage(value) && Uri.parse(value).path.endsWith('/staticmap');

/// Retain response-level, place-level and selected-photo attribution separately.
/// This metadata travels with the displayed content; it is never executed as HTML.
Map<String, dynamic> placesAttributionMetadata(
  Map<dynamic, dynamic> place, {
  dynamic responseAttributions,
  bool google = true,
}) {
  final photos = place['photos'];
  final photo = photos is List && photos.isNotEmpty && photos.first is Map
      ? photos.first as Map
      : null;
  return {
    if (google || place['source'] == 'google') 'source': 'google',
    'placeAttributions': {
      ..._strings(responseAttributions),
      ..._strings(place['html_attributions']),
      ..._strings(place['placeAttributions']),
    }.toList(),
    'photoAttributions': photo != null
        ? _strings(photo['html_attributions'])
        : _strings(place['photoAttributions']),
    'photoAttributionsKnown':
        (photo != null && photo.containsKey('html_attributions')) ||
        place['photoAttributionsKnown'] == true ||
        place.containsKey('photoAttributions'),
  };
}

bool hasGooglePlacesContent(Map<String, dynamic> venue) =>
    venue['source'] == 'google' ||
    isGooglePlacesImage((venue['photoUrl'] ?? venue['image'] ?? '').toString());

String attributedVenueImage(Map<String, dynamic> venue) {
  final value = (venue['photoUrl'] ?? venue['image'] ?? '').toString();
  // Old catalog URLs can contain former Google web-service credentials.
  // Never hand them to a renderer, disk cache, browser or network client.
  if (value == 'null' || isGooglePlacesImage(value)) return '';
  return value;
}

String _plain(String html) {
  var text = html.replaceAll(
    RegExp(
      r'<(script|style)\b[^>]*>.*?</\1\s*>',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');
  text = text.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);'), (match) {
    final raw = match[1]!;
    final code = int.tryParse(
      raw.startsWith('x') ? raw.substring(1) : raw,
      radix: raw.startsWith('x') ? 16 : 10,
    );
    return code != null &&
            code > 0 &&
            code <= 0x10ffff &&
            !(code >= 0xd800 && code <= 0xdfff)
        ? String.fromCharCode(code)
        : '';
  });
  for (final entity in {
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
  }.entries) {
    text = text.replaceAll(entity.key, entity.value);
  }
  return text.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
}

Uri? _safeLink(String value) {
  final uri = Uri.tryParse(_plain(value));
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

List<PlaceCredit> parsePlaceCredits(Iterable<String> htmlAttributions) {
  final credits = <PlaceCredit>[];
  final seen = <String>{};
  final anchors = RegExp(
    r'''<a\b[^>]*\bhref\s*=\s*(["'])(.*?)\1[^>]*>(.*?)</a\s*>''',
    caseSensitive: false,
    dotAll: true,
  );
  void add(String raw, [String? href]) {
    final text = _plain(raw);
    if (text.isEmpty) return;
    final url = href == null ? null : _safeLink(href);
    if (seen.add('$text|$url')) credits.add(PlaceCredit(text, url));
  }

  for (final html in htmlAttributions) {
    var end = 0;
    for (final match in anchors.allMatches(html)) {
      add(html.substring(end, match.start));
      add(match[3]!, match[2]);
      end = match.end;
    }
    add(html.substring(end));
  }
  return credits;
}

List<PlaceCredit> venuePlaceCredits(Map<String, dynamic> venue) =>
    parsePlaceCredits({
      ..._strings(venue['placeAttributions']),
      ..._strings(venue['photoAttributions']),
    });
