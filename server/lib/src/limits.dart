/// Bremsen aus G10, im Speicher. Nach einem Neustart sind sie leer; das ist
/// hinnehmbar, ein Neustart kommt nicht oft genug vor, um Raten zu helfen.
class RateLimiter {
  final int limit;
  final Duration window;
  final _hits = <String, List<DateTime>>{};

  RateLimiter({required this.limit, required this.window});

  List<DateTime> _recent(String key, DateTime now) {
    final hits = _hits[key];
    if (hits == null) return const [];
    final from = now.subtract(window);
    hits.removeWhere((time) => !time.isAfter(from));
    if (hits.isEmpty) _hits.remove(key);
    return hits;
  }

  /// Ist [key] schon am Limit?
  bool blocked(String key, DateTime now) => _recent(key, now).length >= limit;

  void hit(String key, DateTime now) {
    _recent(key, now);
    (_hits[key] ??= []).add(now);
  }

  /// Raeumt abgelaufene Eintraege weg, damit der Speicher nicht waechst.
  void sweep(DateTime now) {
    for (final key in _hits.keys.toList()) {
      _recent(key, now);
    }
  }

  int get size => _hits.length;
}
