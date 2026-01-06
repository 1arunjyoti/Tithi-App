/// Conditional export for platform-specific panchang initialization
/// Uses mobile implementation on non-web platforms, stub on web
library;

export 'panchang_init_stub.dart'
    if (dart.library.io) 'panchang_init_mobile.dart';
