import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/places_attribution.dart';

/// Plain text credits and HTTPS links only; remote HTML is never rendered.
class PlacesAttributionWidget extends StatelessWidget {
  const PlacesAttributionWidget({super.key, required this.venue});
  final Map<String, dynamic> venue;

  @override
  Widget build(BuildContext context) {
    final credits = venuePlaceCredits(venue);
    if (!hasGooglePlacesContent(venue) && credits.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFF1F1F1F),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasGooglePlacesContent(venue))
            const Text(
              'Google Maps',
              softWrap: false,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          for (final credit in credits)
            InkWell(
              onTap: credit.url == null
                  ? null
                  : () async {
                      try {
                        await launchUrl(
                          credit.url!,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {
                        /* Preserve credit even if a browser cannot open. */
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  credit.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    decoration: credit.url == null
                        ? TextDecoration.none
                        : TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
