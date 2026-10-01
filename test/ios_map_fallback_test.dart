import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halisaha_app/widgets/venue_map_widget.dart';

void main() {
  testWidgets(
    'iOS never builds a native map without configuration',
    (tester) async {
      const channel = MethodChannel('depar/maps_configuration');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => false,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VenueMapWidget(venues: [])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.textContaining('liste görünümünden'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
