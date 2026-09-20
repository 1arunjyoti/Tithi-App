import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson2/flutter_map_geojson2.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/location_provider.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final FMTCTileProvider _tileProvider = FMTCTileProvider(
    stores: const {'osm_tiles': BrowseStoreStrategy.readUpdateCreate},
    cachedValidDuration: const Duration(days: 30),
  );
  StreamSubscription<Position>? _positionSubscription;
  bool _autoCenterEnabled = true;
  LatLng _center = const LatLng(28.6139, 77.2090); // Default Delhi
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize center with current location if available
    final currentAsync = ref.read(currentLocationProvider);
    currentAsync.whenData((loc) {
      if (loc != null) {
        setState(() {
          _center = LatLng(loc.latitude, loc.longitude);
        });
      }
    });
    _startLiveLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLiveLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final locationSettings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 10,
            forceLocationManager: true,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 10,
          );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            if (!_autoCenterEnabled || !mounted) return;
            final nextCenter = LatLng(position.latitude, position.longitude);
            setState(() {
              _center = nextCenter;
            });
            _mapController.move(nextCenter, _mapController.camera.zoom);
          },
        );
  }

  Future<void> _onSelectLocation() async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context);

    try {
      final service = ref.read(locationServiceProvider);
      final cityName = await service.getCityName(
        _center.latitude,
        _center.longitude,
      );

      final addressLabel =
          cityName ??
          '${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)}';

      await service.setHomeLocation(
        _center.latitude,
        _center.longitude,
        addressLabel,
      );

      ref.invalidate(currentLocationProvider);
      ref.invalidate(homeLocationProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.homeLocationSetTo(addressLabel) ??
                  'Home location set to $addressLabel',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.errorSettingLocation(e.toString()) ??
                  'Error setting location: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _recenterToLiveLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.medium,
              forceLocationManager: true,
            )
          : const LocationSettings(accuracy: LocationAccuracy.medium),
    );

    final nextCenter = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _autoCenterEnabled = true;
      _center = nextCenter;
    });
    _mapController.move(nextCenter, _mapController.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n?.setHomeLocation ?? 'Set Home Location'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  _autoCenterEnabled = false;
                }
                _center = pos.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tithi',
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
              // Simple Credits overlay
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // Center Pin
          Center(
            child: Semantics(
              label: l10n?.mapPinLocation ?? 'Map pin location',
              child: Icon(
                Icons.location_on,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
            ),
          ),

          // Zoom Controls
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              children: [
                _buildZoomButton(
                  icon: Icons.my_location,
                  onTap: _recenterToLiveLocation,
                ),
                const SizedBox(height: 8),
                _buildZoomButton(
                  icon: Icons.add,
                  onTap: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_center, currentZoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                _buildZoomButton(
                  icon: Icons.remove,
                  onTap: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_center, currentZoom - 1);
                  },
                ),
              ],
            ),
          ),

          // Bottom Action Card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassmorphism(
                context: context,
                opacity: 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n?.dragMapToPin ??
                        'Drag map to position pin at your home',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onSelectLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: context.colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.onPrimary,
                              ),
                            )
                          : Text(
                              l10n?.setThisLocation ?? 'Set This Location',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: context.colors.onSurface, size: 24),
      ),
    );
  }
}
