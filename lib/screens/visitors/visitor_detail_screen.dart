// lib/screens/visitors/visitor_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';

class VisitorDetailScreen extends StatefulWidget {
  final String entryId;
  const VisitorDetailScreen({super.key, required this.entryId});
  @override
  State<VisitorDetailScreen> createState() => _State();
}

class _State extends State<VisitorDetailScreen> {
  VisitorEntryDetailDto? _e;
  String? _qrBase64;          // base64 PNG from API
  bool _loading    = true;
  bool _qrLoading  = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final e = await ApiService.getVisitorById(widget.entryId);
      if (!mounted) return;
      setState(() { _e = e; _loading = false; });
      // Auto-fetch QR for active visitors
      if (e.status == 'Registered' || e.status == 'CheckedIn') {
        _fetchQr();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _fetchQr() async {
    setState(() => _qrLoading = true);
    try {
      final b64 = await ApiService.getQrCodeImage(widget.entryId);
      if (mounted) setState(() { _qrBase64 = b64; _qrLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _qrLoading = false);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(m, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: c, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ),
  );

  Future<void> _checkIn() async {
    try {
      await ApiService.checkIn(widget.entryId);
      _snack('Checked in ✓', AppTheme.statusIn);
      _load();
    } on ApiException catch (e) { _snack(e.message, AppTheme.statusError); }
  }

  Future<void> _checkOut() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Check Out', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Check out ${_e?.visitorName}?'),
          const SizedBox(height: 12),
          TextField(controller: ctrl,
              decoration: const InputDecoration(hintText: 'Remarks (optional)'),
              maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.statusWait,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final resp = await ApiService.checkOut(widget.entryId,
          remarks: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
      _snack('Checked out • ${resp.durationMinutes ?? 0} min', AppTheme.statusWait);
      _load();
    } on ApiException catch (e) { _snack(e.message, AppTheme.statusError); }
  }

  // Show QR full-screen dialog for easy scanning at reception desk
  void _showQrDialog() {
    if (_qrBase64 == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_e!.visitorName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            if (_e!.company != null) ...[
              const SizedBox(height: 4),
              Text(_e!.company!, style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 20),
            // Large QR image
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 1.5),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Image.memory(
                base64Decode(_qrBase64!),
                width: 220, height: 220, fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.qr_code_2_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(_e!.qrToken ?? '', style: const TextStyle(
                    fontSize: 12, color: AppTheme.primary,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
              _e!.status == 'Registered'
                  ? 'Scan to check in'
                  : 'Scan to check out',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                child: const Text('Close'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_e?.visitorName ?? 'Visitor Detail'),
        actions: [
          if (_e != null &&
              (_e!.status == 'Registered' || _e!.status == 'CheckedIn') &&
              _qrBase64 != null)
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded),
              tooltip: 'Show QR Badge',
              onPressed: _showQrDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _Body(
                  e: _e!, r: r,
                  qrBase64: _qrBase64,
                  qrLoading: _qrLoading,
                  onShowQr: _showQrDialog,
                ),
      bottomNavigationBar: _actionBar(r),
    );
  }

  Widget? _actionBar(Responsive r) {
    if (_e == null) return null;
    if (_e!.status == 'Registered') return _ActionBar(
        label: 'Check In', icon: Icons.how_to_reg_rounded,
        color: AppTheme.statusIn, r: r, onTap: _checkIn);
    if (_e!.status == 'CheckedIn') return _ActionBar(
        label: 'Check Out', icon: Icons.logout_rounded,
        color: AppTheme.statusWait, r: r, onTap: _checkOut);
    return null;
  }
}

// ─────────────────────────────────────────────────────────
//  BODY
// ─────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final VisitorEntryDetailDto e;
  final Responsive r;
  final String? qrBase64;
  final bool qrLoading;
  final VoidCallback onShowQr;
  const _Body({required this.e, required this.r,
      this.qrBase64, required this.qrLoading, required this.onShowQr});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy • h:mm a');
    final sc  = AppTheme.statusColor(e.status);
    final canScan = e.status == 'Registered' || e.status == 'CheckedIn';

    // ── Hero card (avatar + QR badge side by side) ─────────
    final hero = AppCard(
      padding: EdgeInsets.all(r.cardPadding + 4),
      child: canScan
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left: avatar + name
              Expanded(child: _HeroInfo(e: e, sc: sc)),
              const SizedBox(width: 16),
              // Right: QR code
              _QrPanel(
                qrBase64: qrBase64,
                loading: qrLoading,
                qrToken: e.qrToken,
                status: e.status,
                onTap: onShowQr,
              ),
            ])
          : _HeroInfo(e: e, sc: sc, centered: true),
    );

    final details = AppCard(
      child: Column(children: [
        _Row(Icons.phone_outlined,    'Mobile',     e.mobile ?? '—'),
        if (e.email != null) _Row(Icons.email_outlined, 'Email', e.email!),
        _Row(Icons.work_outline,      'Purpose',    e.purpose),
        const _Hr(),
        _Row(Icons.person_outline,    'Host',       e.hostName),
        _Row(Icons.business_outlined, 'Department', e.hostDepartment),
        if (e.hostPhone != null) _Row(Icons.phone_outlined, 'Host Phone', e.hostPhone!),
        const _Hr(),
        _Row(Icons.event_outlined,    'Visit Date', fmt.format(e.visitDateTime.toLocal())),
        if (e.checkInTime  != null)
          _Row(Icons.login_rounded,  'Check In',  fmt.format(e.checkInTime!.toLocal())),
        if (e.checkOutTime != null)
          _Row(Icons.logout_rounded, 'Check Out', fmt.format(e.checkOutTime!.toLocal())),
        if (e.idType != null) ...[
          const _Hr(),
          _Row(Icons.credit_card_outlined, 'ID Type', e.idType!),
          if (e.idNumber != null) _Row(Icons.numbers_outlined, 'ID Number', e.idNumber!),
        ],
        if (e.remarks != null) ...[const _Hr(), _Row(Icons.notes_outlined, 'Remarks', e.remarks!)],
      ]),
    );

    final timeline = e.events.isEmpty ? null : AppCard(
      padding: EdgeInsets.all(r.cardPadding),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Timeline', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 14),
        ...e.events.asMap().entries.map((entry) {
          final ev = entry.value; final last = entry.key == e.events.length - 1;
          final c  = ev.eventType == 'CheckIn'  ? AppTheme.statusIn
              : ev.eventType == 'CheckOut' ? AppTheme.statusWait : AppTheme.primary;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(_evIcon(ev.eventType), size: 15, color: c)),
              if (!last) Container(width: 2, height: 28, color: AppTheme.border),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ev.eventType, style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: c)),
                Text(fmt.format(ev.eventTime.toLocal()),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                if (ev.notes != null) Text(ev.notes!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ]),
            )),
          ]);
        }),
      ]),
    );

    final content = r.isWide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: r.isDesktop ? 320 : 280, child: hero),
            SizedBox(width: r.sectionGap),
            Expanded(child: Column(children: [
              details,
              if (timeline != null) ...[SizedBox(height: r.itemGap), timeline],
            ])),
          ])
        : Column(children: [
            hero, SizedBox(height: r.itemGap), details,
            if (timeline != null) ...[SizedBox(height: r.itemGap), timeline],
            const SizedBox(height: 80),
          ]);

    return SingleChildScrollView(
        padding: EdgeInsets.all(r.pagePadding), child: content);
  }

  IconData _evIcon(String t) => t == 'CheckIn' ? Icons.login_rounded
      : t == 'CheckOut' ? Icons.logout_rounded : Icons.app_registration_rounded;
}

// ─────────────────────────────────────────────────────────
//  HERO INFO  (name + badge + duration)
// ─────────────────────────────────────────────────────────
class _HeroInfo extends StatelessWidget {
  final VisitorEntryDetailDto e;
  final Color sc;
  final bool centered;
  const _HeroInfo({required this.e, required this.sc, this.centered = false});

  @override
  Widget build(BuildContext context) {
    final align = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(crossAxisAlignment: align, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(
          color: sc.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(child: Text(e.visitorName[0].toUpperCase(),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: sc)))),
      const SizedBox(height: 12),
      Text(e.visitorName, textAlign: centered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary, letterSpacing: -0.4)),
      if (e.company != null) ...[
        const SizedBox(height: 4),
        Text(e.company!, textAlign: centered ? TextAlign.center : TextAlign.start,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
      const SizedBox(height: 12),
      StatusBadge(e.status),
      if (e.durationMinutes != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.timer_outlined, size: 12, color: AppTheme.primary),
            const SizedBox(width: 5),
            Text('${e.durationMinutes} min visit',
                style: const TextStyle(fontSize: 11, color: AppTheme.primary,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  QR PANEL  — small QR thumbnail + "Expand" tap
// ─────────────────────────────────────────────────────────
class _QrPanel extends StatelessWidget {
  final String? qrBase64;
  final bool loading;
  final String? qrToken;
  final String status;
  final VoidCallback onTap;
  const _QrPanel({this.qrBase64, required this.loading,
      this.qrToken, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final actionLabel = status == 'Registered' ? 'Scan to\nCheck In' : 'Scan to\nCheck Out';
    final color = status == 'Registered' ? AppTheme.statusIn : AppTheme.statusWait;

    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      GestureDetector(
        onTap: qrBase64 != null ? onTap : null,
        child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4), width: 2),
            boxShadow: [BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 12, offset: const Offset(0, 4),
            )],
          ),
          child: loading
              ? const Center(child: SizedBox(width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5,
                      color: AppTheme.primary)))
              : qrBase64 != null
                  ? Stack(alignment: Alignment.bottomRight, children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.memory(
                          base64Decode(qrBase64!),
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Expand icon hint
                      Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.fullscreen_rounded, size: 14, color: color),
                      ),
                    ])
                  : Center(child: Icon(Icons.qr_code_2_rounded,
                      size: 40, color: AppTheme.textMuted)),
        ),
      ),
      const SizedBox(height: 8),
      Text(actionLabel, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, height: 1.4)),
      if (qrToken != null) ...[
        const SizedBox(height: 4),
        Text(qrToken!, style: const TextStyle(
            fontSize: 9, color: AppTheme.textMuted, letterSpacing: 0.3)),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final IconData icon; final String label, value;
  const _Row(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(children: [
      Icon(icon, size: 16, color: AppTheme.textMuted),
      const SizedBox(width: 12),
      SizedBox(width: 96, child: Text(label, style: const TextStyle(
          fontSize: 12, color: AppTheme.textSecondary))),
      Expanded(child: Text(value, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
    ]),
  );
}

class _Hr extends StatelessWidget {
  const _Hr();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppTheme.border, indent: 44);
}

class _ActionBar extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final Responsive r; final VoidCallback onTap;
  const _ActionBar({required this.label, required this.icon,
      required this.color, required this.r, required this.onTap});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.all(r.pagePadding),
      child: SizedBox(
        height: r.buttonHeight,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label, style: TextStyle(
              fontSize: r.bodyFontSize + 1, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: AppTheme.r12),
          ),
        ),
      ),
    ),
  );
}