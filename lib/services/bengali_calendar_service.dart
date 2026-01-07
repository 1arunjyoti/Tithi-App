// Conditional export - loads web version by default, native on io platforms
export 'bengali_calendar/bengali_calendar_service.dart'
    if (dart.library.io) 'bengali_calendar/bengali_calendar_service_native.dart';
