// Conditional export: stub on web/desktop, mobile on Android/iOS
export 'home_widget/home_widget_service_stub.dart'
    if (dart.library.io) 'home_widget/home_widget_service_mobile.dart';
