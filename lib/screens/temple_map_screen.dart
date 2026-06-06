import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson2/flutter_map_geojson2.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import '../models/temple.dart';
import '../services/temple_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart'; // Added

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added
import '../providers/location_provider.dart'; // Added
import '../widgets/responsive_layout.dart';

class TempleMapScreen extends ConsumerStatefulWidget {
  const TempleMapScreen({super.key});

  @override
  ConsumerState<TempleMapScreen> createState() => _TempleMapScreenState();
}

class _TempleMapScreenState extends ConsumerState<TempleMapScreen> {
  final MapController _mapController = MapController();
  // Static to avoid re-instantiation on widget recreation
  static final TempleService _templeService = TempleService();
  static const FMTCStore _tileStore = FMTCStore('osm_tiles');
  final FMTCTileProvider _tileProvider = _tileStore.getTileProvider(
    cachedValidDuration: const Duration(days: 30),
  );

  List<Temple> _temples = [];
  bool _isLoading = false;
  LatLng? _userLocation;
  int _currentPage = 0;
  bool _hasMoreTemples = true;
  static const int _pageSize = 80;

  // Default center (India)
  LatLng _center = const LatLng(20.5937, 78.9629);
  double _zoom = 5.0;

  @override
  void dispose() {
    super.dispose();
  }

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
          await _fetchTemples(force: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchTemples({bool reset = true, bool force = false}) async {
    if (_isLoading && !force) return;

    if (reset) {
      _currentPage = 0;
      _hasMoreTemples = true;
    } else if (!_hasMoreTemples) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Use current map center to fetch
      final center = _mapController.camera.center;
      final zoom = _mapController.camera.zoom;
      final radius = _radiusFromZoom(zoom);
      final temples = await _templeService.fetchNearbyTemples(
        center.latitude,
        center.longitude,
        radius: radius,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _temples = temples;
          } else {
            final existingIds = _temples.map((t) => t.id).toSet();
            _temples.addAll(
              temples.where((temple) => !existingIds.contains(temple.id)),
            );
          }
          _hasMoreTemples = temples.length == _pageSize;
          if (temples.isNotEmpty) {
            _currentPage++;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.templeSearchFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _radiusFromZoom(double zoom) {
    if (zoom >= 15) return 2500;
    if (zoom >= 13) return 5000;
    if (zoom >= 11) return 9000;
    return 15000;
  }

  void _onMapReady() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rightOffset = ResponsiveLayout.value(
      context,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nearbyTemples),
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
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.tithi', // Update with actual package
                tileProvider: _tileProvider,
              ),
              GeoJsonLayer.asset(
                'assets/map_data/india_boundary.geojson',
                styleDefaults: const GeoJsonStyleDefaults(
                  strokeColor: Colors.orange,
                  strokeOpacity: 1.0,
                  strokeWidth: 1.5,
                  fillColor: Colors.transparent,
                  fillOpacity: 0.0,
                ),
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
                      child: Semantics(
                        button: true,
                        label: '${l10n.templeMarker}: ${temple.name}',
                        child: GestureDetector(
                          onTap: () => _showTempleDetails(temple),
                          child: Icon(
                            Icons.place,
                            color: context.colors.primary,
                            size: 40,
                          ),
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
              child: Semantics(
                button: true,
                label: l10n.searchHere,
                child: FloatingActionButton.extended(
                  onPressed: () => _fetchTemples(reset: true),
                  icon: const Icon(Icons.search),
                  label: Text(l10n.searchHere),
                  backgroundColor: context.colors.primaryContainer,
                  foregroundColor: context.colors.onPrimaryContainer,
                ),
              ),
            ),
          ),

          // Re-center button
          Positioned(
            bottom: 100,
            right: rightOffset,
            child: Semantics(
              button: true,
              label: l10n.recenterMap,
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
          ),

          // Zoom Controls
          Positioned(
            bottom: 170, // Above recenter button
            right: rightOffset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: l10n.zoomIn,
                  child: FloatingActionButton(
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
                ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: l10n.zoomOut,
                  child: FloatingActionButton(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTempleDetails(Temple temple) {
    final l10n = AppLocalizations.of(context)!;
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
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16),
                const SizedBox(width: 4),
                Text(
                  temple.distance != null
                      ? l10n.kmAway(
                          (temple.distance! / 1000).toStringAsFixed(1),
                        )
                      : l10n.nearby,
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
                label: Text(l10n.getDirections),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMaps(Temple temple) async {
    final l10n = AppLocalizations.of(context)!;
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
          ).showSnackBar(SnackBar(content: Text(l10n.couldNotOpenMaps)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorLaunchingMaps(e.toString()))),
        );
      }
    }
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.yourLocation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: context.colors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
