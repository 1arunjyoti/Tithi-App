import 'package:flutter_riverpod/flutter_riverpod.dart';

// Phase 5a: local sheet UI state extracted from
// widgets/event_detail_sheet.dart (was a private provider in the widget
// file, invisible to tests). Name made public; the widget re-exports.
final descExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);
