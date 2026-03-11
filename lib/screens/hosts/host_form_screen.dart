// lib/screens/hosts/host_form_screen.dart
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';

class HostFormScreen extends StatefulWidget {
  final HostDto? host;
  const HostFormScreen({super.key, this.host});
  @override
  State<HostFormScreen> createState() => _State();
}

class _State extends State<HostFormScreen> {
  final _fk   = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _em   = TextEditingController();
  final _ph   = TextEditingController();
  final _dept = TextEditingController();
  bool _busy = false;

  bool get _isEdit => widget.host != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _name.text = widget.host!.name;
      _em.text   = widget.host!.email;
      _ph.text   = widget.host!.phone ?? '';
      _dept.text = widget.host!.department;
    }
  }

  @override
  void dispose() {
    _name.dispose(); _em.dispose(); _ph.dispose(); _dept.dispose(); super.dispose();
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await ApiService.updateHost(
          widget.host!.hostId,
          name:       _name.text.trim(),
          email:      _em.text.trim(),
          phone:      _ph.text.trim().isEmpty ? null : _ph.text.trim(),
          department: _dept.text.trim(),
        );
      } else {
        await ApiService.createHost(
          name:       _name.text.trim(),
          email:      _em.text.trim(),
          phone:      _ph.text.trim().isEmpty ? null : _ph.text.trim(),
          department: _dept.text.trim(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Host updated ✓' : 'Host created ✓',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.statusIn, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.statusError, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Host' : 'Add Host'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.formMaxWidth),
          child: Form(
            key: _fk,
            child: ListView(
              padding: EdgeInsets.all(r.pagePadding),
              children: [
                // Header card
                AppCard(
                  padding: EdgeInsets.all(r.cardPadding + 4),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGrad,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEdit ? 'Edit Host Profile' : 'New Host',
                            style: const TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 3),
                        Text(_isEdit
                            ? 'Update host information'
                            : 'Add an employee who can receive visitors',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    )),
                  ]),
                ),
                SizedBox(height: r.itemGap),

                // Form fields card
                AppCard(
                  padding: EdgeInsets.all(r.cardPadding),
                  child: Column(children: [
                    _Field(_name, 'Full Name', Icons.badge_outlined,
                        req: true, caps: TextCapitalization.words),
                    SizedBox(height: r.itemGap),
                    _Field(_em, 'Email Address', Icons.email_outlined,
                        req: true, type: TextInputType.emailAddress,
                        val: (v) => v != null && !v.contains('@') ? 'Enter valid email' : null),
                    SizedBox(height: r.itemGap),
                    _Field(_ph, 'Phone Number (optional)', Icons.phone_outlined,
                        type: TextInputType.phone),
                    SizedBox(height: r.itemGap),
                    _Field(_dept, 'Department', Icons.business_outlined,
                        req: true, caps: TextCapitalization.words),
                  ]),
                ),
                SizedBox(height: r.sectionGap),

                GradientButton(
                  label: _busy ? 'Saving…' : (_isEdit ? 'Update Host' : 'Create Host'),
                  icon:  _isEdit ? Icons.save_rounded : Icons.add_rounded,
                  onTap: _busy ? null : _submit,
                  loading: _busy,
                  height: r.buttonHeight,
                ),
                SizedBox(height: r.sectionGap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool req;
  final TextInputType type;
  final TextCapitalization caps;
  final String? Function(String?)? val;

  const _Field(this.ctrl, this.label, this.icon, {
    this.req = false,
    this.type = TextInputType.text,
    this.caps = TextCapitalization.none,
    this.val,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: type,
    textCapitalization: caps,
    style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
    decoration: InputDecoration(
      labelText: req ? '$label *' : label,
      prefixIcon: Icon(icon, size: 18),
    ),
    validator: val ?? (req
        ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
        : null),
  );
}