/// Platform initialization with conditional imports
/// Uses mobile implementation on Android/iOS, stub on web
export 'platform_init_stub.dart'
    if (dart.library.io) 'platform_init_mobile.dart';
