// lib/screens/visitors/visitor_log_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';
import 'visitor_detail_screen.dart';

// ── Filter mode ───────────────────────────────────────────
enum _Mode { all, today, specificDay, specificMonth, customRange }

class VisitorLogScreen extends StatefulWidget {
  const VisitorLogScreen({super.key});
  @override
  State<VisitorLogScreen> createState() => _State();
}

class _State extends State<VisitorLogScreen> {
  final _sc = TextEditingController();
  final _sv = ScrollController();

  List<VisitorEntryDto> _items  = [];
  bool      _loading  = false;
  bool      _hasMore  = true;
  int       _page     = 1;
  String    _status   = 'All';
  _Mode     _mode     = _Mode.all;

  // for specific day / month / custom
  DateTime? _pickedDay;      // exact date
  DateTime? _pickedMonth;    // year+month only
  DateTimeRange? _customRange;

  static const _statuses = ['All', 'Registered', 'CheckedIn', 'CheckedOut'];

  // ── Compute API date range from current mode ──────────────
  (DateTime?, DateTime?) get _range {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_mode) {
      case _Mode.all:
        return (null, null);
      case _Mode.today:
        return (today, today.add(const Duration(days: 1)));
      case _Mode.specificDay:
        if (_pickedDay == null) return (null, null);
        final d = DateTime(_pickedDay!.year, _pickedDay!.month, _pickedDay!.day);
        return (d, d.add(const Duration(days: 1)));
      case _Mode.specificMonth:
        if (_pickedMonth == null) return (null, null);
        final first = DateTime(_pickedMonth!.year, _pickedMonth!.month, 1);
        final next  = DateTime(_pickedMonth!.year, _pickedMonth!.month + 1, 1);
        return (first, next);
      case _Mode.customRange:
        if (_customRange == null) return (null, null);
        final from = _customRange!.start;
        final to   = DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day + 1);
        return (from, to);
    }
  }

  // ── Dropdown label ────────────────────────────────────────
  String get _dropdownLabel {
    final dfmt  = DateFormat('dd MMM yyyy');
    final mfmt  = DateFormat('MMMM yyyy');
    final sfmt  = DateFormat('dd MMM');
    switch (_mode) {
      case _Mode.all:           return 'All';
      case _Mode.today:         return 'Today';
      case _Mode.specificDay:
        return _pickedDay != null ? dfmt.format(_pickedDay!) : 'Pick a Day';
      case _Mode.specificMonth:
        return _pickedMonth != null ? mfmt.format(_pickedMonth!) : 'Pick a Month';
      case _Mode.customRange:
        if (_customRange != null) {
          return '${sfmt.format(_customRange!.start)} – ${sfmt.format(_customRange!.end)}';
        }
        return 'Custom Range';
    }
  }

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _sv.addListener(_onScroll);
    _sc.addListener(() => setState(() {})); // update clear button
  }

  @override
  void dispose() { _sc.dispose(); _sv.dispose(); super.dispose(); }

  void _onScroll() {
    if (_sv.position.pixels >= _sv.position.maxScrollExtent - 200
        && !_loading && _hasMore) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) { _page = 1; _items = []; _hasMore = true; }
    setState(() => _loading = true);
    final (from, to) = _range;
    try {
      final res = await ApiService.getVisitors(
        search:   _sc.text.trim().isEmpty ? null : _sc.text.trim(),
        status:   _status == 'All' ? null : _status,
        dateFrom: from?.toUtc(),
        dateTo:   to?.toUtc(),
        page:     _page, pageSize: 25,
      );
      if (mounted) setState(() {
        _items.addAll(res.items);
        _hasMore = _page < res.totalPages;
        _page++;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(e.message, AppTheme.statusError);
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

  // ── Date filter dropdown ──────────────────────────────────
  // Called when a filter option is selected from the dropdown
  Future<void> _onFilterSelected(_Mode mode) async {
    final now = DateTime.now();

    if (mode == _Mode.specificDay) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _pickedDay ?? now,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
          child: child!,
        ),
      );
      if (picked == null || !mounted) return;
      setState(() { _mode = _Mode.specificDay; _pickedDay = picked; });
    } else if (mode == _Mode.specificMonth) {
      final picked = await showDialog<DateTime>(
        context: context,
        builder: (_) => _MonthPickerDialog(initial: _pickedMonth ?? now),
      );
      if (picked == null || !mounted) return;
      setState(() { _mode = _Mode.specificMonth; _pickedMonth = picked; });
    } else if (mode == _Mode.customRange) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange: _customRange ??
            DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
          child: child!,
        ),
      );
      if (picked == null || !mounted) return;
      setState(() { _mode = _Mode.customRange; _customRange = picked; });
    } else {
      setState(() => _mode = mode);
    }
    _load(reset: true);
  }



  // ── Check-in / out ────────────────────────────────────────
  Future<void> _checkIn(VisitorEntryDto v) async {
    try {
      await ApiService.checkIn(v.entryId);
      _snack('${v.visitorName} checked in ✓', AppTheme.statusIn);
      _load(reset: true);
    } on ApiException catch (e) { _snack(e.message, AppTheme.statusError); }
  }

  Future<void> _checkOut(VisitorEntryDto v) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Check Out',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Check out ${v.visitorName}?',
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          TextField(controller: ctrl,
              decoration: const InputDecoration(hintText: 'Remarks (optional)'),
              maxLines: 2),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.statusWait,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final resp = await ApiService.checkOut(v.entryId,
          remarks: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
      _snack('Checked out • ${resp.durationMinutes ?? 0} min', AppTheme.statusWait);
      _load(reset: true);
    } on ApiException catch (e) { _snack(e.message, AppTheme.statusError); }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Visitors'),
        actions: [
          _GradBtn(Icons.person_add_rounded, 'Register',
              () => Navigator.pushNamed(context, '/visitors/new')
                  .then((_) => _load(reset: true))),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(children: [

        // ── Filter panel ────────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: EdgeInsets.fromLTRB(r.pagePadding, 12, r.pagePadding, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Search bar
            Container(
              height: 44,
              decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: AppTheme.r12,
                  border: Border.all(color: AppTheme.border)),
              child: TextField(
                controller: _sc,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search name, mobile, company…',
                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: AppTheme.textMuted),
                  suffixIcon: _sc.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: AppTheme.textMuted),
                          onPressed: () { _sc.clear(); _load(reset: true); })
                      : null,
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none, filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => Future.delayed(
                    const Duration(milliseconds: 500), () => _load(reset: true)),
              ),
            ),
            const SizedBox(height: 10),

            // ── Date filter + Status row ────────────────────
            Row(children: [
              // Date filter — inline dropdown
              Expanded(
                child: _DateFilterDropdown(
                  mode: _mode,
                  label: _dropdownLabel,
                  onSelected: _onFilterSelected,
                ),
              ),
              const SizedBox(width: 10),

              // Status filter dropdown
              _StatusDropdown(
                value: _status,
                onChanged: (v) { setState(() => _status = v); _load(reset: true); },
              ),
            ]),
          ]),
        ),

        const Divider(height: 1, color: AppTheme.border),

        // ── Results count bar ───────────────────────────────
        if (!_loading || _items.isNotEmpty)
          Container(
            color: AppTheme.background,
            padding: EdgeInsets.symmetric(
                horizontal: r.pagePadding, vertical: 8),
            child: Row(children: [
              Text(_dropdownLabel,
                  style: const TextStyle(fontSize: 12,
                      color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              if (_status != 'All') ...[
                const Text('·', style: TextStyle(color: AppTheme.textMuted)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.statusColor(_status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusLabel(_status),
                      style: TextStyle(fontSize: 11,
                          color: AppTheme.statusColor(_status),
                          fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              Text('${_items.length}${_hasMore ? '+' : ''} visitors',
                  style: const TextStyle(fontSize: 12,
                      color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            ]),
          ),

        // ── Visitor list ────────────────────────────────────
        Expanded(
          child: _items.isEmpty && !_loading
              ? const _Empty()
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () => _load(reset: true),
                  child: ListView.builder(
                    controller: _sv,
                    padding: EdgeInsets.symmetric(
                        horizontal: r.pagePadding, vertical: 10),
                    itemCount: _items.length + (_hasMore || _loading ? 1 : 0),
                    itemBuilder: _buildRow,
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildRow(BuildContext context, int i) {
    if (i == _items.length) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(
            color: AppTheme.primary, strokeWidth: 2)),
      );
    }
    final v = _items[i];
    return _VRow(
      v: v,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => VisitorDetailScreen(entryId: v.entryId)))
          .then((_) => _load(reset: true)),
      onAction: v.status == 'Registered'
          ? () => _checkIn(v)
          : v.status == 'CheckedIn'
              ? () => _checkOut(v)
              : null,
      actionLabel: v.status == 'Registered' ? 'Check In' : 'Check Out',
      actionIcon:  v.status == 'Registered'
          ? Icons.how_to_reg_rounded
          : Icons.logout_rounded,
    );
  }

  IconData _modeIcon(_Mode m) {
    switch (m) {
      case _Mode.all:           return Icons.all_inclusive_rounded;
      case _Mode.today:         return Icons.today_rounded;
      case _Mode.specificDay:   return Icons.event_rounded;
      case _Mode.specificMonth: return Icons.calendar_month_rounded;
      case _Mode.customRange:   return Icons.date_range_rounded;
    }
  }

  String _statusLabel(String s) =>
      s == 'CheckedIn' ? 'Inside' : s == 'CheckedOut' ? 'Checked Out' : s;
}

// ─────────────────────────────────────────────────────────
//  DATE FILTER DROPDOWN BUTTON
// ─────────────────────────────────────────────────────────
class _DateFilterDropdown extends StatelessWidget {
  final _Mode mode;
  final String label;
  final void Function(_Mode) onSelected;

  const _DateFilterDropdown({
    required this.mode,
    required this.label,
    required this.onSelected,
  });

  static const _modeColors = {
    _Mode.all:           Color(0xFF6366F1),
    _Mode.today:         AppTheme.primary,
    _Mode.specificDay:   Color(0xFF0891B2),
    _Mode.specificMonth: Color(0xFF7C3AED),
    _Mode.customRange:   Color(0xFFD97706),
  };

  static const _modeIcons = {
    _Mode.all:           Icons.all_inclusive_rounded,
    _Mode.today:         Icons.today_rounded,
    _Mode.specificDay:   Icons.event_rounded,
    _Mode.specificMonth: Icons.calendar_month_rounded,
    _Mode.customRange:   Icons.date_range_rounded,
  };

  static const _modeLabels = {
    _Mode.all:           'All',
    _Mode.today:         'Today',
    _Mode.specificDay:   'Pick Any Day',
    _Mode.specificMonth: 'Pick Any Month',
    _Mode.customRange:   'Custom Range',
  };

  @override
  Widget build(BuildContext context) {
    final now      = DateTime.now();
    final color    = _modeColors[mode] ?? AppTheme.primary;
    final icon     = _modeIcons[mode]  ?? Icons.calendar_today_rounded;
    final showSub  = label != (_modeLabels[mode] ?? '') &&
                     label != 'All' && label != 'Today';

    return PopupMenuButton<dynamic>(
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 4,
      onSelected: (val) => onSelected(val as _Mode),
      itemBuilder: (_) => [
        ...(_modeLabels.entries.map((e) {
          final sel = mode == e.key;
          final c   = _modeColors[e.key] ?? AppTheme.primary;
          final ic  = _modeIcons[e.key]  ?? Icons.calendar_today_rounded;
          return PopupMenuItem<dynamic>(
            value: e.key,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(ic, size: 15, color: sel ? c : AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Text(e.value, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: sel ? c : AppTheme.textPrimary))),
              if (sel) Icon(Icons.check_rounded, size: 14, color: c),
            ]),
          );
        })),
      ],
      // The trigger button
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: showSub
                ? Column(mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_modeLabels[mode] ?? '', style: TextStyle(
                        fontSize: 10, color: color.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500, height: 1.1)),
                    Text(label, style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700, color: color, height: 1.2),
                        overflow: TextOverflow.ellipsis),
                  ])
                : Text(label, style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: color),
                    overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: color),
        ]),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────
//  MONTH PICKER DIALOG
// ─────────────────────────────────────────────────────────
class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;
  const _MonthPickerDialog({required this.initial});
  @override
  State<_MonthPickerDialog> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year  = widget.initial.year;
    _month = widget.initial.month;
  }

  bool _isFuture(int y, int m) {
    final now = DateTime.now();
    return y > now.year || (y == now.year && m > now.month);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      // Fixed width — same compact footprint as the Flutter date picker
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Year row ────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              onPressed: _year > now.year - 3
                  ? () => setState(() => _year--)
                  : null,
              color: AppTheme.primary,
            ),
            GestureDetector(
              child: Text('$_year', style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppTheme.primary)),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              onPressed: _year < now.year
                  ? () => setState(() => _year++)
                  : null,
              color: AppTheme.primary,
            ),
          ]),
          const SizedBox(height: 10),

          // ── Month grid — 3 rows × 4 cols ─────────────────
          ...List.generate(3, (row) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: List.generate(4, (col) {
                final i    = row * 4 + col;
                final m    = i + 1;
                final sel  = m == _month;
                final grey = _isFuture(_year, m);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: col == 0 ? 0 : 5),
                    child: GestureDetector(
                      onTap: grey ? null : () => setState(() => _month = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: 30,
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: sel
                                ? AppTheme.primary
                                : grey
                                    ? AppTheme.border.withValues(alpha: 0.3)
                                    : AppTheme.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(_months[i], style: TextStyle(
                          fontSize: 15,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel
                              ? Colors.white
                              : grey
                                  ? AppTheme.textMuted
                                  : AppTheme.textPrimary,
                        )),
                      ),
                    ),
                  ),
                );
              }),
            ),
          )),
          const SizedBox(height: 12),

          // ── Actions ──────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  foregroundColor: AppTheme.textMuted),
              child: const Text('Cancel', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _isFuture(_year, _month)
                  ? null
                  : () => Navigator.pop(context, DateTime(_year, _month, 1)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  foregroundColor: AppTheme.primary),
              child: const Text('OK',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    ),
  );
  }
}

// ─────────────────────────────────────────────────────────
//  STATUS DROPDOWN
// ─────────────────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusDropdown({required this.value, required this.onChanged});

  static const _options = ['All', 'Registered', 'CheckedIn', 'CheckedOut'];

  String _label(String s) =>
      s == 'CheckedIn' ? 'Inside' : s == 'CheckedOut' ? 'Checked Out' : s;

  Color _color(String s) =>
      s == 'All' ? AppTheme.textSecondary : AppTheme.statusColor(s);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: AppTheme.textMuted),
          style: const TextStyle(
              fontSize: 13, color: AppTheme.textPrimary,
              fontFamily: 'Outfit'),
          items: _options.map((s) => DropdownMenuItem(
            value: s,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: _color(s), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(_label(s), style: TextStyle(
                  fontSize: 13, color: _color(s),
                  fontWeight: FontWeight.w600)),
            ]),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  VISITOR ROW
// ─────────────────────────────────────────────────────────
class _VRow extends StatelessWidget {
  final VisitorEntryDto v;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final String actionLabel;
  final IconData actionIcon;
  const _VRow({required this.v, required this.onTap,
      this.onAction, required this.actionLabel, required this.actionIcon});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy • h:mm a');
    final c   = AppTheme.statusColor(v.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(width: 46, height: 46,
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(v.visitorName[0].toUpperCase(),
                    style: TextStyle(color: c, fontSize: 18,
                        fontWeight: FontWeight.w700)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(v.visitorName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                StatusBadge(v.status),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.person_outline_rounded,
                    size: 11, color: AppTheme.textMuted),
                const SizedBox(width: 3),
                Flexible(child: Text(v.hostName,
                    style: const TextStyle(fontSize: 12,
                        color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                const Icon(Icons.work_outline_rounded,
                    size: 11, color: AppTheme.textMuted),
                const SizedBox(width: 3),
                Flexible(child: Text(v.purpose,
                    style: const TextStyle(fontSize: 12,
                        color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.access_time_rounded,
                    size: 11, color: AppTheme.textMuted),
                const SizedBox(width: 3),
                Text(fmt.format(v.visitDateTime.toLocal()),
                    style: const TextStyle(fontSize: 11,
                        color: AppTheme.textMuted)),
                if (v.company != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.business_outlined,
                      size: 11, color: AppTheme.textMuted),
                  const SizedBox(width: 3),
                  Flexible(child: Text(v.company!,
                      style: const TextStyle(fontSize: 11,
                          color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ])),
            if (onAction != null) ...[
              const SizedBox(width: 10),
              _ActionChip(label: actionLabel, icon: actionIcon,
                  color: c, onTap: onAction!),
            ],
          ]),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(label.replaceAll(' ', '\n'), textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: color,
                fontWeight: FontWeight.w600, height: 1.2)),
      ]),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 60, height: 60,
          decoration: BoxDecoration(color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.people_outline_rounded,
              size: 28, color: AppTheme.primary)),
      const SizedBox(height: 12),
      const Text('No visitors found', style: TextStyle(fontSize: 14,
          color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      const Text('Try adjusting the filters or date range',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
    ]),
  );
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.btnShadow),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}