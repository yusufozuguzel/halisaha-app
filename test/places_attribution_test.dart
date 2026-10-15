import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha_app/core/services/places_attribution.dart';
import 'package:halisaha_app/widgets/places_attribution_widget.dart';
import 'package:halisaha_app/widgets/static_map_venue_card.dart';

void main() {
  test(
    'search retains response, place and selected photo credits independently',
    () {
      final metadata = placesAttributionMetadata(
        {
          'html_attributions': ['Provider'],
          'photos': [
            {
              'photo_reference': 'first',
              'html_attributions': ['Photographer'],
            },
            {
              'photo_reference': 'second',
              'html_attributions': ['Other author'],
            },
          ],
        },
        responseAttributions: ['Response provider'],
      );
      expect(metadata['source'], 'google');
      expect(metadata['placeAttributions'], ['Response provider', 'Provider']);
      expect(metadata['photoAttributions'], ['Photographer']);
      expect(metadata['photoAttributionsKnown'], true);
    },
  );

  test(
    'old Photos URLs require verified attribution; empty API credits are valid',
    () {
      const photo =
          'https://maps.googleapis.com/maps/api/place/photo?photo_reference=test';
      expect(attributedVenueImage({'photoUrl': photo}), isEmpty);
      final metadata = placesAttributionMetadata({
        'photos': [
          {'html_attributions': <String>[]},
        ],
      });
      expect(attributedVenueImage({'photoUrl': photo, ...metadata}), isEmpty);
      expect(
        placesAttributionMetadata({
          'photos': [
            {'photo_reference': 'old'},
          ],
        })['photoAttributionsKnown'],
        false,
      );
    },
  );

  test('local images do not receive Google attribution', () {
    final venue = {
      'photoUrl': 'https://example.invalid/local.jpg',
      ...placesAttributionMetadata({}, google: false),
    };
    expect(hasGooglePlacesContent(venue), false);
    expect(attributedVenueImage(venue), 'https://example.invalid/local.jpg');
  });

  test(
    'credit parser preserves text, entities and HTTPS links without executing HTML',
    () {
      final credits = parsePlaceCredits([
        '<a href="https://maps.google.com/maps/contrib/123">Ada &amp; Can</a>',
        '<script>hidden</script><b>Copyright &#169;</b>',
        '<a href="javascript:alert(1)">Unsafe link</a>',
        '<a href="https://user:password@example.invalid">Credential URL</a>',
      ]);
      expect(credits.map((credit) => credit.text), [
        'Ada & Can',
        'Copyright \u00a9',
        'Unsafe link',
        'Credential URL',
      ]);
      expect(credits.first.url?.host, 'maps.google.com');
      expect(credits[2].url, isNull);
      expect(credits[3].url, isNull);
    },
  );

  test(
    'credits retain neighboring plaintext and deduplicate repeated provider',
    () {
      final credits = parsePlaceCredits([
        'Photo: <a href="https://example.invalid/author">Author</a>',
        'Provider',
        'Provider',
      ]);
      expect(credits.map((credit) => credit.text), [
        'Photo:',
        'Author',
        'Provider',
      ]);
    },
  );

  testWidgets('compact footer presents legible Google Maps and author credit', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: PlacesAttributionWidget(
              venue: {
                'source': 'google',
                'photoAttributions': ['<b>Photo Author</b>'],
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Photo Author'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Google Maps'));
    expect(label.style?.fontSize, 12);
    expect(label.style?.fontWeight, FontWeight.w400);
    expect(label.softWrap, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long author credits stay accessible in narrow scrolling footer',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 90,
              child: SingleChildScrollView(
                child: PlacesAttributionWidget(
                  venue: {
                    'source': 'google',
                    'photoAttributions': List.generate(8, (i) => 'Author $i'),
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.text('Author 7').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Static Map image contains full image, labels stay outside image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: StaticMapVenueCard(
              height: 180,
              venue: {
                'source': 'google',
                'photoBytes': base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a0VkAAAAASUVORK5CYII=',
                ),
                'name': 'Venue',
                'city': 'City',
              },
            ),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(image.image, isA<MemoryImage>());
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Venue \u2022 City'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(Image)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Venue \u2022 City')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
