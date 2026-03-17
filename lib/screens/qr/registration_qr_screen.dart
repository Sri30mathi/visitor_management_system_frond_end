// lib/screens/qr/registration_qr_screen.dart
//
// Displays a large QR code at the reception desk.
// Visitors scan it with their phone to open the registration
// form directly in their mobile browser.
//
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';

class RegistrationQrScreen extends StatefulWidget {
  const RegistrationQrScreen({super.key});
  @override
  State<RegistrationQrScreen> createState() => _RegistrationQrScreenState();
}

class _RegistrationQrScreenState extends State<RegistrationQrScreen> {
  String? _qrBase64;
  String? _registrationUrl;
  bool    _loading = true;
  String? _error;
  Timer?  _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh QR every 5 minutes (URL doesn't change but keeps display live)
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getRegistrationQr();
      if (!mounted) return;
      if (data.isEmpty || data['qrImageBase64']!.isEmpty) {
        setState(() {
          _error   = 'Could not generate QR code.\nCheck API is running.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _qrBase64         = data['qrImageBase64'];
        _registrationUrl  = data['registrationUrl'];
        _loading          = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = 'Failed to load QR code.\n${e.toString()}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Visitor Self-Registration QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh QR',
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: AppTheme.primary)
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _load)
                : _QrDisplay(
                    qrBase64: _qrBase64!,
                    registrationUrl: _registrationUrl!,
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  QR Display
// ─────────────────────────────────────────────────────────────
class _QrDisplay extends StatelessWidget {
  final String qrBase64;
  final String registrationUrl;
  const _QrDisplay({
    required this.qrBase64,
    required this.registrationUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGrad,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.btnShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.how_to_reg_rounded,
                      color: Colors.white, size: 26),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visitor Registration',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                      SizedBox(height: 2),
                      Text('Scan to register your visit',
                        style: TextStyle(fontSize: 12,
                            color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── QR Code card ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(children: [
                // QR image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(qrBase64),
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),

                // Corner bracket decoration label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_android_rounded,
                        size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text('Scan with your phone camera',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500)),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Steps ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(children: [
                const Text('How it works',
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
                const SizedBox(height: 14),
                ...[
                  ['1', Icons.qr_code_scanner_rounded,
                   'Scan the QR code above with your phone camera'],
                  ['2', Icons.open_in_browser_rounded,
                   'Registration form opens in your mobile browser'],
                  ['3', Icons.edit_note_rounded,
                   'Fill in your name, mobile, purpose and host'],
                  ['4', Icons.check_circle_outline_rounded,
                   'Submit — security will confirm your entry'],
                ].map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGrad,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(s[0] as String,
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
                    ),
                    const SizedBox(width: 12),
                    Icon(s[1] as IconData,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s[2] as String,
                      style: const TextStyle(fontSize: 12,
                          color: AppTheme.textSecondary))),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // ── URL label ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded,
                      size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Flexible(child: Text(registrationUrl,
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Error view
// ─────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.qr_code_2_rounded,
          size: 56, color: AppTheme.textMuted),
      const SizedBox(height: 16),
      Text(error,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 14, color: AppTheme.textSecondary)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try Again'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}