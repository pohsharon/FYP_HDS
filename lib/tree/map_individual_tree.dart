import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fyp_hbs/services/tree_api.dart';
import 'package:fyp_hbs/tree/tree_details.dart';

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
          permission != LocationPermission.whileInUse)
        return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      final LatLng newLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() => _currentLocation = newLocation);
        _mapController.move(newLocation, _mapController.camera.zoom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialLocation = LatLng(
      widget.treeLatitude,
      widget.treeLongitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Tree Location",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialLocation,
          initialZoom: 18,
          cameraConstraint: CameraConstraint.contain(bounds: farmBounds),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: [
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
    );
  }
}
