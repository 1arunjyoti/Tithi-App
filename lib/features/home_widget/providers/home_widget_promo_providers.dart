import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage_service.dart';

// Phase 5a: promo-dismiss state extracted from widgets/home_widget_card.dart.
// Name unchanged; the widget re-exports.

/// Whether the home promo card was dismissed (persisted in settings).
/// Applies to home only — the countdown screen always shows the card so the
/// feature stays discoverable where it matters.
final homeWidgetPromoDismissedProvider =
    NotifierProvider<HomeWidgetPromoDismissNotifier, bool>(
      HomeWidgetPromoDismissNotifier.new,
    );

class HomeWidgetPromoDismissNotifier extends Notifier<bool> {
  static const _key = 'home_widget_promo_dismissed';

  @override
  bool build() {
    try {
      return StorageService().getSettingsBox().get(_key, defaultValue: false)
          as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismiss() async {
    state = true;
    try {
      await StorageService().getSettingsBox().put(_key, true);
    } catch (_) {
      // State already hides the card for this session.
    }
  }
}
