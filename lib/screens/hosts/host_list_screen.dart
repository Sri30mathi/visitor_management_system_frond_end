// lib/screens/hosts/host_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';
import 'host_form_screen.dart';

class HostListScreen extends StatefulWidget {
  const HostListScreen({super.key});
  @override
  State<HostListScreen> createState() => _State();
}

class _State extends State<HostListScreen> {
  final _sc = TextEditingController();
  List<HostDto> _hosts  = [];
  bool  _loading        = true;
  bool? _activeFilter;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiService.getHosts(
        search:   _sc.text.trim().isEmpty ? null : _sc.text.trim(),
        isActive: _activeFilter, pageSize: 100,
      );
      if (mounted) setState(() { _hosts = r.items; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
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

  Future<void> _toggle(HostDto h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(h.isActive ? 'Deactivate Host' : 'Reactivate Host',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text('${h.isActive ? 'Deactivate' : 'Reactivate'} ${h.name}?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: h.isActive ? AppTheme.statusError : AppTheme.statusIn,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(h.isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (h.isActive) await ApiService.deactivateHost(h.hostId);
      else await ApiService.reactivateHost(h.hostId);
      _snack('Host ${h.isActive ? 'deactivated' : 'reactivated'}', AppTheme.statusIn);
      _load();
    } on ApiException catch (e) { _snack(e.message, AppTheme.statusError); }
  }

  @override
  Widget build(BuildContext context) {
    final r       = Responsive.of(context);
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hosts'),
        actions: [
          if (isAdmin) ...[
            _GradBtn(Icons.person_add_rounded, 'Add Host', () =>
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const HostFormScreen())).then((_) => _load())),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: Column(children: [
        // ── Filter panel ─────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: EdgeInsets.fromLTRB(r.pagePadding, 12, r.pagePadding, 14),
          child: Column(children: [
            // Search
            Container(height: 44,
              decoration: BoxDecoration(color: AppTheme.background,
                  borderRadius: AppTheme.r12, border: Border.all(color: AppTheme.border)),
              child: TextField(
                controller: _sc,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name or department…',
                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textMuted),
                  suffixIcon: _sc.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                          onPressed: () { _sc.clear(); _load(); })
                      : null,
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => Future.delayed(
                    const Duration(milliseconds: 400), _load),
              ),
            ),
            const SizedBox(height: 10),
            // Status filter chips
            Row(children: [
              const Text('Status', style: TextStyle(fontSize: 11,
                  color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              ...(<({bool? val, String label, Color color})>[
                (val: null,  label: 'All',      color: AppTheme.primary),
                (val: true,  label: 'Active',   color: AppTheme.statusIn),
                (val: false, label: 'Inactive', color: AppTheme.statusError),
              ].map((item) {
                final sel = _activeFilter == item.val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () { setState(() => _activeFilter = item.val); _load(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? item.color.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? item.color : AppTheme.border,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Text(item.label, style: TextStyle(fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? item.color : AppTheme.textSecondary)),
                    ),
                  ),
                );
              })),
            ]),
          ]),
        ),
        const Divider(height: 1, color: AppTheme.border),

        // ── List ─────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ]))
                  : _hosts.isEmpty
                      ? _Empty(isAdmin: isAdmin, onCreate: () =>
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const HostFormScreen())).then((_) => _load()))
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.pagePadding, vertical: 10),
                            itemCount: _hosts.length,
                            itemBuilder: (_, i) => _HostRow(
                              h: _hosts[i],
                              isAdmin: isAdmin,
                              onEdit: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => HostFormScreen(host: _hosts[i])))
                                  .then((_) => _load()),
                              onToggle: () => _toggle(_hosts[i]),
                            ),
                          ),
                        ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  HOST ROW  (list-view tile)
// ─────────────────────────────────────────────────────────
class _HostRow extends StatelessWidget {
  final HostDto h;
  final bool isAdmin;
  final VoidCallback onEdit, onToggle;
  const _HostRow({required this.h, required this.isAdmin,
      required this.onEdit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active = h.isActive;
    final c      = active ? AppTheme.primary : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: active ? AppTheme.border : AppTheme.border.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

          // Avatar
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: active ? AppTheme.primaryLight : AppTheme.border.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(h.name[0].toUpperCase(),
                style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(h.name, style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? AppTheme.textPrimary : AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              if (!active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.statusError.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Inactive', style: TextStyle(
                      fontSize: 10, color: AppTheme.statusError, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 2),
            // Department
            Row(children: [
              const Icon(Icons.business_outlined, size: 11, color: AppTheme.textMuted),
              const SizedBox(width: 3),
              Text(h.department, style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
            ]),
            const SizedBox(height: 2),
            // Email + visits
            Row(children: [
              const Icon(Icons.email_outlined, size: 11, color: AppTheme.textMuted),
              const SizedBox(width: 3),
              Expanded(child: Text(h.email, style: const TextStyle(
                  fontSize: 11, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              const Icon(Icons.people_outline, size: 11, color: AppTheme.textMuted),
              const SizedBox(width: 3),
              Text('${h.totalVisitors} visits', style: const TextStyle(
                  fontSize: 11, color: AppTheme.textMuted)),
            ]),
          ])),

          // Admin action buttons
          if (isAdmin) ...[
            const SizedBox(width: 8),
            Column(mainAxisSize: MainAxisSize.min, children: [
              _IconBtn(
                icon: Icons.edit_outlined,
                color: AppTheme.primary,
                tooltip: 'Edit',
                onTap: onEdit,
              ),
              const SizedBox(height: 4),
              _IconBtn(
                icon: active
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                color: active ? AppTheme.statusError : AppTheme.statusIn,
                tooltip: active ? 'Deactivate' : 'Reactivate',
                onTap: onToggle,
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final Color color;
  final String tooltip; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  final bool isAdmin; final VoidCallback onCreate;
  const _Empty({required this.isAdmin, required this.onCreate});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 60, height: 60,
        decoration: BoxDecoration(color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.people_outline_rounded, size: 28, color: AppTheme.primary)),
    const SizedBox(height: 12),
    const Text('No hosts found', style: TextStyle(fontSize: 14,
        color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
    if (isAdmin) ...[
      const SizedBox(height: 16),
      GradientButton(label: 'Add First Host', icon: Icons.add, onTap: onCreate, height: 44),
    ],
  ]));
}

class _GradBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _GradBtn(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(gradient: AppTheme.brandGrad,
          borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.btnShadow),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}