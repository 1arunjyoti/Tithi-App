import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
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
  }

  Future<void> _onSelectLocation() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(locationServiceProvider);
      // Reverse geocode to get address
      // We can use Nominatim directly or via service helper
      final cityName = await service.getCityName(
        _center.latitude,
        _center.longitude,
      );

      // Also get full address details if possible, or just use city name for now
      // Let's use Nominatim explicitly here to show a better label if we want,
      // but service.getCityName filters nicely for "City".
      // Let's stick to the service's logic to keep it consistent.
      final addressLabel =
          cityName ??
          '${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)}';

      // Save as Home Location
      await service.setHomeLocation(
        _center.latitude,
        _center.longitude,
        addressLabel,
      );

      // Invalidate providers to refresh UI
      ref.invalidate(currentLocationProvider);
      ref.invalidate(homeLocationProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Home location set to $addressLabel')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error setting location: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Set Home Location',
          style: TextStyle(color: Colors.black),
        ),
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
              initialZoom: 13.0,
              onPositionChanged: (pos, hasGesture) {
                _center = pos.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tithi',
              ),
              // Simple Credits overlay
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: null, // tap action
                  ),
                ],
              ),
            ],
          ),

          // Center Pin
          const Center(
            child: Icon(Icons.location_on, color: Colors.red, size: 48),
          ),

          // Zoom Controls
          Positioned(
            right: 16,
            top: 120,
            child: Column(
              children: [
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
                borderRadius: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
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
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Set This Location',
                              style: TextStyle(
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
