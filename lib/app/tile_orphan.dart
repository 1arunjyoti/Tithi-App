// One-time removal of the pre-migration FMTC tile database.
// dart:io file deletion can't compile on web, so the real implementation
// lives behind this conditional export (project platform pattern).
export 'tile_orphan_stub.dart'
    if (dart.library.io) 'tile_orphan_io.dart';
