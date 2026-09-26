/// Platform-specific APK file + installer operations.
///
/// Web builds cannot write files or launch a package installer, so the
/// stub throws [UnsupportedError] and callers fall back to opening the
/// GitHub releases page.
library;

export 'app_update_file_stub.dart'
    if (dart.library.io) 'app_update_file_io.dart';
