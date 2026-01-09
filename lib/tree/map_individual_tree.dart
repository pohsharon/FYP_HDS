import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/services/api/tree_api.dart'; // ✅ make sure this import exists

class MapIndividualTreePage extends StatefulWidget {
  final double treeLatitude;
  final double treeLongitude;
  final String treeTag;
  final String treeUuid;

  const MapIndividualTreePage({
    super.key,
    required this.treeLatitude,
    required this.treeLongitude,
    required this.treeTag,
    required this.treeUuid,
  });

  @override
  State<MapIndividualTreePage> createState() => _MapIndividualTreePageState();
}

class _MapIndividualTreePageState extends State<MapIndividualTreePage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _locationNotSaved = false;
  bool _isSaving = false; // ✅ track saving state

  final LatLngBounds farmBounds = LatLngBounds(
    // const LatLng(3.110831, 101.626978),
    // const LatLng(3.130831, 101.646978),
    const LatLng(6.36800, 100.38200), // Southwest corner
    const LatLng(6.39000, 100.42000), // Northeast corner
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      final LatLng newLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentLocation = newLocation;

          // 🌱 If tree location is not saved, mark it and center on user
          if (widget.treeLatitude == 0.0 && widget.treeLongitude == 0.0) {
            _locationNotSaved = true;
            _mapController.move(newLocation, 18);
          }
        });
      }
    });
  }

  void _centerToCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 18);
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  Future<void> _saveTreeLocation() async {
    if (_currentLocation == null) {
      final overlayContext = Navigator.of(context, rootNavigator: true).overlay?.context ?? context;
      Flushbar(
        message: "Current location not detected yet.",
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.info, color: Colors.white),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
      ).show(overlayContext);
      return;
    }

    // prevent concurrent saves but keep the button visually active
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await TreeApi.addTreeLocation(
        treeUuid: widget.treeUuid,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      );

      if (!mounted) return;

      // Hide the local UI indicator and return success to caller. The
      // caller (TreeDetailsPage) will refresh and can show a confirmation
      // message if desired. Avoid showing a Flushbar here before pop to
      // prevent pushing a new route while the navigator is in a pop/push
      // transition (which can trigger an assertion).
      setState(() {
        _locationNotSaved = false; // hide button and message
      });

      Navigator.pop(context, true);
    } catch (e) {
      final overlayContext = Navigator.of(context, rootNavigator: true).overlay?.context ?? context;
      Flushbar(
        message: "Failed to save location: $e",
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red.shade700,
        icon: const Icon(Icons.error, color: Colors.white),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
      ).show(overlayContext);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool treeHasLocation =
        widget.treeLatitude != 0.0 && widget.treeLongitude != 0.0;

    final LatLng initialLocation = treeHasLocation
        ? LatLng(widget.treeLatitude, widget.treeLongitude)
        : (_currentLocation ?? const LatLng(3.120821, 101.636978));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              widget.treeTag,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.pakistanGreen,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialLocation,
              initialZoom: 18,
              cameraConstraint: CameraConstraint.contain(bounds: farmBounds),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fyp_hbs',
              ),
              MarkerLayer(
                markers: [
                  // 🧭 Current user location marker
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),

                  // 🌳 Tree marker (only if saved)
                  if (treeHasLocation)
                    Marker(
                      point: LatLng(widget.treeLatitude, widget.treeLongitude),
                      width: 50,
                      height: 50,
                      child: Tooltip(
                        message: widget.treeTag,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ℹ️ Message overlay if location not saved
          if (_locationNotSaved)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "Tree location not saved yet.",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 💾 Save Tree Location button
          if (_locationNotSaved)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () {
                  if (_isSaving) return;
                  _saveTreeLocation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hunterGreen,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSaving ? Icons.hourglass_bottom : Icons.save_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSaving ? "Saving..." : "Save Tree Location",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Map Controls
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _buildMapControlButton(
                  icon: Icons.add,
                  onPressed: _zoomIn,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.remove,
                  onPressed: _zoomOut,
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.my_location,
                  onPressed: _centerToCurrentLocation,
                  tooltip: 'My Location',
                ),
              ],
            ),
          ),

          // Copyright
          Positioned(
            right: 10,
            bottom: 10,
            child: GestureDetector(
              onTap: () {
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.copyright, size: 12, color: Colors.black54),
                    SizedBox(width: 4),
                    Text(
                      'OpenStreetMap',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.pakistanGreen,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
