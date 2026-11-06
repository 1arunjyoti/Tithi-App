import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/panchang_service.dart';

// Regression: switching the Panjika system replaces `panchangServiceProvider`
// with a new, uninitialized instance. `panchangInitProvider` used to *read*
// (not watch) the service, so it kept serving the previous instance's completed
// init: every downstream computation then threw "PanchangService not
// initialized" and the home screen went blank until an app restart.
//
// The fake records init calls instead of touching the native ephemeris.

class _RecordingPanchangService extends PanchangService {
  _RecordingPanchangService(this.label);

  final String label;
  int initCalls = 0;

  @override
  Future<void> init() async {
    initCalls++;
  }
}

void main() {
  test('switching the calculation school initializes the new service', () async {
    final first = _RecordingPanchangService('bisuddha');
    final second = _RecordingPanchangService('suryasiddhanta');

    final activeService = StateProvider<PanchangService>((_) => first);
    final gate = Completer<void>()..complete();

    final container = ProviderContainer(
      overrides: [
        // The real gate is completed by the first-launch permission flow.
        locationPermissionGateProvider.overrideWithValue(gate),
        // Stand-in for `PanchangService(school: ...)`: the provider rebuilds
        // (with a new instance) whenever the school changes.
        panchangServiceProvider.overrideWith(
          (ref) => ref.watch(activeService),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(panchangInitProvider.future);
    expect(first.initCalls, 1);
    expect(second.initCalls, 0);

    // The settings picker replaces the provider's value, as
    // `setPanchangSchool` does through `panchangSchoolProvider`.
    container.read(activeService.notifier).state = second;

    // Reading the init future after the switch must initialize the replacement.
    await container.read(panchangInitProvider.future);

    expect(second.initCalls, 1, reason: 'new school service must be initialized');
  });
}
