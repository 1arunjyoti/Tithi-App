import 'package:flutter_riverpod/flutter_riverpod.dart';

// Phase 5a: local sheet UI state. Was private in the former
// widgets/event_detail_sheet.dart monolith and invisible to tests; name made
// public, imported directly by the description/hero widgets.
final descExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

// Collapsed hero language chips on the festival event sheet: false shows
// only the first chip row with a "show more" toggle, true reveals every
// regional name. Auto-dispose so reopening the sheet starts collapsed.
final heroChipsExpandedProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
