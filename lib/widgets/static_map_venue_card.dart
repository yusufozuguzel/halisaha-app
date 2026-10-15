import 'venue_image.dart';
import 'package:flutter/material.dart';
import 'places_attribution_widget.dart';

/// Proxy map bytes retain the complete embedded provider credits.
/// Venue labels sit outside the image.
class StaticMapVenueCard extends StatelessWidget {
  const StaticMapVenueCard({super.key, required this.venue, this.height = 220});
  final Map<String, dynamic> venue;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: VenueImage(
                venue: venue,
                fit: BoxFit.contain,
                placeholder: const Center(
                  child: Icon(Icons.stadium_outlined, color: Colors.white),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Text(
              '${venue['name'] ?? ''} • ${venue['city'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          PlacesAttributionWidget(venue: venue),
        ],
      ),
    );
  }
}
