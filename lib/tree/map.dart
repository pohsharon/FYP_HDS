import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/services/local database/tree_db.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fyp_hbs/utils/tile_cache.dart';
import 'package:another_flushbar/flushbar.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  List<Map<String, dynamic>> treesWithLocation = [];
  final TextEditingController treeController = TextEditingController();
  bool _isLoading = true;
  late AnimationController _fabAnimationController;
  Animation<double>? _fabAnimation;

  final LatLngBounds farmBounds = LatLngBounds(
    const LatLng(3.110831, 101.626978),
    const LatLng(3.130831, 101.646978),
  );

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
    
    _getCurrentLocation();
    _fetchTreeMarkers();
  }

  @override
  void dispose() {
    treeController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchTreeMarkers() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await TreeApi.fetchAllTrees();
      final treeList = response['data']['data'] as List<dynamic>;

      final markers = treeList.map<Map<String, dynamic>>((tree) {
        final treeMap = tree as Map<String, dynamic>;
        return {
          ...treeMap,
          'latitude': treeMap['latitude'] ?? 0.0,
          'longitude': treeMap['longitude'] ?? 0.0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          treesWithLocation = markers;
          _isLoading = false;
        });
      }
    } catch (e) {
      try {
        final local = await TreeDB().fetchAllTrees();
        final markers = local.map<Map<String, dynamic>>((t) {
          return {
            'uuid': t.uuid,
            'tree_tag': t.treeTag ?? 'Offline Tree',
            'latitude': t.latitude ?? 0.0,
            'longitude': t.longitude ?? 0.0,
          };
        }).toList();

        if (mounted) {
          setState(() {
            treesWithLocation = markers;
            _isLoading = false;
          });
        }
      } catch (localErr) {
        if (mounted) {
          setState(() => _isLoading = false);
          await Flushbar(
            message: "Failed to load tree markers",
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(12),
            boxShadows: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ).show(context);
        }
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
      setState(() => _currentLocation = fallbackLocation);
      _mapController.move(fallbackLocation, _mapController.camera.zoom);
    }
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

  Future<bool?> _showAddTreeDialog() async {
    final parentContext = context;
    List<Map<String, dynamic>> treeList = [];
    String? selectedTreeId;

    try {
      final response = await TreeApi.fetchAllTrees();
      treeList = (response['data']['data'] as List<dynamic>)
          .map((tree) => tree as Map<String, dynamic>)
          .toList();
    } catch (e) {
      try {
        final local = await TreeDB().fetchAllTrees();
        treeList = local
            .map((t) => {
                  'uuid': t.uuid,
                  'tree_tag': t.treeTag ?? 'Offline Tree',
                })
            .toList();
      } catch (localErr) {
        if (!mounted) return false;
        await Flushbar(
          message: "Failed to load tree list",
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(12),
        ).show(parentContext);
        return false;
      }
    }

    return showDialog<bool>(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final dialogWidth = min(screenWidth * 0.85, 450.0);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            width: dialogWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.pakistanGreen,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.forest,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Add Tree Location',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(dialogContext, false),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select a tree to pin on the map',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Dropdown with custom styling
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selectedTreeId == null
                                    ? Colors.grey.shade300
                                    : AppColors.pakistanGreen,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownMenu<String>(
                              width: dialogWidth - 48,
                              menuHeight: 300,
                              controller: treeController,
                              requestFocusOnTap: true,
                              initialSelection: selectedTreeId,
                              label: const Text('Select Tree Tag'),
                              trailingIcon: const Icon(Icons.arrow_drop_down),
                              selectedTrailingIcon: const Icon(Icons.arrow_drop_up),
                              inputDecorationTheme: InputDecorationTheme(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              dropdownMenuEntries: treeList
                                  .map<DropdownMenuEntry<String>>(
                                    (tree) => DropdownMenuEntry(
                                      value: tree['uuid'].toString(),
                                      label: tree['tree_tag'] ?? 'Unnamed',
                                      leadingIcon: const Icon(
                                        Icons.park,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onSelected: (value) {
                                if (value == null) return;
                                setState(() => selectedTreeId = value);
                                try {
                                  final found = treeList.firstWhere(
                                      (t) => t['uuid'].toString() == value);
                                  treeController.text =
                                      found['tree_tag']?.toString() ?? '';
                                } catch (_) {
                                  treeController.text = '';
                                }
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: selectedTreeId == null
                                      ? null
                                      : () async {
                                          try {
                                            final position =
                                                await Geolocator
                                                    .getCurrentPosition(
                                              desiredAccuracy:
                                                  LocationAccuracy.high,
                                            );

                                            await TreeApi.addTreeLocation(
                                              treeUuid: selectedTreeId!,
                                              latitude: position.latitude,
                                              longitude: position.longitude,
                                            );

                                            if (mounted) {
                                              await Flushbar(
                                                message:
                                                    'Tree location saved successfully!',
                                                icon: const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white),
                                                backgroundColor:
                                                    Colors.green.shade700,
                                                duration:
                                                    const Duration(seconds: 2),
                                                margin:
                                                    const EdgeInsets.all(12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ).show(parentContext);
                                              Navigator.pop(dialogContext, true);
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              await Flushbar(
                                                message:
                                                    'Failed to save location',
                                                backgroundColor:
                                                    Colors.red.shade700,
                                                duration:
                                                    const Duration(seconds: 3),
                                                margin:
                                                    const EdgeInsets.all(12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ).show(parentContext);
                                              Navigator.pop(
                                                  dialogContext, false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.hunterGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        'Save',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomMarker(Map<String, dynamic> tree) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.hunterGreen,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            tree['tree_tag'] ?? 'Unknown',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 32,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialLocation = farmBounds.center;

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
              child: const Icon(Icons.map, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              "Farm Map",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.pakistanGreen,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          IconButton(
            key: const ValueKey('refresh_button'),
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTreeMarkers,
            tooltip: 'Refresh markers',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialLocation,
              initialZoom: 16,
              cameraConstraint: CameraConstraint.contain(bounds: farmBounds),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fyp_hbs',
                tileProvider: LocalOrNetworkTileProvider(),
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    // Current Location Marker with pulse effect
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 60,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Tree Markers
                    ...treesWithLocation.map((tree) {
                      final lat = double.tryParse(tree['latitude'].toString());
                      final lng =
                          double.tryParse(tree['longitude'].toString());
                      if (lat == null || lng == null) return null;

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 100,
                        height: 80,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TreeDetailsPage(treeID: tree['uuid']),
                              ),
                            );
                          },
                          child: _buildCustomMarker(tree),
                        ),
                      );
                    }).whereType<Marker>(),
                  ],
                ),
            ],
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

          // Attribution
          Positioned(
            right: 10,
            bottom: 80,
            child: GestureDetector(
              onTap: () {
                launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'));
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
      floatingActionButton: _fabAnimation != null
          ? ScaleTransition(
              scale: _fabAnimation!,
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final result = await _showAddTreeDialog();
                  if (result == true) {
                    _fetchTreeMarkers();
                  }
                },
                label: const Text(
                  'Add Tree',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                icon: const Icon(Icons.add_location_alt, color: Colors.white),
                backgroundColor: AppColors.hunterGreen,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await _showAddTreeDialog();
                if (result == true) {
                  _fetchTreeMarkers();
                }
              },
              label: const Text(
                'Add Tree',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              icon: const Icon(Icons.add_location_alt, color: Colors.white),
              backgroundColor: AppColors.hunterGreen,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
