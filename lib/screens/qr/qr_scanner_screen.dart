// lib/screens/qr/qr_scanner_screen.dart
//
// Uses a SINGLE API call (POST /visitors/smart-scan) which:
//   - Looks up the QR token
//   - Auto checks-in  if status == Registered
//   - Auto checks-out if status == CheckedIn
//   - Returns what happened so we can show the right UI
//
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _cam = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final _tokenCtrl = TextEditingController();

  bool _processing   = false;
  bool _torchOn      = false;
  String?         _errorMsg;
  SmartScanResult? _result;

  @override
  void dispose() { _cam.dispose(); _tokenCtrl.dispose(); super.dispose(); }

  // ── Camera detect ─────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_processing || _result != null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _smartScan(raw);
  }

  // ── Manual entry ──────────────────────────────────────────
  void _onManualLookup() {
    final t = _tokenCtrl.text.trim();
    if (t.isEmpty) return;
    _smartScan(t);
  }

  // ── SINGLE API CALL: lookup + check-in/out ────────────────
  Future<void> _smartScan(String token, {String? remarks}) async {
    if (_processing) return;
    setState(() { _processing = true; _errorMsg = null; _result = null; });
    try {
      await _cam.stop();
      final result = await ApiService.smartScan(token, remarks: remarks);
      if (result.action == 'NotFound') {
        setState(() {
          _errorMsg = 'No visitor found for "$token"';
          _processing = false;
        });
        await _cam.start();
        return;
      }
      setState(() { _result = result; _processing = false; });
    } catch (e) {
      setState(() { _errorMsg = e.toString(); _processing = false; });
      await _cam.start();
    }
  }

  // ── If checked-out, optionally re-prompt for remarks ─────
  // (for manual checkout from result card after auto-checkout showed)
  // Actually smart-scan auto-acts, so this is just scan-again reset
  void _reset() {
    setState(() { _result = null; _errorMsg = null; _processing = false; });
    _tokenCtrl.clear();
    _cam.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          if (_result == null && !_processing)
            MobileScanner(controller: _cam, onDetect: _onDetect),

          // Viewfinder overlay
          if (_result == null && !_processing)
            _ScannerOverlay(
              torchOn: _torchOn,
              onToggleTorch: () { _cam.toggleTorch(); setState(() => _torchOn = !_torchOn); },
              onClose: () => Navigator.pop(context, _result != null),
            ),

          // Manual entry + error bar (always at bottom while scanning)
          if (_result == null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _ManualEntryBar(
                ctrl: _tokenCtrl, processing: _processing,
                errorMsg: _errorMsg, onLookup: _onManualLookup,
                onReset: _errorMsg != null ? _reset : null,
              ),
            ),

          // Result card (after smart scan completes)
          if (_result != null)
            _ResultCard(
              result: _result!,
              onScanAgain: _reset,
              onClose: () => Navigator.pop(context, true),
            ),

          // Loading spinner
          if (_processing && _result == null)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  SCANNER OVERLAY
// ─────────────────────────────────────────────────────────
class _ScannerOverlay extends StatelessWidget {
  final bool torchOn;
  final VoidCallback onToggleTorch, onClose;
  const _ScannerOverlay({required this.torchOn, required this.onToggleTorch, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.sizeOf(context);
    final boxSize = size.width < 500 ? size.width * 0.65 : 280.0;
    return Stack(children: [
      // Dark overlay with cutout
      CustomPaint(size: Size(size.width, size.height),
          painter: _OverlayPainter(boxSize: boxSize)),
      // Top bar
      SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _CircleBtn(icon: Icons.close_rounded, onTap: onClose),
          const Text('Scan QR Badge',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          _CircleBtn(
            icon: torchOn ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded,
            onTap: onToggleTorch, active: torchOn,
          ),
        ]),
      )),
      // Frame corners
      Center(child: SizedBox(width: boxSize, height: boxSize,
          child: _FrameCorners(size: boxSize))),
      // Hint
      Positioned(
        left: 0, right: 0,
        top: size.height / 2 + boxSize / 2 + 20,
        child: const Text('Point camera at visitor QR badge\nCheck-in or check-out happens automatically',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6)),
      ),
    ]);
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool active;
  const _CircleBtn({required this.icon, required this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.45),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: active ? AppTheme.primary : Colors.white, size: 20),
    ),
  );
}

class _OverlayPainter extends CustomPainter {
  final double boxSize;
  _OverlayPainter({required this.boxSize});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2; final h = boxSize / 2;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - h, cy - h, cx + h, cy + h),
          const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.55));
  }
  @override bool shouldRepaint(_OverlayPainter o) => o.boxSize != boxSize;
}

class _FrameCorners extends StatelessWidget {
  final double size;
  const _FrameCorners({required this.size});
  @override
  Widget build(BuildContext context) {
    Widget c(bool top, bool left) => Positioned(
      top: top ? 0 : null, bottom: top ? null : 0,
      left: left ? 0 : null, right: left ? null : 0,
      child: SizedBox(width: 36, height: 36,
          child: CustomPaint(painter: _CornerPainter(top: top, left: left))),
    );
    return Stack(children: [c(true,true), c(true,false), c(false,true), c(false,false)]);
  }
}

class _CornerPainter extends CustomPainter {
  final bool top, left;
  _CornerPainter({required this.top, required this.left});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppTheme.accent..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final x = left ? 0.0 : size.width; final y = top ? 0.0 : size.height;
    canvas.drawLine(Offset(x, y), Offset(x + (left ? 1 : -1) * 20, y), p);
    canvas.drawLine(Offset(x, y), Offset(x, y + (top ? 1 : -1) * 20), p);
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────
//  MANUAL ENTRY BAR
// ─────────────────────────────────────────────────────────
class _ManualEntryBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool processing;
  final String? errorMsg;
  final VoidCallback onLookup;
  final VoidCallback? onReset;
  const _ManualEntryBar({required this.ctrl, required this.processing,
      required this.errorMsg, required this.onLookup, this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        const Text('Or enter token manually',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'VMS-xxxxxxxx',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.qr_code, color: Colors.white38),
              filled: true, fillColor: Colors.white12,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (_) => onLookup(),
          )),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: processing ? null : onLookup,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary, minimumSize: const Size(80, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: processing
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Scan'),
          ),
        ]),
        if (errorMsg != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.statusError.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.statusError.withOpacity(0.35)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppTheme.statusError, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMsg!,
                  style: const TextStyle(color: AppTheme.statusError, fontSize: 13))),
              if (onReset != null)
                GestureDetector(onTap: onReset,
                    child: const Icon(Icons.refresh_rounded, color: AppTheme.statusError, size: 18)),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  RESULT CARD  — shows what the smart-scan did
// ─────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final SmartScanResult result;
  final VoidCallback onScanAgain;
  final VoidCallback onClose;
  const _ResultCard({required this.result, required this.onScanAgain, required this.onClose});

  Color get _color {
    switch (result.action) {
      case 'CheckedIn':  return AppTheme.statusIn;
      case 'CheckedOut': return AppTheme.statusOut;
      case 'AlreadyOut': return AppTheme.textMuted;
      default:           return AppTheme.statusWait;
    }
  }

  IconData get _actionIcon {
    switch (result.action) {
      case 'CheckedIn':  return Icons.login_rounded;
      case 'CheckedOut': return Icons.logout_rounded;
      case 'AlreadyOut': return Icons.check_circle_outline_rounded;
      default:           return Icons.info_outline_rounded;
    }
  }

  String get _actionLabel {
    switch (result.action) {
      case 'CheckedIn':  return 'Checked In';
      case 'CheckedOut': return 'Checked Out';
      case 'AlreadyOut': return 'Already Completed';
      default:           return result.action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localTime = result.eventTime.toLocal();
    final timeStr   = '${localTime.hour.toString().padLeft(2,'0')}:${localTime.minute.toString().padLeft(2,'0')}';

    return Container(
      color: Colors.black87,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: Colors.white,
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  // ── Colored action header ────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(gradient: LinearGradient(
                      colors: [_color.withOpacity(0.80), _color],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    )),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Action badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_actionIcon, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(_actionLabel,
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      // Name
                      Text(result.visitorName,
                          style: const TextStyle(color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      if (result.company != null)
                        Text(result.company!, style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      const SizedBox(height: 8),
                      // Time + duration
                      Row(children: [
                        const Icon(Icons.access_time_rounded, color: Colors.white70, size: 14),
                        const SizedBox(width: 5),
                        Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        if (result.durationMinutes != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                          const SizedBox(width: 5),
                          Text('${result.durationMinutes} min',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ]),
                    ]),
                  ),

                  // ── Details + actions ────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _DR(Icons.work_outline,    'Purpose', result.purpose),
                      const _DV(),
                      _DR(Icons.badge_outlined,  'Host', '${result.hostName} · ${result.hostDepartment}'),
                      const SizedBox(height: 6),

                      // Message from server
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: _color.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _color.withOpacity(0.2)),
                        ),
                        child: Text(result.message,
                            style: TextStyle(color: _color,
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ),

                      const SizedBox(height: 16),
                      // Buttons
                      Row(children: [
                        Expanded(child: FilledButton.icon(
                          onPressed: onScanAgain,
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: const Text('Scan Next'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary, minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        )),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: onClose,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                          child: const Icon(Icons.close_rounded),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DR extends StatelessWidget {
  final IconData icon; final String label, value;
  const _DR(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppTheme.textMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11,
            color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      ])),
    ]),
  );
}

class _DV extends StatelessWidget {
  const _DV();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Divider(height: 1, color: AppTheme.border),
  );
}