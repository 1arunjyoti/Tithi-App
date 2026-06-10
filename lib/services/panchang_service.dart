// Conditional export - loads web version by default, native on io platforms
// The PanchangService class is defined in these files.
// panchangServiceProvider is defined in lib/providers/panchang_provider.dart.
export 'panchang/panchang_service.dart'
    if (dart.library.io) 'panchang/panchang_service_native.dart';
