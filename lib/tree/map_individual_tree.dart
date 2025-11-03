import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
          permission != LocationPermission.whileInUse) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current location not detected yet.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await TreeApi.addTreeLocation(
        treeUuid: widget.treeUuid,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tree location saved successfully!")),
      );

      setState(() {
        _locationNotSaved = false; // ✅ hide button and message
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save location: $e")),
      );
    } finally {
      setState(() => _isSaving = false);
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
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveTreeLocation,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? "Saving..." : "Save Tree Location",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
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
