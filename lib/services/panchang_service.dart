// Conditional export - loads web version by default, native on io platforms
// The PanchangService class and panchangServiceProvider are defined in these files
export 'panchang/panchang_service.dart'
    if (dart.library.io) 'panchang/panchang_service_native.dart';
