// lib/screens/visitors/visitor_form_screen.dart
import 'package:flutter/material.dart';
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

  @override
  void initState() { super.initState(); _loadHosts(); }
  @override
  void dispose() {
    _name.dispose(); _mob.dispose(); _em.dispose();
    _co.dispose(); _idn.dispose(); super.dispose();
  }

  Future<void> _loadHosts() async {
    try {
      final r = await ApiService.getHosts(isActive: true, pageSize: 100);
      if (mounted) setState(() { _hosts = r.items; _loadingHosts = false; });
    } catch (_) { if (mounted) setState(() => _loadingHosts = false); }
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    if (_hostId == null) { _snack('Please select a host', AppTheme.statusError); return; }
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
        _snack('Visitor registered ✓', AppTheme.statusIn);
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
      appBar: AppBar(title: const Text('Register Visitor')),
      body: _loadingHosts
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.formMaxWidth),
                child: Form(key: _fk, child: ListView(
                  padding: EdgeInsets.all(r.pagePadding),
                  children: [
                    _Section(num: '01', title: 'Visitor Information', child: Column(children: [
                      _row(r, _tf(_name, 'Full Name', Icons.badge_outlined, req: true,
                              caps: TextCapitalization.words),
                          _tf(_mob, 'Mobile Number', Icons.phone_outlined, req: true,
                              type: TextInputType.phone,
                              val: (v) => v == null || v.trim().length < 10 ? 'Enter valid mobile' : null)),
                      SizedBox(height: r.itemGap),
                      _row(r, _tf(_em, 'Email (optional)', Icons.email_outlined,
                              type: TextInputType.emailAddress,
                              val: (v) => v != null && v.isNotEmpty && !v.contains('@') ? 'Invalid email' : null),
                          _tf(_co, 'Company (optional)', Icons.business_outlined,
                              caps: TextCapitalization.words)),
                    ])),
                    SizedBox(height: r.itemGap),

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
                            borderRadius: AppTheme.r12, border: Border.all(color: AppTheme.border)),
                        child: SwitchListTile(
                          title: const Text('Walk-in visit', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                          subtitle: Text(_walkIn ? 'Visiting right now' : 'Scheduled',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                                    initialDate: _date, firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 30)));
                                if (p != null) setState(() => _date = p);
                              })),
                          SizedBox(width: r.itemGap),
                          Expanded(child: _DateBtn(
                              label: _time.format(context),
                              icon: Icons.access_time_rounded,
                              onTap: () async {
                                final p = await showTimePicker(context: context, initialTime: _time);
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

                    GradientButton(label: _busy ? 'Registering…' : 'Register Visitor',
                        icon: Icons.how_to_reg_rounded,
                        onTap: _busy ? null : _submit,
                        loading: _busy,
                        height: r.buttonHeight),
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
              decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.1),
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