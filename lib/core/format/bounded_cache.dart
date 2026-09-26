/// Tiny insertion-ordered bounded cache (Phase 1).
///
/// Dart [Map] preserves insertion order, so evicting the oldest fifth on
/// overflow gives a cheap LRU approximation without a new dependency.
/// Used for `DateFormat`/`NumberFormat` caches that previously grew without
/// bound (`utils/tithi_localization.dart`).
class BoundedCache<K, V> {
  BoundedCache({this.maxSize = 200}) : assert(maxSize > 0);

  final int maxSize;
  final Map<K, V> _entries = <K, V>{};

  V? get(K key) => _entries[key];

  void set(K key, V value) {
    // Refresh recency on re-insert.
    _entries.remove(key);
    if (_entries.length >= maxSize) {
      final toRemove = _entries.keys.take(maxSize ~/ 5).toList();
      for (final k in toRemove) {
        _entries.remove(k);
      }
    }
    _entries[key] = value;
  }

  int get length => _entries.length;
}
