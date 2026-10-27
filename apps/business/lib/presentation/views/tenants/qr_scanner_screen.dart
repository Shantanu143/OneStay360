// lib/presentation/views/tenants/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../design/components/biz_header.dart';
import '../../design/tokens.dart';
import 'qr_scan_viewmodel.dart';

/// The camera behind the scanner, so tests need not have one.
abstract class QrCamera {
  /// The live view; [onCode] is called for every code it reads.
  Widget view(ValueChanged<String> onCode);

  Future<void> toggleTorch();

  Future<void> switchCamera();

  Future<void> stop();

  void dispose();
}

class MobileQrCamera implements QrCamera {
  final MobileScannerController _controller = MobileScannerController();

  @override
  Widget view(ValueChanged<String> onCode) => MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          for (final b in capture.barcodes) {
            final raw = b.rawValue;
            if (raw != null && raw.isNotEmpty) return onCode(raw);
          }
        },
        errorBuilder: (context, error, _) => const _CameraUnavailable(),
      );

  @override
  Future<void> toggleTorch() => _controller.toggleTorch();

  @override
  Future<void> switchCamera() => _controller.switchCamera();

  @override
  Future<void> stop() => _controller.stop();

  @override
  void dispose() => _controller.dispose();
}

/// Scans a tenant's profile QR code. Pops with the tenant's details.
class TenantQrScannerScreen extends StatefulWidget {
  const TenantQrScannerScreen({super.key, this.camera, this.lookup});

  /// Test hooks. Defaults use the phone's camera and Firestore.
  final QrCamera? camera;
  final TenantLookup? lookup;

  @override
  State<TenantQrScannerScreen> createState() => _TenantQrScannerScreenState();
}

class _TenantQrScannerScreenState extends State<TenantQrScannerScreen> {
  late final QrCamera _camera = widget.camera ?? MobileQrCamera();
  late final QrScanViewModel _vm = QrScanViewModel(lookup: widget.lookup ?? FirestoreTenantLookup());

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _vm.dispose();
    _camera.dispose();
    super.dispose();
  }

  void _onChanged() {
    final tenant = _vm.found;
    if (tenant != null && mounted) {
      HapticFeedback.mediumImpact();
      _camera.stop();
      Navigator.of(context).pop(tenant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _camera.view(_vm.onCode),
          const IgnorePointer(child: _Frame()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const BizRoundButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    iconSize: 18,
                    tooltip: 'Back',
                    onTap: _noop,
                  ).copy(onTap: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  BizRoundButton(icon: Icons.flashlight_on_rounded, tooltip: 'Torch', onTap: _camera.toggleTorch),
                  const SizedBox(width: 10),
                  BizRoundButton(icon: Icons.cameraswitch_rounded, tooltip: 'Switch camera', onTap: _camera.switchCamera),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
            child: ListenableBuilder(
              listenable: _vm,
              builder: (context, _) => _HintCard(busy: _vm.busy, error: _vm.error),
            ),
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}

extension on BizRoundButton {
  BizRoundButton copy({required VoidCallback onTap}) => BizRoundButton(
        icon: icon,
        iconSize: iconSize,
        tooltip: tooltip,
        onTap: onTap,
        badgeCount: badgeCount,
        dark: dark,
        size: size,
      );
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.busy, required this.error});

  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: failed ? BizColors.dangerTint : BizColors.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(BizRadius.card),
      ),
      child: Row(
        children: [
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: BizColors.mint),
            )
          else
            Icon(
              failed ? Icons.error_outline_rounded : Icons.qr_code_scanner_rounded,
              color: failed ? BizColors.dangerInk : BizColors.mint,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              busy
                  ? 'Looking them up…'
                  : (error ?? "Point the camera at the QR code on the tenant's profile."),
              style: BizText.style(14, 500, color: failed ? BizColors.dangerInk : Colors.white, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four corner brackets around where the code should be.
class _Frame extends StatelessWidget {
  const _Frame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: CustomPaint(painter: _CornersPainter()),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BizColors.mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const arm = 38.0;
    const r = 22.0;
    void corner(double x, double y, double dx, double dy) {
      final path = Path()
        ..moveTo(x, y + dy * arm)
        ..lineTo(x, y + dy * r)
        ..quadraticBezierTo(x, y, x + dx * r, y)
        ..lineTo(x + dx * arm, y);
      canvas.drawPath(path, paint);
    }

    corner(0, 0, 1, 1);
    corner(size.width, 0, -1, 1);
    corner(0, size.height, 1, -1);
    corner(size.width, size.height, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'The camera is not available. Allow camera access in Settings, then try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }
}
