import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onestay360/presentation/services/firestore_service.dart';

class QRScannerScreen extends StatefulWidget {
  final Function(Map<String, dynamic> tenantData)? onTenantScanned;

  const QRScannerScreen({
    super.key,
    this.onTenantScanned,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture barcodeCapture) async {
    if (_isProcessing) return;

    if (barcodeCapture.barcodes.isEmpty) return;
    final barcode = barcodeCapture.barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    final scannedData = barcode.rawValue!;
    HapticFeedback.mediumImpact();

    // Check if it's a valid tenant QR code
    if (!scannedData.startsWith('onestay360:tenant:')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR code. Please scan a tenant profile QR code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Extract tenantId from QR code
      final tenantId = scannedData.replaceFirst('onestay360:tenant:', '');
      
      if (tenantId.isEmpty) {
        throw Exception('Invalid tenant ID in QR code');
      }

      // Fetch tenant data from Firestore
      final tenantData = await _fetchTenantData(tenantId);

      if (tenantData == null) {
        throw Exception('Tenant not found');
      }

      // Stop scanner
      await _controller.stop();

      // Return tenant data
      if (mounted) {
        if (widget.onTenantScanned != null) {
          widget.onTenantScanned!(tenantData);
        }
        Navigator.pop(context, tenantData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchTenantData(String tenantId) async {
    try {
      // First, get tenant document from tenants collection
      final tenantDoc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (!tenantDoc.exists) {
        return null;
      }

      final tenantData = tenantDoc.data()!;

      // Also get user document for additional details
      final userId = tenantData['userId']?.toString();
      Map<String, dynamic>? userData;
      
      if (userId != null && userId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          userData = userDoc.data();
        }
      }

      // Merge tenant and user data
      return {
        ...tenantData,
        ...?userData,
        'tenantId': tenantId,
      };
    } catch (e) {
      print('Error fetching tenant data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Tenant QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Position the QR code within the frame',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

