import 'package:flutter_map/flutter_map.dart';

// Lightweight compatibility shim for FMTC used during development.
// This provides a no-op cache provider (falls back to the regular
// network tile provider) so the app can compile and run when the
// flutter_map_tile_caching package is unavailable or has a different API.
//
// Replace this shim with the real package import when ready:
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class FMTC {
  FMTC._();

  static final Map<String, _FMTCInstance> _stores = {};

  static _FMTCInstance instance(String name) {
    return _stores.putIfAbsent(name, () => _FMTCInstance());
  }
}

class _FMTCInstance {
  Future<void> init() async {
    // no-op in shim
    return;
  }

  TileProvider getTileProvider() {
    return NetworkTileProvider();
  }
}
