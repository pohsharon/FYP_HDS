import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart' as qr;
import 'package:torch_light/torch_light.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
// import 'package:google_mlkit_commons/google_mlkit_commons.dart';
// import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as mlkit;

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  qr.QRViewController? controller;
  bool isTorchOn = false;

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
      controller.pauseCamera();
      final uuid = scanData.code;

      if (uuid != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TreeDetailsPage(treeID: uuid)),
        );
      }
    });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Flashlight error: $e')));
    }
  }

  Future<void> _pickImageFromGallery() async {
  final picker = ImagePicker();
  final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery);
  if (pickedImage == null) return;
  else  ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image selected from gallery')),);

  // final inputImage = InputImage.fromFilePath(pickedImage.path);
  // final barcodeScanner = mlkit.BarcodeScanner(formats: [mlkit.BarcodeFormat.qrCode]);

  // try {
  //   final barcodes = await barcodeScanner.processImage(inputImage);
  //   if (barcodes.isNotEmpty) {
  //     final String? uuid = barcodes.first.rawValue;
  //     if (uuid != null) {
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(builder: (_) => TreeDetailsPage(treeID: uuid)),
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('QR code not recognized.')),
  //       );
  //     }
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('No QR code found in the image.')),
  //     );
  //   }
  // } catch (e) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(content: Text('Error scanning QR code: $e')),
  //   );
  // } finally {
  //   barcodeScanner.close();
  // }
}

  @override
  void dispose() {
    controller?.dispose();
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
