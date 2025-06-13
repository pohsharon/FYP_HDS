import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;

  // Dummy tree IDs – replace with actual API data
  final List<String> _treeIds = ['T001', 'T002', 'T003'];

  // Seksyen 17
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
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
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
        });
        _mapController.move(newLocation, _mapController.camera.zoom);
      }
    });
  }

  void _showAddTreeDialog() {
    String? selectedTreeId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Tree ID'),
          content: DropdownButtonFormField<String>(
            value: selectedTreeId,
            hint: const Text("Select Tree ID"),
            items: _treeIds.map((id) {
              return DropdownMenuItem(
                value: id,
                child: Text(id),
              );
            }).toList(),
            onChanged: (value) {
              selectedTreeId = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedTreeId != null && _currentLocation != null) {
                  await _saveTreeLocation(selectedTreeId!, _currentLocation!);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTreeLocation(String treeId, LatLng location) async {
    // Replace with your actual API call
    print("✅ Saving tree $treeId at ${location.latitude}, ${location.longitude}");

    // Example API call:
    // await TreeApi.saveLocation(treeId, location.latitude, location.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialLocation = farmBounds.center;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Farm Map",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialLocation,
          initialZoom: 16,
          cameraConstraint: CameraConstraint.contain(bounds: farmBounds),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTreeDialog,
        label: const Text('Add Tree', style: TextStyle(color: Colors.white),),
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        backgroundColor: AppColors.hunterGreen,
      ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // ✅ center bottom

    );
  }
}
