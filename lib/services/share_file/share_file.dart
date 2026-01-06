/// Conditional export for platform-specific file saving
library;

export 'share_file_stub.dart' if (dart.library.io) 'share_file_mobile.dart';
