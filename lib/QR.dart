import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart' as qr;
import 'package:torch_light/torch_light.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:qr_code_tools/qr_code_tools.dart'; 
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/services/local database/fruit_db.dart';
import 'package:fyp_hbs/services/local database/tree_db.dart';
import 'package:fyp_hbs/fruit/fruit_list.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  qr.QRViewController? controller;
  bool isTorchOn = false;
  bool _isProcessingQR = false;  // Prevent duplicate scans
  late List<dynamic> _cachedTrees;
  late List<dynamic> _cachedFruits;

  @override
  void initState() {
    super.initState();
    _preloadDatabases();
  }

  Future<void> _preloadDatabases() async {
    try {
      // Preload databases to avoid slow first scan
      _cachedTrees = await TreeDB().fetchAllTrees();
      _cachedFruits = await FruitDB().getAllFruits();
      // print('✅ [DB PRELOAD] Databases preloaded: ${_cachedTrees.length} trees, ${_cachedFruits.length} fruits');
    } catch (e) {
      print('⚠️ [DB PRELOAD ERROR] Failed to preload databases: $e');
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  void _onQRViewCreated(qr.QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      // Prevent processing multiple scans of the same QR code
      if (_isProcessingQR) return;
      
      final uuid = scanData.code;
      if (uuid != null && uuid.isNotEmpty) {
        _isProcessingQR = true;
        controller.pauseCamera();
        _handleScannedUUID(uuid);
      }
    });
  }

  Future<void> _handleScannedUUID(String scannedData) async {
    final scanTime = DateTime.now();
    
    // Extract UUID from URL if scanned data contains domain
    String uuid = scannedData;
    if (scannedData.contains('http://') || scannedData.contains('https://')) {
      // Extract UUID from URL (last segment)
      // Format: https://domain.com/product-details/uuid
      try {
        final uri = Uri.parse(scannedData);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          uuid = pathSegments.last;
          print('🔗 [URL PARSED] Extracted UUID: $uuid from URL: $scannedData');
        }
      } catch (e) {
        print('⚠️ [URL PARSE ERROR] Could not parse URL: $e');
        if (mounted) {
          await Flushbar(
            message: '❌ Invalid QR code format',
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(8),
          ).show(context);
        }
        return;
      }
    }
    
    // print('🔍 [QR SCAN] Scanned at ${scanTime.toIso8601String()} - UUID: $uuid');
    
    try {
      // First, check if this UUID is a tree (using cached database)
      final validationStartTime = DateTime.now();
      // print('🔎 [VALIDATION START] Tree database search started at ${validationStartTime.toIso8601String()}');
      
      final treeIndex = _cachedTrees.indexWhere((t) => t.uuid == uuid);

      if (treeIndex >= 0 && mounted) {
        // Found in tree database - navigate to tree details
        final foundTime = DateTime.now();
        final searchDuration = foundTime.difference(validationStartTime).inMilliseconds;
        // print('✅ [TREE FOUND] Found in tree database after ${searchDuration}ms at ${foundTime.toIso8601String()}');
        
        final navigationTime = DateTime.now();
        // print('🚀 [NAVIGATION START] Navigating to TreeDetailsPage at ${navigationTime.toIso8601String()}');
        
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TreeDetailsPage(treeID: uuid)),
          );
        }
        
        final navigationCompleteTime = DateTime.now();
        final navigationDuration = navigationCompleteTime.difference(navigationTime).inMilliseconds;
        // print('✅ [NAVIGATION COMPLETE] Directed to tree details in ${navigationDuration}ms at ${navigationCompleteTime.toIso8601String()}');
        // print('📊 [TOTAL TIME] From scan to navigation: ${navigationCompleteTime.difference(scanTime).inMilliseconds}ms');
        return;
      }

      // Second, check if this UUID is a fruit (using cached database)
      final fruitSearchStart = DateTime.now();
      // print('🔎 [VALIDATION CONTINUE] Fruit database search started at ${fruitSearchStart.toIso8601String()}');
      
      // Check only the fruit's own uuid field
      final fruitIndex = _cachedFruits.indexWhere((f) => f.uuid == uuid);

      if (fruitIndex >= 0 && mounted) {
        // Found in fruit database - navigate to FruitList and show details
        final foundTime = DateTime.now();
        final searchDuration = foundTime.difference(fruitSearchStart).inMilliseconds;
        // print('✅ [FRUIT FOUND] Found in fruit database after ${searchDuration}ms at ${foundTime.toIso8601String()}');
        
        final foundFruit = _cachedFruits[fruitIndex];
        final navigationTime = DateTime.now();
        // print('🚀 [NAVIGATION START] Navigating to FruitListFromQR at ${navigationTime.toIso8601String()}');
        
        // if (mounted) {
        //   await Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (_) => FruitListFromQR(fruitUuid: foundFruit.uuid ?? uuid),
        //     ),
        //   );
        // }
        
        final navigationCompleteTime = DateTime.now();
        final navigationDuration = navigationCompleteTime.difference(navigationTime).inMilliseconds;
        // print('✅ [NAVIGATION COMPLETE] Directed to fruit details in ${navigationDuration}ms at ${navigationCompleteTime.toIso8601String()}');
        // print('📊 [TOTAL TIME] From scan to navigation: ${navigationCompleteTime.difference(scanTime).inMilliseconds}ms');
        return;
      }

      // UUID not found in either database
      final notFoundTime = DateTime.now();
      final totalValidationTime = notFoundTime.difference(validationStartTime).inMilliseconds;
      // print('❌ [NOT FOUND] UUID not found in any database after ${totalValidationTime}ms at ${notFoundTime.toIso8601String()}');
      
      if (mounted) {
        await Flushbar(
          message: '❌ QR code not found in database',
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(8),
        ).show(context);
      }
    } catch (e) {
      final errorTime = DateTime.now();
      print('❌ [ERROR] Exception at ${errorTime.toIso8601String()}: $e');
      debugPrint('Error handling scanned UUID: $e');
      if (mounted) {
        await Flushbar(
          message: '❌ Error scanning QR code: ${e.toString().split('\n').first}',
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(8),
        ).show(context);
      }
    } finally {
      // Keep the flag locked for a longer duration to prevent duplicate navigations
      // especially when navigation happens
      await Future.delayed(const Duration(milliseconds: 800));
      _isProcessingQR = false;
      // Resume camera for next scan
      if (mounted && controller != null) {
        controller!.resumeCamera();
      }
    }
  }
  

  Future<void> _toggleFlashlight() async {
    try {
      if (isTorchOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() {
        isTorchOn = !isTorchOn;
      });
    } catch (e) {
      await Flushbar(
        message: 'Flashlight error: $e',
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(8),
      ).show(context);
    }
  }

Future<void> _pickImageFromGallery() async {
  try {
    final picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage == null) {
      debugPrint('No image selected.');
      return;
    }

    String? result = await QrCodeToolsPlugin.decodeFrom(pickedImage.path);
  
    if (result != null && result.isNotEmpty) {
      await _handleScannedUUID(result);
    } else {
      await Flushbar(
        message: 'No QR code found in image.',
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(8),
      ).show(context);
    }
  } catch (e) {
    debugPrint('Error decoding QR: $e');
    await Flushbar(
      message: '❌ Error decoding QR: $e',
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(8),
    ).show(context);
  }
}

@override
void dispose() {
  // Only call dispose on controllers you actually defined.
  // Example: textController?.dispose();
  super.dispose();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          qr.QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: qr.QrScannerOverlayShape(
              borderColor: Colors.green,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleFlashlight,
                  icon: Icon(isTorchOn ? Icons.flash_off : Icons.flash_on),
                  label: Text(isTorchOn ? 'Flash Off' : 'Flash On'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.image),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
