import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/services/places_attribution.dart';

bool hasVenueImage(Map<String, dynamic> venue) =>
    venue['photoBytes'] is Uint8List || attributedVenueImage(venue).isNotEmpty;

class VenueImage extends StatelessWidget {
  const VenueImage({
    super.key,
    required this.venue,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });
  final Map<String, dynamic> venue;
  final BoxFit fit;
  final Widget placeholder;
  @override
  Widget build(BuildContext context) {
    final bytes = venue['photoBytes'];
    if (bytes is Uint8List) {
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    final url = attributedVenueImage(venue);
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
