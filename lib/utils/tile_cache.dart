import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Simple file-backed tile cache.
///
/// - Tiles are stored under <appDocs>/tilecache/{z}/{x}/{y}.png
/// - Use `LocalOrNetworkTileProvider()` as a `TileProvider` for flutter_map.
/// - Call `prefetchTilesForBounds` to download tiles for a bbox and zoom range.

class LocalOrNetworkTileProvider extends TileProvider {
  LocalOrNetworkTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coords, TileLayer options) {
    final file = _tileFilePathSync(coords.x, coords.y, coords.z);
    if (file != null && File(file).existsSync()) {
      return FileImage(File(file));
    }

    // Fallback to network tile provider
    return NetworkTileProvider().getImage(coords, options);
  }

  // Synchronous helper: returns path string or null if unable to compute
  String? _tileFilePathSync(int x, int y, int z) {
    try {
      final base = Directory.systemTemp.path; // fallback location
      final p = '$base${Platform.pathSeparator}fyp_tilecache${Platform.pathSeparator}$z${Platform.pathSeparator}$x${Platform.pathSeparator}$y.png';
      return p;
    } catch (_) {
      return null;
    }
  }
}

/// Convert lat/lon to XYZ tile numbers for a given zoom (slippy map tiles)
math.Point<int> latLonToTileXY(double lat, double lon, int zoom) {
  final latRad = lat * math.pi / 180.0;
  final n = math.pow(2.0, zoom);
  final xTile = ((lon + 180.0) / 360.0 * n).floor();
  final yTile = ((1.0 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2.0 * n).floor();
  return math.Point<int>(xTile, yTile);
}

Future<Directory> _getCacheDir() async {
  final dir = await getApplicationDocumentsDirectory();
  final cacheDir = Directory('${dir.path}/tilecache');
  if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
  return cacheDir;
}

String _tileFilePathSyncFromBase(String basePath, int z, int x, int y) {
  return '$basePath${Platform.pathSeparator}$z${Platform.pathSeparator}$x${Platform.pathSeparator}$y.png';
}

Future<void> _saveTileBytes(String basePath, int z, int x, int y, List<int> bytes) async {
  final dir = Directory('$basePath${Platform.pathSeparator}$z${Platform.pathSeparator}$x');
  if (!await dir.exists()) await dir.create(recursive: true);
  final file = File(_tileFilePathSyncFromBase(basePath, z, x, y));
  await file.writeAsBytes(bytes);
}

/// Estimate number of tiles for a bounds and zoom range
int estimateTileCountForBounds(LatLngBounds bounds, int zMin, int zMax) {
  int total = 0;
  for (int z = zMin; z <= zMax; z++) {
    final nw = latLonToTileXY(bounds.north, bounds.west, z);
    final se = latLonToTileXY(bounds.south, bounds.east, z);
    final dx = (se.x - nw.x).abs().toInt() + 1;
    final dy = (se.y - nw.y).abs().toInt() + 1;
    total += dx * dy;
  }
  return total;
}

/// Prefetch tiles for the given bounds and zoom range. Reports progress via the
/// optional callback (downloaded, total).
Future<void> prefetchTilesForBounds(
    LatLngBounds bounds, int zMin, int zMax, void Function(int, int)? progress) async {
  final cacheDir = await _getCacheDir();
  final base = cacheDir.path;

  int total = estimateTileCountForBounds(bounds, zMin, zMax);
  int downloaded = 0;

  for (int z = zMin; z <= zMax; z++) {
    final nw = latLonToTileXY(bounds.north, bounds.west, z);
    final se = latLonToTileXY(bounds.south, bounds.east, z);

    final xMin = math.min(nw.x, se.x);
    final xMax = math.max(nw.x, se.x);
    final yMin = math.min(nw.y, se.y);
    final yMax = math.max(nw.y, se.y);

    for (int x = xMin; x <= xMax; x++) {
      for (int y = yMin; y <= yMax; y++) {
        final filePath = _tileFilePathSyncFromBase(base, z, x, y);
        final file = File(filePath);
        if (await file.exists()) {
          downloaded++;
          progress?.call(downloaded, total);
          continue;
        }

        try {
          final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            await _saveTileBytes(base, z, x, y, res.bodyBytes);
          }
        } catch (e) {
          // ignore single tile failures; continue
        }

        downloaded++;
        progress?.call(downloaded, total);
      }
    }
  }
}
