import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'authenticated_callable.dart';
import 'places_attribution.dart';

class PlacesUnavailable implements Exception {
  const PlacesUnavailable();
  String get message =>
      'Saha arama hizmeti \u015fu anda kullan\u0131lam\u0131yor. Kay\u0131tl\u0131 sahalar\u0131 se\u00e7ebilirsiniz.';
}

/// Per-session, bounded in-memory image transport. No Google key, URL or image
/// bytes are persisted to Firestore, preferences or disk cache.
class PlacesProxy {
  PlacesProxy({AuthenticatedCallable? call, String? Function()? currentUid})
    : _call = call ?? authenticatedCallable,
      _currentUid =
          currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final AuthenticatedCallable _call;
  final String? Function() _currentUid;
  final _images = LinkedHashMap<String, Uint8List>();
  int _cachedBytes = 0;
  String? _owner;
  bool? _enabled;
  DateTime? _checkedAt;
  static const maxImageBytes = 2 * 1024 * 1024;
  static const maxCacheBytes = 10 * 1024 * 1024;
  static const maxCacheEntries = 16;

  Future<bool>? _capabilityFuture;
  Future<bool> _capability(String owner) {
    if (_checkedAt != null &&
        DateTime.now().difference(_checkedAt!).inSeconds < 60) {
      return Future.value(_enabled == true);
    }
    if (_capabilityFuture != null) return _capabilityFuture!;
    late Future<bool> pending;
    pending = (() async {
      try {
        final status = await _call('safetyStatus', {});
        if (_currentUid() != owner || _owner != owner) return false;
        _enabled = status['placesProxyEnabled'] == true;
      } catch (_) {
        if (_owner == owner) _enabled = false;
      } finally {
        if (_owner == owner) _checkedAt = DateTime.now();
        if (identical(_capabilityFuture, pending)) _capabilityFuture = null;
      }
      return _owner == owner && _enabled == true;
    })();
    _capabilityFuture = pending;
    return pending;
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> data) async {
    final owner = _currentUid();
    if (owner == null) throw const PlacesUnavailable();
    if (_owner != owner) {
      _images.clear();
      _cachedBytes = 0;
      _owner = owner;
      _enabled = null;
      _checkedAt = null;
      _capabilityFuture = null;
    }
    if (!await _capability(owner) || _currentUid() != owner)
      throw const PlacesUnavailable();
    try {
      final response = await _call('placesProxy', data);
      if (_currentUid() != owner) throw const PlacesUnavailable();
      return response;
    } catch (_) {
      // An invalid place/photo does not turn off unrelated searches.
      throw const PlacesUnavailable();
    }
  }

  Future<Map<String, dynamic>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) => _request({
    'operation': 'search',
    'query': query,
    if (latitude != null && longitude != null) 'latitude': latitude,
    if (latitude != null && longitude != null) 'longitude': longitude,
  });

  Future<Map<String, dynamic>> details(String placeId) =>
      _request({'operation': 'details', 'placeId': placeId});

  static Uint8List decodeImage(Map<String, dynamic> response) {
    final raw = response['imageBase64'];
    final mime = response['mimeType'];
    if (raw is! String ||
        raw.length > (maxImageBytes * 4 ~/ 3) + 8 ||
        !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime))
      throw const PlacesUnavailable();
    try {
      final bytes = base64Decode(raw);
      if (bytes.isEmpty || bytes.length > maxImageBytes)
        throw const PlacesUnavailable();
      bool prefix(List<int> values) =>
          bytes.length >= values.length &&
          List.generate(
            values.length,
            (i) => bytes[i] == values[i],
          ).every((value) => value);
      final valid = mime == 'image/jpeg'
          ? prefix([255, 216, 255])
          : mime == 'image/png'
          ? prefix([137, 80, 78, 71, 13, 10, 26, 10])
          : prefix([82, 73, 70, 70]) &&
                bytes.length >= 12 &&
                bytes[8] == 87 &&
                bytes[9] == 69 &&
                bytes[10] == 66 &&
                bytes[11] == 80;
      if (!valid) throw const PlacesUnavailable();
      return bytes;
    } catch (_) {
      throw const PlacesUnavailable();
    }
  }

  Future<Uint8List> _image(Map<String, dynamic> data) async {
    final key = '${_currentUid()}:${jsonEncode(data)}';
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached;
      return cached;
    }
    final bytes = decodeImage(await _request(data));
    while (_images.isNotEmpty &&
        (_images.length >= maxCacheEntries ||
            _cachedBytes + bytes.length > maxCacheBytes)) {
      _cachedBytes -= _images.remove(_images.keys.first)!.length;
    }
    _images[key] = bytes;
    _cachedBytes += bytes.length;
    return bytes;
  }

  Map<String, dynamic> safeCatalogVenue(Map<String, dynamic> venue) {
    final output = Map<String, dynamic>.from(venue)
      ..remove('photoBytes')
      ..remove('imageBase64');
    if (isGooglePlacesImage(
      (output['photoUrl'] ?? output['image'] ?? '').toString(),
    )) {
      output['source'] = 'google';
      output['photoUrl'] = '';
      output.remove('image');
    }
    return output;
  }

  Future<List<Map<String, dynamic>>> decorateVisible(
    List<Map<String, dynamic>> venues, {
    int limit = 10,
  }) async {
    final output = venues.map(safeCatalogVenue).toList();
    var retained = 0;
    final count = venues.length < limit ? venues.length : limit;
    for (var start = 0; start < count; start += 2) {
      final end = start + 2 < count ? start + 2 : count;
      final batch = await Future.wait(venues.sublist(start, end).map(decorate));
      for (var index = 0; index < batch.length; index++) {
        final enriched = batch[index];
        final bytes = enriched['photoBytes'];
        if (bytes is Uint8List && retained + bytes.length > maxCacheBytes) {
          enriched.remove('photoBytes');
        } else if (bytes is Uint8List) {
          retained += bytes.length;
        }
        output[start + index] = enriched;
      }
    }
    return output;
  }

  Future<Map<String, dynamic>> decorate(
    Map<String, dynamic> venue, {
    dynamic responseAttributions,
  }) async {
    final output = <String, dynamic>{...venue};
    final oldUrl = (venue['photoUrl'] ?? venue['image'] ?? '').toString();
    if (isGooglePlacesImage(oldUrl)) {
      output['source'] = 'google';
      output['photoUrl'] = '';
      output.remove('image');
    }
    if (oldUrl.isNotEmpty && oldUrl != 'null' && !isGooglePlacesImage(oldUrl))
      return output;
    var source = Map<String, dynamic>.from(venue);
    var photos = source['photos'];
    if (photos is! List ||
        photos.isEmpty ||
        photos.first is! Map ||
        !(photos.first as Map).containsKey('html_attributions')) {
      final id =
          (source['place_id'] ??
                  source['placeId'] ??
                  (source['source'] == 'google' ? source['id'] : null))
              ?.toString();
      if (id != null && id.isNotEmpty) {
        try {
          final fetched = await details(id);
          if (fetched['result'] is Map) {
            source.addAll(Map<String, dynamic>.from(fetched['result'] as Map));
            responseAttributions = fetched['html_attributions'];
            photos = source['photos'];
          }
        } on PlacesUnavailable {
          return output;
        }
      }
    }
    output.addAll(
      placesAttributionMetadata(
        source,
        responseAttributions: responseAttributions,
        google:
            source['source'] == 'google' ||
            source['place_id'] != null ||
            isGooglePlacesImage(oldUrl),
      ),
    );
    try {
      if (photos is List &&
          photos.isNotEmpty &&
          photos.first is Map &&
          photos.first['photo_reference'] is String &&
          output['photoAttributionsKnown'] == true) {
        output['photoBytes'] = await _image({
          'operation': 'photo',
          'photoReference': photos.first['photo_reference'],
        });
        output['imageKind'] = 'photo';
      } else if (output['source'] == 'google' &&
          output['lat'] is num &&
          output['lng'] is num) {
        output['photoBytes'] = await _image({
          'operation': 'staticMap',
          'latitude': output['lat'],
          'longitude': output['lng'],
        });
        output['imageKind'] = 'staticMap';
      }
    } on PlacesUnavailable {
      /* Keep cached venue text and existing placeholder. */
    }
    return output;
  }
}
