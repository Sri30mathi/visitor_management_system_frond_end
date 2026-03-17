// lib/screens/visitors/visitor_form_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';

class VisitorFormScreen extends StatefulWidget {
  const VisitorFormScreen({super.key});
  @override
  State<VisitorFormScreen> createState() => _State();
}

class _State extends State<VisitorFormScreen> {
  final _fk   = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mob  = TextEditingController();
  final _em   = TextEditingController();
  final _co   = TextEditingController();
  final _idn  = TextEditingController();

  String? _hostId, _purpose, _idType;
  bool _walkIn = true, _busy = false, _loadingHosts = true;
  DateTime  _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  List<HostDto> _hosts = [];

  // Returning visitor state
  bool _checkingMobile       = false;
  ActiveVisitResponse? _activeVisit;
  Timer? _debounce;

  @override
  void initState() { super.initState(); _loadHosts(); }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose(); _mob.dispose(); _em.dispose();
    _co.dispose(); _idn.dispose(); super.dispose();
  }

  Future<void> _loadHosts() async {
    try {
      final r = await ApiService.getHosts(isActive: true, pageSize: 100);
      if (mounted) setState(() { _hosts = r.items; _loadingHosts = false; });
    } catch (_) { if (mounted) setState(() => _loadingHosts = false); }
  }

  // ── Show self-registration QR in a dialog ────────────
  Future<void> _showRegistrationQr(BuildContext context) async {
    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final data = await ApiService.getRegistrationQr();
      if (!mounted) return;
      Navigator.pop(context); // close loader

      if (data.isEmpty || (data['qrImageBase64'] ?? '').isEmpty) {
        _snack('Could not generate QR. Check API is running.',
            AppTheme.statusError);
        return;
      }

      final qrBytes = base64Decode(data['qrImageBase64']!);
      final url     = data['registrationUrl'] ?? '';

      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Title
              Row(children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Self-Registration QR',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 16),

              // QR image
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Image.memory(qrBytes,
                    width: 200, height: 200, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),

              // Instruction
              const Text('Visitor scans this QR with their phone\nto open the registration form',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12,
                    color: AppTheme.textSecondary)),
              const SizedBox(height: 8),

              // URL
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(url,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textMuted,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      final msg = e is ApiException ? e.message : 'Failed to load QR. Is the API running?';
      _snack(msg, AppTheme.statusError);
    }
  }

  // ── QR scan to pre-fill form ─────────────────────────────

  void _onMobileChanged(String value) {
    final mobile = value.trim();
    _debounce?.cancel();
    if (mobile.length < 10) {
      if (_activeVisit != null || _checkingMobile) {
        setState(() { _activeVisit = null; _checkingMobile = false; });
      }
      return;
    }
    // Debounce 600ms so we only call API when user stops typing
    setState(() { _checkingMobile = true; _activeVisit = null; });
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final result = await ApiService.checkMobile(mobile);
        if (mounted) setState(() { _activeVisit = result; _checkingMobile = false; });
      } catch (_) {
        if (mounted) setState(() => _checkingMobile = false);
      }
    });
  }

  // Called at submit time — re-checks mobile fresh to catch any race condition
  Future<bool> _checkMobileBeforeSubmit() async {
    final mobile = _mob.text.trim();
    if (mobile.length < 10) return true;
    try {
      final result = await ApiService.checkMobile(mobile);
      if (mounted) setState(() => _activeVisit = result);
      return result == null; // true = safe to proceed
    } catch (_) {
      return true; // on error, allow submit
    }
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    if (_hostId == null) { _snack('Please select a host', AppTheme.statusError); return; }
    // Re-check mobile fresh at submit time (catches race conditions & paste scenarios)
    setState(() => _busy = true);
    final safe = await _checkMobileBeforeSubmit();
    if (!safe) {
      setState(() => _busy = false);
      _snack('This visitor already has an active visit — cannot register again',
          Colors.orange.shade700);
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.createVisitor(
        visitorName:   _name.text.trim(),
        mobile:        _mob.text.trim(),
        email:         _em.text.trim().isEmpty ? null : _em.text.trim(),
        company:       _co.text.trim().isEmpty ? null : _co.text.trim(),
        purpose:       _purpose!,
        hostId:        _hostId!,
        idType:        _idType,
        idNumber:      _idn.text.trim().isEmpty ? null : _idn.text.trim(),
        isWalkIn:      _walkIn,
        visitDateTime: _walkIn ? null : DateTime(
            _date.year, _date.month, _date.day, _time.hour, _time.minute),
      );
      if (mounted) {
        _snack('Visitor registered', AppTheme.statusIn);
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) { setState(() => _busy = false); _snack(e.message, AppTheme.statusError); }
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
    backgroundColor: c, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(12),
  ));

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Register Visitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Show Registration QR',
            onPressed: () => _showRegistrationQr(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loadingHosts
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.formMaxWidth),
                child: Form(key: _fk, child: ListView(
                  padding: EdgeInsets.all(r.pagePadding),
                  children: [

                    _Section(num: '01', title: 'Visitor Information', child: Column(children: [
                      _row(r,
                        _tf(_name, 'Full Name', Icons.badge_outlined, req: true,
                            caps: TextCapitalization.words),
                        TextFormField(
                          controller: _mob,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Mobile Number *',
                            prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                            suffixIcon: _checkingMobile
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2,
                                          color: AppTheme.primary)))
                                : _activeVisit != null
                                    ? const Icon(Icons.warning_amber_rounded,
                                        color: Colors.orange)
                                    : null,
                          ),
                          validator: (v) => v == null || v.trim().length < 10
                              ? 'Enter valid mobile' : null,
                          onChanged: _onMobileChanged,
                          onEditingComplete: () {
                            _debounce?.cancel();
                            _onMobileChanged(_mob.text);
                          },
                        ),
                      ),
                      SizedBox(height: r.itemGap),
                      _row(r,
                        _tf(_em, 'Email (optional)', Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            val: (v) => v != null && v.isNotEmpty && !v.contains('@')
                                ? 'Invalid email' : null),
                        _tf(_co, 'Company (optional)', Icons.business_outlined,
                            caps: TextCapitalization.words)),
                    ])),
                    SizedBox(height: r.itemGap),

                    // Active visit blocker card
                    if (_activeVisit != null) ...[
                      _ActiveVisitCard(
                        visit: _activeVisit!,
                        onViewVisit: () => Navigator.pushNamed(
                          context,
                          '/visitors/${_activeVisit!.entryId}',
                        ).then((_) => setState(() => _activeVisit = null)),
                      ),
                      SizedBox(height: r.itemGap),
                    ],

                    _Section(num: '02', title: 'Visit Details', child: Column(children: [
                      _row(r,
                        DropdownButtonFormField<String>(
                          value: _purpose,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                          decoration: const InputDecoration(labelText: 'Purpose *',
                              prefixIcon: Icon(Icons.work_outline_rounded, size: 18)),
                          items: AppConstants.purposes.map((p) =>
                              DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (v) => setState(() => _purpose = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: _hostId, isExpanded: true,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                          decoration: const InputDecoration(labelText: 'Host to Meet *',
                              prefixIcon: Icon(Icons.person_pin_outlined, size: 18)),
                          items: _hosts.map((h) => DropdownMenuItem(value: h.hostId,
                              child: Text('${h.name} — ${h.department}',
                                  overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _hostId = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                      SizedBox(height: r.itemGap),
                      Container(
                        decoration: BoxDecoration(color: AppTheme.surface,
                            borderRadius: AppTheme.r12,
                            border: Border.all(color: AppTheme.border)),
                        child: SwitchListTile(
                          title: const Text('Walk-in visit', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary)),
                          subtitle: Text(_walkIn ? 'Visiting right now' : 'Scheduled',
                              style: const TextStyle(fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          value: _walkIn, activeColor: AppTheme.primary,
                          onChanged: (v) => setState(() => _walkIn = v),
                        ),
                      ),
                      if (!_walkIn) ...[
                        SizedBox(height: r.itemGap),
                        Row(children: [
                          Expanded(child: _DateBtn(
                              label: '${_date.day}/${_date.month}/${_date.year}',
                              icon: Icons.calendar_today_rounded,
                              onTap: () async {
                                final p = await showDatePicker(context: context,
                                    initialDate: _date,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 30)));
                                if (p != null) setState(() => _date = p);
                              })),
                          SizedBox(width: r.itemGap),
                          Expanded(child: _DateBtn(
                              label: _time.format(context),
                              icon: Icons.access_time_rounded,
                              onTap: () async {
                                final p = await showTimePicker(
                                    context: context, initialTime: _time);
                                if (p != null) setState(() => _time = p);
                              })),
                        ]),
                      ],
                    ])),
                    SizedBox(height: r.itemGap),

                    _Section(num: '03', title: 'ID Verification', tag: 'Optional',
                        child: Column(children: [
                          _row(r,
                            DropdownButtonFormField<String>(
                              value: _idType,
                              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                              decoration: const InputDecoration(labelText: 'ID Type',
                                  prefixIcon: Icon(Icons.credit_card_outlined, size: 18)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('None')),
                                ...AppConstants.idTypes.map((t) =>
                                    DropdownMenuItem(value: t, child: Text(t))),
                              ],
                              onChanged: (v) => setState(() => _idType = v),
                            ),
                            _idType != null
                                ? _tf(_idn, 'ID Number', Icons.numbers_outlined)
                                : const SizedBox(),
                          ),
                        ])),
                    SizedBox(height: r.sectionGap),

                    if (_activeVisit != null)
                      Container(
                        height: r.buttonHeight,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: AppTheme.r12,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Registration blocked — active visit exists',
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500),
                        ),
                      )
                    else
                      GradientButton(
                        label: _busy ? 'Registering…' : 'Register Visitor',
                        icon: Icons.how_to_reg_rounded,
                        onTap: _busy ? null : _submit,
                        loading: _busy,
                        height: r.buttonHeight,
                      ),
                    SizedBox(height: r.sectionGap),
                  ],
                )),
              ),
            ),
    );
  }

  Widget _row(Responsive r, Widget a, Widget b) => r.isDesktop
      ? Row(children: [Expanded(child: a), SizedBox(width: r.itemGap), Expanded(child: b)])
      : Column(children: [a, SizedBox(height: r.itemGap), b]);

  Widget _tf(TextEditingController c, String label, IconData icon, {
    bool req = false,
    TextInputType type = TextInputType.text,
    TextCapitalization caps = TextCapitalization.none,
    String? Function(String?)? val,
  }) => TextFormField(
    controller: c, keyboardType: type, textCapitalization: caps,
    style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
    decoration: InputDecoration(
        labelText: req ? '$label *' : label, prefixIcon: Icon(icon, size: 18)),
    validator: val ?? (req ? (v) =>
        (v == null || v.trim().isEmpty) ? '$label is required' : null : null),
  );
}

// ─────────────────────────────────────────────────────────────
//  Active Visit Blocker Card
// ─────────────────────────────────────────────────────────────
class _ActiveVisitCard extends StatelessWidget {
  final ActiveVisitResponse visit;
  final VoidCallback onViewVisit;
  const _ActiveVisitCard({required this.visit, required this.onViewVisit});

  @override
  Widget build(BuildContext context) {
    final statusColor = visit.status == 'CheckedIn'
        ? AppTheme.statusIn : AppTheme.statusWait;
    final statusLabel = visit.status == 'CheckedIn'
        ? 'Currently Inside' : 'Awaiting Check-In';
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.r16,
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
          ),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Active Visit Found — Cannot Register Again',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(statusLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: statusColor)),
            ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(visit.visitorName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                  if (visit.company != null) ...[
                    const SizedBox(height: 2),
                    Text(visit.company!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGrad,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  visit.totalVisits == 1 ? 'First visit' : '${visit.totalVisits}× visited',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 10),
            _Row(Icons.person_pin_outlined,
                '${visit.hostName} — ${visit.hostDepartment}'),
            _Row(Icons.work_outline_rounded, visit.purpose),
            _Row(Icons.access_time_rounded,
                fmt.format(visit.visitDateTime.toLocal())),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewVisit,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('View Existing Visit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.r12),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon; final String text;
  const _Row(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Icon(icon, size: 14, color: AppTheme.textMuted),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12,
          color: AppTheme.textSecondary))),
    ]),
  );
}

class _DateBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _DateBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 15),
    label: Text(label, style: const TextStyle(fontSize: 13)),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 46),
      foregroundColor: AppTheme.textPrimary,
      side: const BorderSide(color: AppTheme.border),
      shape: RoundedRectangleBorder(borderRadius: AppTheme.r12),
    ),
  );
}

class _Section extends StatelessWidget {
  final String num, title; final String? tag; final Widget child;
  const _Section({required this.num, required this.title, required this.child, this.tag});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: AppTheme.r16,
        border: Border.all(color: AppTheme.border), boxShadow: AppTheme.cardShadow),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(color: AppTheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: const Border(bottom: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          Container(width: 26, height: 26,
            decoration: BoxDecoration(gradient: AppTheme.brandGrad,
                borderRadius: BorderRadius.circular(7)),
            child: Center(child: Text(num, style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
          if (tag != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.textMuted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(tag!, style: const TextStyle(fontSize: 10,
                  color: AppTheme.textMuted, fontWeight: FontWeight.w500))),
          ],
        ]),
      ),
      Padding(padding: const EdgeInsets.all(16), child: child),
    ]),
  );
}