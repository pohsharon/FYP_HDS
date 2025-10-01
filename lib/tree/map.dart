import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fyp_hbs/services/tree_api.dart';
import 'package:fyp_hbs/tree/tree_details.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  List<Map<String, dynamic>> treesWithLocation = [];

  final LatLngBounds farmBounds = LatLngBounds(
    const LatLng(3.110831, 101.626978),
    const LatLng(3.130831, 101.646978),
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchTreeMarkers();
  }

Future<void> _fetchTreeMarkers() async {
  try {
    final allTrees = await TreeApi.fetchTrees(); // already a List

    setState(() async {
      final response = await TreeApi.fetchTrees(); // returns Map?
final treeList = response['data'];           // this is List<Map>
treesWithLocation = treeList.map((tree) => {
      ...tree,
      'latitude': tree['latitude'] ?? 0.0,
      'longitude': tree['longitude'] ?? 0.0,
    }).toList();


    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load tree markers: $e")),
      );
    }
  }
}



  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setFallbackLocation();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        _setFallbackLocation();
        return;
      }
    }

    try {
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        final LatLng newLocation = LatLng(
          position.latitude,
          position.longitude,
        );

        if (mounted) {
          setState(() => _currentLocation = newLocation);
          _mapController.move(newLocation, _mapController.camera.zoom);
        }
      });
    } catch (e) {
      debugPrint("❌ Error getting location stream: $e");
      _setFallbackLocation();
    }
  }

  void _setFallbackLocation() {
    final fallbackLocation = LatLng(3.120821, 101.636978);
    if (mounted) {
      setState(() {
        _currentLocation = fallbackLocation;
      });
      _mapController.move(fallbackLocation, _mapController.camera.zoom);
    }
  }

  Future<bool?> _showAddTreeDialog() async {
    final parentContext = context;

    List<Map<String, dynamic>> treeList = [];
    String? selectedTreeId;

    try {
      treeList = (await TreeApi.fetchTrees()) as List<Map<String, dynamic>>; // already a List<Map<String, dynamic>>
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        parentContext,
      ).showSnackBar(SnackBar(content: Text("Failed to load tree list: $e")));
      return false;
    }

    return showDialog<bool>(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select Tree'),
          backgroundColor: AppColors.white,
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    hint: const Text("Select Tree Tag"),
                    value: selectedTreeId,
                    items:
                        treeList.map((tree) {
                          return DropdownMenuItem(
                            value: tree['id'].toString(),
                            child: Text(tree['tree_tag'] ?? 'Unnamed'),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() => selectedTreeId = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        selectedTreeId == null
                            ? null
                            : () async {
                              try {
                                final position =
                                    await Geolocator.getCurrentPosition(
                                      desiredAccuracy: LocationAccuracy.high,
                                    );

                                await TreeApi.addTreeLocation(
                                  treeId: selectedTreeId!,
                                  latitude: position.latitude,
                                  longitude: position.longitude,
                                );

                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    parentContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Tree location saved successfully!",
                                      ),
                                    ),
                                  );
                                  Navigator.pop(
                                    dialogContext,
                                    true,
                                  ); // ✅ Return true
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    parentContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Failed to save location: $e",
                                      ),
                                    ),
                                  );
                                  Navigator.pop(
                                    dialogContext,
                                    false,
                                  ); // ✅ Return false
                                }
                              }
                            },
                    child: const Text("Save"),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
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
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),

          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                // 🧭 Current Location Marker
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
                // 🌳 Tree Markers
                ...treesWithLocation
                    .map((tree) {
                      final lat = double.tryParse(tree['latitude'].toString());
                      final lng = double.tryParse(tree['longitude'].toString());
                      if (lat == null || lng == null) return null;

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 80,
                        height: 80,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => TreeDetailsPage(
                                      treeID:
                                          tree['uuid'] ?? tree['id'].toString(),
                                    ),
                              ),
                            );
                          },
                          child: FittedBox(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  color: Colors.white,
                                  child: Text(
                                    tree['tree_tag'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                    .whereType<Marker>()
                    .toList(),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await _showAddTreeDialog();
          if (result == true) {
            _fetchTreeMarkers(); // ✅ Refresh markers after success
          }
        },
        label: const Text('Add Tree', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        backgroundColor: AppColors.hunterGreen,
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
