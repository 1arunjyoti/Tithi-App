import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/temple.dart';
import '../services/temple_service.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart'; // Added

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added
import '../providers/location_provider.dart'; // Added

class TempleMapScreen extends ConsumerStatefulWidget {
  const TempleMapScreen({super.key});

  @override
  ConsumerState<TempleMapScreen> createState() => _TempleMapScreenState();
}

class _TempleMapScreenState extends ConsumerState<TempleMapScreen> {
  final MapController _mapController = MapController();
  // LocationService is now accessed via ref
  final TempleService _templeService = TempleService();

  List<Temple> _temples = [];
  bool _isLoading = false;
  LatLng? _userLocation;

  // Default center (India)
  LatLng _center = const LatLng(20.5937, 78.9629);
  double _zoom = 5.0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() => _isLoading = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final locData = await locationService.getCurrentLocation();
      if (locData != null) {
        if (mounted) {
          setState(() {
            _userLocation = LatLng(locData.latitude, locData.longitude);
            _center = _userLocation!;
            _zoom = 14.0;
          });
          _fetchTemples();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchTemples() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      // Use current map center to fetch
      final center = _mapController.camera.center;
      final temples = await _templeService.fetchNearbyTemples(
        center.latitude,
        center.longitude,
        radius: 5000, // 5km radius
      );

      if (mounted) {
        setState(() {
          _temples = temples;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onMapReady() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Temples'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              onMapReady: _onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.tithi', // Update with actual package
              ),
              MarkerLayer(
                markers: [
                  // User Location Marker
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 60,
                      height: 60,
                      child: const _UserLocationMarker(),
                    ),

                  // Temple Markers
                  ..._temples.map(
                    (temple) => Marker(
                      point: LatLng(temple.latitude, temple.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showTempleDetails(temple),
                        child: const Icon(
                          Icons.place,
                          color: Colors.orange,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Floating Search Button
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: _fetchTemples,
                icon: const Icon(Icons.search),
                label: const Text('Search Here'),
                backgroundColor: context.colors.primaryContainer,
                foregroundColor: context.colors.onPrimaryContainer,
              ),
            ),
          ),

          // Re-center button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'recenter',
              mini: true,
              onPressed: () {
                if (_userLocation != null) {
                  _mapController.move(_userLocation!, 15.0);
                  _fetchTemples();
                } else {
                  _initLocation();
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // Zoom Controls
          Positioned(
            bottom: 170, // Above recenter button
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTempleDetails(Temple temple) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              temple.name,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16),
                const SizedBox(width: 4),
                Text(
                  temple.distance != null
                      ? '${(temple.distance! / 1000).toStringAsFixed(1)} km away'
                      : 'Nearby',
                  style: context.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _launchMaps(temple);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMaps(Temple temple) async {
    // Open Google Maps coordinates
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${temple.latitude},${temple.longitude}',
    );

    // Native intent for geo: (works better on Android)
    final geoUrl = Uri.parse(
      'geo:${temple.latitude},${temple.longitude}?q=${temple.latitude},${temple.longitude}(${Uri.encodeComponent(temple.name)})',
    );

    try {
      if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error launching maps: $e')));
      }
    }
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
