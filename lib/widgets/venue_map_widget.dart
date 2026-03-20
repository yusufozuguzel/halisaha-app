import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VenueMapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> venues;
  final Position? userPosition;

  const VenueMapWidget({
    super.key,
    required this.venues,
    this.userPosition,
  });

  @override
  State<VenueMapWidget> createState() => _VenueMapWidgetState();
}

class _VenueMapWidgetState extends State<VenueMapWidget> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  Map<String, dynamic>? _selectedVenue;
  BitmapDescriptor? _customIcon;

  static const _green = Color(0xFF2EED7B);

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  @override
  void didUpdateWidget(covariant VenueMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venues != widget.venues) {
      // Eski marker'ları tamamen temizle
      _markers.clear();

      // Pınleri güncelle (setState tetikler)
      _buildMarkers();

      // Kamerayı yeni gelen listeye uçur
      _focusOnVenues();
    }
  }

  Future<void> _focusOnVenues() async {
    if (widget.venues.isEmpty) return;
    if (!_controller.isCompleted) return;

    final controller = await _controller.future;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;
    bool hasValid = false;

    for (var v in widget.venues) {
      if (v['lat'] != null && v['lng'] != null) {
        final lat = (v['lat'] as num).toDouble();
        final lng = (v['lng'] as num).toDouble();
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
        hasValid = true;
      }
    }

    if (hasValid) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      try {
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
      } catch (e) {
        // bounds hatasi (Harita layout hazır degilse falan) yoksay
      }
    }
  }

  Future<void> _loadCustomMarker() async {
    try {
      // football_marker.png mevcutsa onu kullan
      await rootBundle.load('assets/images/football_marker.png');
      _customIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/football_marker.png',
      );
    } catch (e) {
      // Bulunamazsa fallback: Yeşil Pin
      _customIcon = BitmapDescriptor.defaultMarkerWithHue(120.0);
    }
    _buildMarkers();
  }

  void _buildMarkers() {
    final Set<Marker> markers = {};
    for (var venue in widget.venues) {
      final lat = venue['lat'];
      final lng = venue['lng'];
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(venue['id'] ?? venue['name'] ?? DateTime.now().toString()),
          position: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          icon: _customIcon ?? BitmapDescriptor.defaultMarkerWithHue(120.0),
          onTap: () {
            setState(() {
              _selectedVenue = venue;
            });
          },
        ),
      );
    }
    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Merkezi seç: kullanıcı konumu varsa o, yoksa ilk saha, yoksa İstanbul
    double initLat = 41.0082;
    double initLng = 28.9784;

    if (widget.userPosition != null) {
      initLat = widget.userPosition!.latitude;
      initLng = widget.userPosition!.longitude;
    } else if (widget.venues.isNotEmpty && widget.venues.first['lat'] != null) {
      initLat = (widget.venues.first['lat'] as num).toDouble();
      initLng = (widget.venues.first['lng'] as num).toDouble();
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(initLat, initLng),
            zoom: 12.5,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false, 
          onMapCreated: (GoogleMapController controller) {
            if (!_controller.isCompleted) {
              _controller.complete(controller);
            }
            _setDarkMapStyle(controller);
            
            // İlk açılışta animasyonu ve focus'u gecikmeli ver
            // (Google Maps layout tam yüklenmeden bounds atanırsa hata atar)
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _focusOnVenues();
            });
          },
          onTap: (_) {
            if (_selectedVenue != null) {
              setState(() => _selectedVenue = null);
            }
          },
        ),
        
        // CUSTOM MODULAR INFO WINDOW (SAHA BİLGİ KARTI)
        if (_selectedVenue != null)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _buildVenueCard(_selectedVenue!),
          ),
          
        // RESET/FOCUS BUTTON TO RETURN TO VENUES
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: "focusVenueBtn",
            onPressed: () => _focusOnVenues(),
            backgroundColor: _green,
            icon: const Icon(Icons.my_location, color: Colors.black, size: 20),
            label: const Text(
              'Sahayı Bul',
              style: TextStyle(
                color: Colors.black, 
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _setDarkMapStyle(GoogleMapController controller) async {
    // Koyu harita stili (isteğe bağlı varsayılan dark theme formatı)
    const String darkMapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#212121"}]
      },
      {
        "elementType": "labels.icon",
        "stylers": [{"visibility": "off"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#212121"}]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "administrative.country",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#9e9e9e"}]
      },
      {
        "featureType": "administrative.land_parcel",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#bdbdbd"}]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [{"color": "#181818"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#1b1b1b"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [{"color": "#2c2c2c"}]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#8a8a8a"}]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry",
        "stylers": [{"color": "#373737"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [{"color": "#3c3c3c"}]
      },
      {
        "featureType": "road.highway.controlled_access",
        "elementType": "geometry",
        "stylers": [{"color": "#4e4e4e"}]
      },
      {
        "featureType": "road.local",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "featureType": "transit",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#000000"}]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#3d3d3d"}]
      }
    ]
    ''';
    try {
      await controller.setMapStyle(darkMapStyle);
    } catch (_) {}
  }

  Widget _buildVenueCard(Map<String, dynamic> venue) {
    final name = venue['name'] ?? 'Bilinmiyor Saha';
    final city = venue['city'] ?? '';
    final distanceMeters = venue['distanceInMeters'] as double?;
    final distanceStr = distanceMeters != null
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : null;

    String imageUrl = venue['photoUrl']?.toString() ?? venue['image']?.toString() ?? '';
    if (imageUrl == 'null') imageUrl = '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16221A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
             color: _green.withOpacity(0.15),
             blurRadius: 20,
             spreadRadius: 2,
          ),
        ],
        border: Border.all(color: _green.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fotoğraf Parçası
          SizedBox(
            width: 100,
            height: 100,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF0D1B13),
                      child: const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: _green, strokeWidth: 2),
                        )
                      ),
                    ),
                    errorWidget: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          
          // Detay Kısmı
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white.withOpacity(0.65), size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          distanceStr != null ? '$city • 📍 $distanceStr' : city,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Kapat Butonu
          IconButton(
            icon: Icon(Icons.close, color: Colors.white.withOpacity(0.5), size: 18),
            onPressed: () => setState(() => _selectedVenue = null),
          )
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF0D1B13),
      child: const Center(
        child: Icon(Icons.stadium_outlined, color: _green, size: 30),
      ),
    );
  }
}
