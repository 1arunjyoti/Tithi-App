import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson2/flutter_map_geojson2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/app_localizations.dart';
import '../core/anim/press_scale.dart';
import '../core/feedback/app_messages.dart';
import '../theme/app_theme.dart';
import '../app/bootstrap.dart';
import '../providers/location_provider.dart';
import '../services/location_service.dart';
import '../core/location/location_defaults.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

/// State of the place-search overlay. A single enum keeps the panel's
/// visibility and content in sync — the previous pair of booleans could
/// express impossible combinations.
enum _SearchStatus { idle, searching, results, empty, failed }

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final MapController _mapController = MapController();
  // Built-in file cache with the shared app config; the singleton is
  // created on first use, so no init ordering needed. The explicit
  // User-Agent satisfies the OSM tile usage policy (names the app and
  // gives a contact point instead of a library default or placeholder).
  // NOTE: headers must stay a MUTABLE map literal — flutter_map calls
  // putIfAbsent on it to backfill its default User-Agent (a const map
  // throws "Cannot modify unmodifiable map"). Ours already defines the
  // key, so the backfill is a no-op and our contactable UA always wins.
  final TileProvider _tileProvider = NetworkTileProvider(
    cachingProvider: AppBootstrap.appTileCaching(),
    headers: {
      'User-Agent': 'Tithi (app.tithi.pro; +https://tithiapp.netlify.app)',
    },
  );
  StreamSubscription<Position>? _positionSubscription;
  bool _autoCenterEnabled = true;
  LatLng _center = const LatLng(
    kDefaultLatitude,
    kDefaultLongitude,
  ); // Default Delhi
  bool _isLoading = false;
  // True while the "my location" action is resolving a GPS fix.
  bool _isLocating = false;
  // Latest fix reported by the follow stream. Cached even while the camera
  // is not following, so "my location" is instant instead of forcing a new
  // fix (which can time out twice on a stationary/indoor device).
  LatLng? _lastLivePosition;

  /// Minimum zoom applied by the "my location" recenter so the fix is
  /// readable instead of a dot on a continent-level view.
  static const double _recenterMinZoom = 13;

  // Place search state: debounced Nominatim lookups shown as an overlay
  // list under the search field.
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  _SearchStatus _searchStatus = _SearchStatus.idle;
  List<PlaceSearchResult> _searchResults = const [];
  PlaceSearchError? _searchError;
  // Guards against an older, slower response overwriting a newer one.
  int _searchRequestId = 0;

  /// Debounce window; combined with the service-side rate limit this keeps
  /// keystroke bursts well inside Nominatim's 1 req/s policy.
  static const Duration _searchDebounceDelay = Duration(milliseconds: 600);

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
    // Cancel the pending debounce so a queued search can never fire against a
    // torn-down element tree. Any response already in flight is dropped by the
    // request-id + `mounted` guards in [_performSearch], and the shared HTTP
    // client stays open because it is owned by LocationService, not this
    // screen.
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _searchController.dispose();
    _resetLiveLocationSubscription();
    super.dispose();
  }

  /// Starts (or repairs) the live GPS follow stream.
  ///
  /// Idempotent: a second call while a subscription is alive is a no-op, so
  /// the "my location" button can safely use it to recover a stream that was
  /// never established (permission granted later) or that the platform
  /// terminated (the [Stream.listen] error/done handlers null the field).
  Future<void> _startLiveLocation() async {
    if (_positionSubscription != null) return;

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
    // The awaits above can outlive the screen.
    if (!mounted || _positionSubscription != null) return;

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
            final nextCenter = LatLng(position.latitude, position.longitude);
            // Cache regardless of follow state: this is the only *live* fix
            // the screen is guaranteed to have.
            _lastLivePosition = nextCenter;
            if (!_autoCenterEnabled || !mounted) return;
            setState(() {
              _center = nextCenter;
            });
            _mapController.move(nextCenter, _mapController.camera.zoom);
          },
          onError: (Object error) {
            if (kDebugMode) {
              print('Live location stream error: $error');
            }
            _resetLiveLocationSubscription();
          },
          onDone: _resetLiveLocationSubscription,
          cancelOnError: true,
        );
  }

  /// Tears down the follow stream so [_startLiveLocation] can rebuild it.
  void _resetLiveLocationSubscription() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
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

      // Re-reads the place, its zone and the clock in one call: the pick now
      // also stops live location, so "today" moves to this place's day.
      refreshPlaceContext(ref);

      if (mounted) {
        Navigator.pop(context);
        showAppMessage(
          context,
          l10n?.homeLocationSetTo(addressLabel) ??
              'Home location set to $addressLabel',
          kind: AppMessageKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          l10n?.errorSettingLocation(e.toString()) ??
              'Error setting location: $e',
          kind: AppMessageKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Recenters the map on the device's current position.
  ///
  /// Every failure path reports to the user instead of returning silently —
  /// a dead-looking button was the previous behaviour: location services off,
  /// permission denied, and (on Android) a GPS-only request with no timeout
  /// that never completes indoors all produced nothing at all.
  Future<void> _recenterToLiveLocation() async {
    if (_isLocating) return; // Ignore repeat taps while a fix is in flight.
    setState(() => _isLocating = true);
    final l10n = AppLocalizations.of(context);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        showAppMessage(
          context,
          l10n?.pleaseEnableLocationServices ??
              'Please enable location services on your device',
          kind: AppMessageKind.error,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // A button tap is an explicit user action, so requesting here is fine.
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showAppMessage(
          context,
          l10n?.locationPermissionNeeded ??
              'Location permission is required to use your current location.',
          kind: AppMessageKind.error,
          action: permission == LocationPermission.deniedForever
              ? SnackBarAction(
                  label: l10n?.openSettings ?? 'Open Settings',
                  onPressed: Geolocator.openAppSettings,
                )
              : null,
        );
        return;
      }

      final service = ref.read(locationServiceProvider);

      // Resolve a target in increasing order of cost:
      //   1. the live fix the follow stream already reported — free and
      //      genuinely current;
      //   2. the OS last known position, then a fresh fix (service-owned,
      //      with short timeouts and never throwing).
      // Forcing a fix first (the previous behaviour) is what produced
      // "GPS fix timed out, falling back to fused provider" followed by a
      // second timeout: 20-50s of spinner, then nothing.
      LatLng? resolved = _lastLivePosition;

      if (resolved == null) {
        final position = await service.tryResolvePosition();
        if (!mounted) return;
        if (position != null) {
          resolved = LatLng(position.latitude, position.longitude);
        }
      }

      if (resolved == null) {
        showAppMessage(
          context,
          l10n?.couldNotGetCurrentLocation ??
              'Could not get your current location. Please try again.',
          kind: AppMessageKind.error,
        );
        return;
      }

      final nextCenter = resolved;
      setState(() {
        _autoCenterEnabled = true;
        _center = nextCenter;
      });

      // A "reset" that leaves the camera at a continent-level zoom is not
      // useful, so land at a readable zoom when the user was zoomed far out;
      // otherwise keep their current level.
      final zoom = _mapController.camera.zoom;
      _mapController.move(
        nextCenter,
        zoom < _recenterMinZoom ? _recenterMinZoom : zoom,
      );

      // Recover the follow stream if it was never started or the platform
      // dropped it.
      await _startLiveLocation();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to recenter on current location: $e');
      }
      if (mounted) {
        showAppMessage(
          context,
          l10n?.couldNotGetCurrentLocation ??
              'Could not get your current location. Please try again.',
          kind: AppMessageKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  /// Debounce keystrokes before hitting Nominatim: the usage policy allows
  /// at most 1 request/second, and this keeps a burst of typing to a single
  /// lookup. Queries below the minimum length clear any visible results.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();

    if (query.length < LocationService.minSearchQueryLength) {
      // Nothing worth asking the server for: drop any in-flight response and
      // close the panel.
      _searchRequestId++;
      setState(_resetSearchState);
      return;
    }

    setState(() {}); // Reflect the clear button as soon as text exists.
    _searchDebounce = Timer(_searchDebounceDelay, () => _performSearch(query));
  }

  /// Clears all search UI state. The caller is responsible for incrementing
  /// [_searchRequestId] so late responses are discarded.
  void _resetSearchState() {
    _searchStatus = _SearchStatus.idle;
    _searchResults = const [];
    _searchError = null;
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < LocationService.minSearchQueryLength) return;
    // Reached from a Timer, which dispose() cancels — belt and braces so a
    // race can never touch a torn-down element tree.
    if (!mounted) return;

    final requestId = ++_searchRequestId;
    // Capture localizations before awaiting: the element may be unmounted by
    // the time the response lands, and `l10n` must not be read afterwards.
    final l10n = AppLocalizations.of(context);

    setState(() {
      _searchStatus = _SearchStatus.searching;
      _searchError = null;
    });

    final outcome = await ref
        .read(locationServiceProvider)
        .searchPlaces(trimmed, languageCode: l10n?.localeName);

    // Drop stale responses (a newer keystroke or a cleared field) and any
    // response that lands after the screen is gone.
    if (!mounted || requestId != _searchRequestId) return;

    setState(() {
      switch (outcome) {
        case PlaceSearchSuccess(:final results):
          _searchResults = results;
          _searchError = null;
          _searchStatus = results.isEmpty
              ? _SearchStatus.empty
              : _SearchStatus.results;
        case PlaceSearchFailure(:final error):
          _searchResults = const [];
          _searchError = error;
          _searchStatus = _SearchStatus.failed;
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchRequestId++;
    _searchController.clear();
    setState(_resetSearchState);
  }

  /// Moves the pin to a search result and closes the results list. Manual
  /// selection disables the live-GPS auto-follow so the camera stays put.
  void _selectSearchResult(PlaceSearchResult result) {
    final target = LatLng(result.latitude, result.longitude);
    _searchDebounce?.cancel();
    _searchRequestId++;
    _searchController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _autoCenterEnabled = false;
      _center = target;
      _resetSearchState();
    });

    final zoom = _mapController.camera.zoom;
    _mapController.move(target, zoom < 12 ? 12 : zoom);
  }

  /// Opens the OSM copyright page from the attribution credit.
  /// Best-effort: a failed launch stays silent rather than noising a
  /// credit tap with a snackbar.
  Future<void> _openOsmCopyright() async {
    final url = Uri.parse('https://www.openstreetmap.org/copyright');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Ignore: attribution stays put.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // The bar floats transparent over light map tiles, so the title
        // carries its own scrim pill (explicit onSurface ink — the theme
        // foreground is white in dark mode and washes out over tiles).
        // Same surface treatment as the back-button circle below.
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.colors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            l10n?.setHomeLocation ?? 'Set Home Location',
            style: TextStyle(
              color: context.colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PressScale(
          child: IconButton(
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
                // Real application ID (flutter_map falls back to it only
                // when the provider defines no User-Agent of its own).
                userAgentPackageName: 'app.tithi.pro',
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

          // Place Search. Sits below the transparent app bar so the back
          // button and title pill stay reachable; results expand in place
          // over the map.
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchField(l10n),
                if (_searchStatus != _SearchStatus.idle)
                  _buildSearchResults(l10n),
              ],
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
                  tooltip: l10n?.recenterMap ?? 'Recenter map',
                  isBusy: _isLocating,
                  onTap: _recenterToLiveLocation,
                ),
                const SizedBox(height: 8),
                _buildZoomButton(
                  icon: Icons.add,
                  tooltip: l10n?.zoomIn ?? 'Zoom in',
                  onTap: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_center, currentZoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                _buildZoomButton(
                  icon: Icons.remove,
                  tooltip: l10n?.zoomOut ?? 'Zoom out',
                  onTap: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_center, currentZoom - 1);
                  },
                ),
              ],
            ),
          ),

          // Bottom Action Card. The OSM credit lives as a quiet line at
          // the card's foot: the map's own bottom-right corner (where the
          // Rich credit would sit) is covered by this full-width card, so
          // this is what keeps the attribution always visible, as the tile
          // usage policy requires.
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
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openOsmCopyright,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '© OpenStreetMap contributors',
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: context.colors.onSurface.withValues(
                            alpha: 0.55,
                          ),
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

  Widget _buildSearchField(AppLocalizations? l10n) {
    return Container(
      decoration: AppTheme.glassmorphism(context: context, opacity: 0.9),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: (value) {
          _searchDebounce?.cancel();
          _performSearch(value);
        },
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: l10n?.searchLocationHint ?? 'Search for a city or area',
          hintStyle: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.colors.onSurface.withValues(alpha: 0.7),
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n?.clearSearch ?? 'Clear search',
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                  ),
                  onPressed: _clearSearch,
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchResults(AppLocalizations? l10n) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: AppTheme.glassmorphism(context: context, opacity: 0.9),
      clipBehavior: Clip.antiAlias,
      child: switch (_searchStatus) {
        _SearchStatus.idle => const SizedBox.shrink(),
        _SearchStatus.searching => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        _SearchStatus.failed => _buildSearchFailure(l10n),
        _SearchStatus.empty => _buildSearchMessage(
          l10n?.noLocationsFound ?? 'No places found',
        ),
        _SearchStatus.results => ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: _searchResults.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 1,
            color: context.colors.onSurface.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final result = _searchResults[index];
            return ListTile(
              dense: true,
              leading: Icon(
                Icons.location_on_outlined,
                color: context.colors.onSurface.withValues(alpha: 0.7),
              ),
              title: Text(
                result.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              onTap: () => _selectSearchResult(result),
            );
          },
        ),
      },
    );
  }

  Widget _buildSearchMessage(String message) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  /// Failure state: says what actually went wrong and offers a retry, since
  /// the field's [TextField.onChanged] will not fire again on its own.
  Widget _buildSearchFailure(AppLocalizations? l10n) {
    final message = switch (_searchError) {
      PlaceSearchError.rateLimited =>
        l10n?.searchRateLimited ??
            'Too many searches. Please try again in a moment.',
      _ =>
        l10n?.searchFailed ??
            'Search failed. Check your connection and try again.',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchMessage(message),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextButton.icon(
            onPressed: () {
              _searchDebounce?.cancel();
              _performSearch(_searchController.text);
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n?.retry ?? 'Retry'),
          ),
        ),
      ],
    );
  }

  /// Square glass button used for the map controls.
  ///
  /// [isBusy] swaps the icon for a spinner and blocks taps, so a slow GPS fix
  /// reads as "working" instead of "broken". [tooltip] doubles as the
  /// accessibility label (the tooltip's own semantics are excluded to avoid
  /// announcing it twice).
  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool isBusy = false,
  }) {
    final button = Semantics(
      button: true,
      label: tooltip,
      enabled: !isBusy,
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
        child: isBusy
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.onSurface,
                  ),
                ),
              )
            : Icon(icon, color: context.colors.onSurface, size: 24),
      ),
    );

    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: tooltip == null
          ? button
          : Tooltip(
              message: tooltip,
              excludeFromSemantics: true,
              child: button,
            ),
    );
  }
}
