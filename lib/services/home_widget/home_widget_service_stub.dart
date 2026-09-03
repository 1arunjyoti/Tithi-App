import '../../providers/festival_countdown_provider.dart';

/// Stub implementation for platforms that don't support home widgets
/// (web, desktop). All operations are no-ops.
class HomeWidgetService {
  const HomeWidgetService();

  Future<void> updateFestivalCountdownWidget(
    List<FestivalCountdownTarget> targets,
  ) async {
    // No-op on unsupported platforms
  }

  Future<bool> isRequestPinSupported() async => false;

  Future<bool> requestPinWidget() async => false;

  Future<bool> isWidgetSupported() async => false;
}
