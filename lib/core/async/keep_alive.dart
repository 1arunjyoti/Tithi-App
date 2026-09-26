import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Shared keep-alive-with-timeout for autoDispose providers whose rebuild
// cost is high (month batches, adaptive grids, yearly lists): recent
// entries stay warm for instant back-navigation, idle ones release instead
// of pinning large maps for the whole session. Replaces the
// keepAliveLink + Timer + onDispose triplet previously copied per provider.
extension KeepAliveForX on Ref {
  /// Keeps the provider alive for [duration] after the last listen, then
  /// releases it. The timer cancels on early disposal — no leaked Timer.
  void keepAliveFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
