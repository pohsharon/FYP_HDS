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
    const LatLng(3.110831, 101.626978),
    const LatLng(3.130831, 101.646978),
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
        title: const Text(
          "Tree Location",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "⚠️ Tree location not saved yet. Showing your current location.",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // 💾 Save Tree Location button
          if (_locationNotSaved)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () {
                  if (_isSaving) return;
                  _saveTreeLocation();
                },
                child: Text(
                  _isSaving ? "Saving..." : "Save Tree Location",
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pakistanGreen,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
                color: Colors.white70,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
