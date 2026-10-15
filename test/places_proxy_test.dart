import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/places_proxy.dart';
import 'package:halisaha_app/core/services/safety_api.dart';

void main() {
  final photo = {
    'imageBase64': base64Encode([255, 216, 255, 0]),
    'mimeType': 'image/jpeg',
  };
  Map<String, dynamic> venue(int i) => {
    'source': 'google',
    'id': 'place-$i',
    'photos': [
      {
        'photo_reference': 'photo-$i',
        'html_attributions': ['Author $i'],
      },
    ],
  };

  test(
    'missing or disabled proxy never dispatches a Google operation',
    () async {
      for (final status in [
        <String, dynamic>{},
        {'placesProxyEnabled': false},
      ]) {
        var calls = 0;
        final proxy = PlacesProxy(
          currentUid: () => 'alice',
          call: (function, _) async {
            calls++;
            expect(function, 'safetyStatus');
            return status;
          },
        );
        await expectLater(
          proxy.search('saha'),
          throwsA(isA<PlacesUnavailable>()),
        );
        await expectLater(
          proxy.search('saha'),
          throwsA(isA<PlacesUnavailable>()),
        );
        expect(calls, 1);
      }
    },
  );

  test(
    'ordinary cached catalog document IDs do not request Google details',
    () async {
      final proxy = PlacesProxy(
        currentUid: () => 'alice',
        call: (_, _) async => fail('Local catalog should not call proxy'),
      );
      final output = await proxy.decorate({
        'id': 'curated-venue',
        'name': 'Local',
        'lat': 1,
        'lng': 2,
      });
      expect(output['name'], 'Local');
      expect(output['photoBytes'], isNull);
    },
  );

  test('invalid photo request does not disable a later search', () async {
    var searches = 0;
    final proxy = PlacesProxy(
      currentUid: () => 'alice',
      call: (function, data) async {
        if (function == 'safetyStatus') return {'placesProxyEnabled': true};
        if (data['operation'] == 'photo')
          throw const SafetyApiException('INVALID_ARGUMENT');
        searches++;
        return {'status': 'OK', 'results': []};
      },
    );
    expect((await proxy.decorate(venue(1)))['photoBytes'], isNull);
    await proxy.search('saha');
    expect(searches, 1);
  });

  test('concurrent operations share one capability request', () async {
    final gate = Completer<Map<String, dynamic>>();
    var checks = 0;
    final proxy = PlacesProxy(
      currentUid: () => 'alice',
      call: (function, _) async {
        if (function == 'safetyStatus') {
          checks++;
          return gate.future;
        }
        return {'status': 'OK', 'results': []};
      },
    );
    final first = proxy.search('first');
    final second = proxy.search('second');
    gate.complete({'placesProxyEnabled': true});
    await Future.wait([first, second]);
    expect(checks, 1);
  });

  test(
    'visible image enrichment limits count and concurrency and retains authors',
    () async {
      var active = 0;
      var peak = 0;
      var images = 0;
      final proxy = PlacesProxy(
        currentUid: () => 'alice',
        call: (function, data) async {
          if (function == 'safetyStatus') return {'placesProxyEnabled': true};
          active++;
          if (active > peak) peak = active;
          images++;
          await Future<void>.delayed(Duration.zero);
          active--;
          return photo;
        },
      );
      final output = await proxy.decorateVisible(List.generate(40, venue));
      expect(images, 10);
      expect(peak, lessThanOrEqualTo(2));
      expect(
        output.take(10).every((item) => item['photoBytes'] is Uint8List),
        true,
      );
      expect(output.skip(10).every((item) => item['photoBytes'] == null), true);
      expect(output.first['photoAttributions'], ['Author 0']);
    },
  );

  test(
    'image byte retention remains bounded despite many large photos',
    () async {
      final bytes = Uint8List(PlacesProxy.maxImageBytes)
        ..setRange(0, 3, [255, 216, 255]);
      final proxy = PlacesProxy(
        currentUid: () => 'alice',
        call: (function, _) async => function == 'safetyStatus'
            ? {'placesProxyEnabled': true}
            : {'imageBase64': base64Encode(bytes), 'mimeType': 'image/jpeg'},
      );
      final output = await proxy.decorateVisible(List.generate(10, venue));
      final total = output
          .map((v) => v['photoBytes'])
          .whereType<Uint8List>()
          .fold<int>(0, (sum, b) => sum + b.length);
      expect(total, lessThanOrEqualTo(PlacesProxy.maxCacheBytes));
    },
  );

  test('old keyed URLs are removed even while service is unavailable', () async {
    final proxy = PlacesProxy(
      currentUid: () => 'alice',
      call: (_, _) async => {},
    );
    final output = await proxy.decorate({
      'source': 'google',
      'id': 'place',
      'photoUrl':
          'https://maps.googleapis.com/maps/api/place/photo?key=test-only-key',
    });
    expect(output['photoUrl'], '');
    expect(output['photoBytes'], isNull);
  });

  test(
    'invalid MIME/signatures and oversized images cannot enter transport cache',
    () {
      for (final response in [
        {
          'imageBase64': base64Encode([1, 2, 3]),
          'mimeType': 'image/jpeg',
        },
        {'imageBase64': 'bad base64', 'mimeType': 'image/png'},
        {
          'imageBase64': base64Encode([255, 216, 255]),
          'mimeType': 'text/html',
        },
        {
          'imageBase64': 'A' * (PlacesProxy.maxImageBytes * 2),
          'mimeType': 'image/jpeg',
        },
      ]) {
        expect(
          () => PlacesProxy.decodeImage(response),
          throwsA(isA<PlacesUnavailable>()),
        );
      }
    },
  );
}
