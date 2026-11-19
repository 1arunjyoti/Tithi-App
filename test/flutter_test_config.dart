import 'dart:async';

import 'package:tithi/core/perf/startup_timeline.dart';

/// Cold-start marks exist to diagnose a real launch. In tests every widget
/// build would print them and drown the failure output, so they are off here.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  StartupTimeline.enabled = false;
  await testMain();
}
