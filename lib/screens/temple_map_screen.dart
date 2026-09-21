import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson2/flutter_map_geojson2.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import '../features/temple/providers/temple_providers.dart';
import '../models/temple.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart'; // Added

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added
import '../app/bootstrap.dart';
import '../providers/location_provider.dart'; // Added
import '../widgets/responsive_layout.dart';

class TempleMapScreen extends ConsumerStatefulWidget {
  const TempleMapScreen({super.key});

  @override
  ConsumerState<TempleMapScreen> createState() => _TempleMapScreenState();
}

class _TempleMapScreenState extends ConsumerState<TempleMapScreen> {
  final MapController _mapController = MapController();
  final FMTCTileProvider _tileProvider = FMTCTileProvider(
    stores: const {'osm_tiles': BrowseStoreStrategy.readUpdateCreate},
    cachedValidDuration: const Duration(days: 30),
  );

  LatLng? _userLocation;

  // Default center (India)
  LatLng _center = const LatLng(20.5937, 78.9629);
  double _zoom = 5.0;

  @override
  void dispose() {
    unawaited(_tileProvider.dispose());
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Tile store initializes post-first-frame: gate on it before tiles
    // render (GPS fix below usually takes longer, so rarely any wait).
    final pendingTiles = AppBootstrap.tileCacheReady;
    try {
      final locationService = ref.read(locationServiceProvider);
      final locData = await locationService.getCurrentLocation();
      await pendingTiles;
      if (locData != null) {
        if (mounted) {
          setState(() {
            _userLocation = LatLng(locData.latitude, locData.longitude);
            _center = _userLocation!;
            _zoom = 14.0;
          });
          await _fetchTemples(center: _userLocation!, zoom: _zoom, force: true);
        }
      }
    } catch (_) {
      // No location: the map stays on the default India viewport.
    }
  }

  /// Fetches a page around the camera (or explicit [center]/[zoom]).
  /// State (list, loading, pagination, errors) lives in
  /// [templeListProvider]; this only resolves the viewport inputs.
  Future<void> _fetchTemples({
    bool reset = true,
    bool force = false,
    LatLng? center,
    double? zoom,
  }) {
    final requestCenter = center ?? _mapController.camera.center;
    final requestZoom = zoom ?? _mapController.camera.zoom;
    return ref
        .read(templeListProvider.notifier)
        .fetch(
          center: requestCenter,
          radius: templeRadiusFromZoom(requestZoom),
          reset: reset,
          force: force,
        );
  }

  void _onMapReady() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Search state (list, loading, pagination) comes from the provider;
    // failures surface as the same snackbar the setState version showed.
    final templeState = ref.watch(templeListProvider);
    final temples = templeState.temples;
    final isLoading = templeState.isLoading;
    ref.listen<Object?>(
      templeListProvider.select((s) => s.error),
      (_, error) {
        if (error == null || !mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.templeSearchFailed)));
        ref.read(templeListProvider.notifier).clearError();
      },
    );
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
          if (isLoading)
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
                  strokeColor: AppTheme.mapBoundary,
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
                  ...temples.map(
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
                  onPressed: isLoading
                      ? null
                      : () => _fetchTemples(),
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
                onPressed: isLoading
                    ? null
                    : () {
                        if (_userLocation != null) {
                          _mapController.move(_userLocation!, 15.0);
                          _fetchTemples(center: _userLocation!, zoom: 15.0);
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
      sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
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
