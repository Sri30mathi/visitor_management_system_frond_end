// lib/screens/dashboard/dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';

import '../../utils/responsive.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashState();
}

class _DashState extends State<DashboardScreen> {
  DashboardStats? _stats;
  bool   _loading = true;
  String? _error;
  Timer?  _timer;
  Timer?  _tickTimer;
  DateTime? _lastUpdated;
  int _secondsSinceUpdate = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh every 30 seconds — keeps counts live without user action
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _silentRefresh());
    // Tick every second so "last updated" text stays current + shows countdown
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsSinceUpdate++);
    });
  }

  // Refresh stats silently (no loading spinner) so the UI doesn't flicker
  Future<void> _silentRefresh() async {
    if (!mounted) return;
    try {
      final s = await ApiService.getDashboard();
      if (mounted) setState(() {
        _stats               = s;
        _lastUpdated         = DateTime.now();
        _secondsSinceUpdate  = 0;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[Dashboard] silent refresh error: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await ApiService.getDashboard();
      if (mounted) setState(() { _stats = s; _loading = false; _lastUpdated = DateTime.now(); _secondsSinceUpdate = 0; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  // ── Navigate to other screens — uses ROOT navigator so it works from sidebar
  void _navTo(String route) {
    Navigator.of(context, rootNavigator: true).pushNamed(route);
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      // Clear entire navigation stack and let _Root rebuild to LoginScreen
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r    = Responsive.of(context);
    final auth = context.watch<AuthProvider>();

    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : _error != null
            ? _ErrorView(msg: _error!, onRetry: _load)
            : RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _load,
                child: _DashBody(stats: _stats!, r: r),
              );

    if (r.isWide) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Row(
          children: [
            // Sidebar — fixed width, full height
            SizedBox(
              width: r.isDesktop ? 220 : 72,
              child: _Sidebar(
                user: auth.user,
                extended: r.isDesktop,
                onNavigate: _navTo,
                onLogout: _logout,
              ),
            ),
            // Divider
            Container(width: 1, color: AppTheme.border),
            // Main area — takes remaining space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top app bar
                  _WideAppBar(user: auth.user, onRefresh: _load, lastUpdated: _lastUpdated, secondsSince: _secondsSinceUpdate),
                  const Divider(height: 1, color: AppTheme.border),
                  // Content
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _MobileAppBar(
        user: auth.user,
        onRefresh: _load,
        onLogout: _logout,
        lastUpdated: _lastUpdated,
        secondsSince: _secondsSinceUpdate,
      ),
      body: body,
      bottomNavigationBar: _MobileNav(onNavigate: _navTo),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  DASHBOARD BODY
// ─────────────────────────────────────────────────────────
class _DashBody extends StatelessWidget {
  final DashboardStats stats;
  final Responsive r;
  const _DashBody({required this.stats, required this.r});

  @override
  Widget build(BuildContext context) {
    final p = r.pagePadding;
    final g = r.itemGap;

    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Stat cards — simple Row/Wrap, no GridView ─────
          _StatGrid(stats: stats, r: r),

          SizedBox(height: r.sectionGap),

          // ── QR Banner ─────────────────────────────────────
          _QrBanner(),

          SizedBox(height: r.sectionGap),

          // ── Charts ────────────────────────────────────────
          if (r.isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                if (stats.topHosts.isNotEmpty)
                  Expanded(flex: 2,
                      child: _HostsCard(hosts: stats.topHosts, r: r)),
              ],
            )
          else
            Column(
              children: [
                
                if (stats.topHosts.isNotEmpty)
                  _HostsCard(hosts: stats.topHosts, r: r),
              ],
            ),

          // ── Purposes ──────────────────────────────────────
          if (stats.purposeCounts.isNotEmpty) ...[
            SizedBox(height: g),
            _PurposeCard(purposes: stats.purposeCounts, r: r),
          ],

          SizedBox(height: p),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  STAT GRID — uses LayoutBuilder for perfect sizing
// ─────────────────────────────────────────────────────────
class _StatGrid extends StatelessWidget {
  final DashboardStats stats;
  final Responsive r;
  const _StatGrid({required this.stats, required this.r});

  @override
  Widget build(BuildContext context) {
    final cols = r.dashboardColumns;
    final gap  = r.itemGap;

    final cards = [
      _StatTile(label: 'Total Today',      value: '${stats.totalToday}',
          icon: Icons.today_rounded,             color: AppTheme.primary),
      _StatTile(label: 'Inside Now',       value: '${stats.checkedIn}',
          icon: Icons.sensor_door_rounded,       color: AppTheme.statusIn,   tag: 'LIVE'),
      _StatTile(label: 'Awaiting',         value: '${stats.registered}',
          icon: Icons.schedule_rounded,          color: AppTheme.statusWait),
      _StatTile(label: 'Checked Out',      value: '${stats.checkedOut}',
          icon: Icons.exit_to_app_rounded,       color: AppTheme.statusOut),
      _StatTile(label: 'Total Month',       value: '${stats.totalThisMonth}',
          icon: Icons.calendar_month_rounded,    color: const Color(0xFF7C3AED)),
      _StatTile(label: 'Total visits',         value: '${stats.totalAllTime}',
          icon: Icons.bar_chart_rounded,         color: const Color(0xFF0891B2)),
    ];

    // Build rows manually so each card is same height via IntrinsicHeight
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += cols) {
      final rowCards = cards.skip(i).take(cols).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int j = 0; j < rowCards.length; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(child: rowCards[j]),
              ],
              // fill remaining columns if last row is incomplete
              for (int k = rowCards.length; k < cols; k++) ...[
                SizedBox(width: gap),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        ),
      );
      if (i + cols < cards.length) rows.add(SizedBox(height: gap));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final String?  tag;
  const _StatTile({required this.label, required this.value,
      required this.icon, required this.color, this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.r16,
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(tag!,
                      style: TextStyle(color: color, fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
                height: 1,
              )),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  SECTION CARD
// ─────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.r16,
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Text(title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                )),
          ),
          child,
        ],
      ),
    );
  }
}

//

// ─────────────────────────────────────────────────────────
//  TOP HOSTS
// ─────────────────────────────────────────────────────────
class _HostsCard extends StatelessWidget {
  final List<TopHost> hosts;
  final Responsive r;
  const _HostsCard({required this.hosts, required this.r});

  static const _cols = [AppTheme.primary, AppTheme.accent,
      AppTheme.statusWait, Color(0xFF8B5CF6), AppTheme.statusOut];

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Top Hosts (All Time)',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: hosts.asMap().entries.map((e) {
            final c    = _cols[e.key % _cols.length];
            final h    = e.value;
            final last = e.key == hosts.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(child: Text('${e.key + 1}',
                      style: TextStyle(color: c, fontSize: 13,
                          fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.hostName, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    Text(h.department, style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${h.count}',
                      style: TextStyle(color: c, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  PURPOSES
// ─────────────────────────────────────────────────────────
class _PurposeCard extends StatelessWidget {
  final List<PurposeCount> purposes;
  final Responsive r;
  const _PurposeCard({required this.purposes, required this.r});

  @override
  Widget build(BuildContext context) {
    final total = purposes.fold(0, (s, p) => s + p.count);
    return _Card(
      title: 'Visit Purposes',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: purposes.asMap().entries.map((e) {
            final p    = e.value;
            final pct  = total > 0 ? p.count / total : 0.0;
            final last = e.key == purposes.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(p.purpose,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary))),
                      const SizedBox(width: 12),
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 6,
                      backgroundColor: AppTheme.border,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  SIDEBAR
// ─────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final UserProfile? user;
  final bool         extended;
  final void Function(String) onNavigate;
  final VoidCallback onLogout;
  const _Sidebar({required this.user, required this.extended,
      required this.onNavigate, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // ── Logo ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: extended
                ? Row(children: [
                    _Logo(),
                    const SizedBox(width: 10),
                    const Text('VisitorDairy',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary, letterSpacing: -0.3)),
                  ])
                : Center(child: _Logo()),
          ),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 8),

          // ── Nav items ────────────────────────────────────
          _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard',
              selected: true, extended: extended, onTap: () {}),
          _NavItem(icon: Icons.list_alt_rounded,  label: 'Visitors',
              selected: false, extended: extended,
              onTap: () => onNavigate('/visitors')),
          _NavItem(icon: Icons.person_add_rounded, label: 'Register',
              selected: false, extended: extended,
              onTap: () => onNavigate('/visitors/new')),
          _NavItem(icon: Icons.people_rounded,    label: 'Hosts',
              selected: false, extended: extended,
              onTap: () => onNavigate('/hosts')),
          _NavItem(icon: Icons.qr_code_scanner_rounded, label: 'QR Scan',
              selected: false, extended: extended,
              onTap: () => onNavigate('/qr-scan'),
              highlight: true),

          const Spacer(),
          const Divider(height: 1, color: AppTheme.border),

          // ── User footer ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: extended
                ? Row(children: [
                    _Avatar(user: user),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? '',
                            style: const TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        Text(user?.role ?? '',
                            style: const TextStyle(fontSize: 10,
                                color: AppTheme.textMuted)),
                      ],
                    )),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, size: 16,
                          color: AppTheme.textMuted),
                      onPressed: onLogout,
                      tooltip: 'Sign Out',
                    ),
                  ])
                : Column(children: [
                    _Avatar(user: user),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, size: 16,
                          color: AppTheme.textMuted),
                      onPressed: onLogout,
                    ),
                  ]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final bool     extended;
  final bool     highlight;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label,
      required this.selected, required this.extended, required this.onTap,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppTheme.primaryLight
             : highlight ? const Color(0xFF00BCD4).withOpacity(0.08)
             : Colors.transparent;
    final fg = selected ? AppTheme.primary
             : highlight ? const Color(0xFF0097A7)
             : AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: extended
              ? Row(children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 12),
                  Text(label,
                      style: TextStyle(fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: fg)),
                ])
              : Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 34, height: 34,
    decoration: BoxDecoration(
      gradient: AppTheme.brandGrad,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.badge_rounded, color: Colors.white, size: 18),
  );
}

class _Avatar extends StatelessWidget {
  final UserProfile? user;
  const _Avatar({required this.user});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 16,
    backgroundColor: AppTheme.primaryLight,
    child: Text(
      (user?.fullName ?? 'U')[0].toUpperCase(),
      style: const TextStyle(color: AppTheme.primary,
          fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

// ─────────────────────────────────────────────────────────
//  APP BARS
// ─────────────────────────────────────────────────────────
class _WideAppBar extends StatelessWidget {
  final UserProfile? user;
  final VoidCallback onRefresh;
  final DateTime?    lastUpdated;
  final int          secondsSince;
  const _WideAppBar({required this.user, required this.onRefresh,
      this.lastUpdated, this.secondsSince = 0});

  @override
  Widget build(BuildContext context) {
    final nextIn = 10 - (secondsSince % 10);
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Dashboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary, letterSpacing: -0.3)),
            Text('Welcome, ${user?.fullName ?? ''}',
                style: const TextStyle(fontSize: 12,
                    color: AppTheme.textSecondary)),
          ]),
          const Spacer(),
          // Live indicator with countdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.statusIn.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.statusIn.withOpacity(0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: AppTheme.statusIn, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                lastUpdated == null
                    ? 'Live'
                    : 'Live • refreshes in ${nextIn}s',
                style: const TextStyle(fontSize: 11,
                    color: AppTheme.statusIn, fontWeight: FontWeight.w500),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20,
                color: AppTheme.textSecondary),
            onPressed: onRefresh,
            tooltip: 'Refresh now',
          ),
        ],
      ),
    );
  }
}

class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserProfile? user;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final DateTime?    lastUpdated;
  final int          secondsSince;
  const _MobileAppBar({required this.user, required this.onRefresh,
      required this.onLogout, this.lastUpdated, this.secondsSince = 0});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: AppTheme.surface,
    elevation: 0,
    title: Row(children: [
      Container(width: 30, height: 30,
          decoration: BoxDecoration(gradient: AppTheme.brandGrad,
              borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.badge_rounded, color: Colors.white, size: 15)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(user?.fullName ?? '', style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
          ]),
    ]),
    actions: [
      IconButton(icon: const Icon(Icons.refresh_rounded, size: 20,
          color: AppTheme.textSecondary), onPressed: onRefresh),
      PopupMenuButton<String>(
        icon: _Avatar(user: user),
        onSelected: (v) { if (v == 'out') onLogout(); },
        itemBuilder: (_) => [
          PopupMenuItem(enabled: false, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.fullName ?? '', style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
              Text(user?.role ?? '', style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
            ],
          )),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'out', child: Row(children: [
            Icon(Icons.logout_rounded, size: 16, color: AppTheme.statusError),
            SizedBox(width: 8),
            Text('Sign Out', style: TextStyle(color: AppTheme.statusError)),
          ])),
        ],
      ),
      const SizedBox(width: 4),
    ],
  );
}

// ─────────────────────────────────────────────────────────
//  MOBILE BOTTOM NAV
// ─────────────────────────────────────────────────────────
class _MobileNav extends StatelessWidget {
  final void Function(String) onNavigate;
  const _MobileNav({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MobileNavBtn(Icons.dashboard_rounded, 'Dashboard',
                  selected: true, onTap: () {}),
              _MobileNavBtn(Icons.list_alt_rounded, 'Visitors',
                  onTap: () => onNavigate('/visitors')),
              _MobileNavBtn(Icons.person_add_rounded, 'Register',
                  onTap: () => onNavigate('/visitors/new')),
              _MobileNavBtn(Icons.people_rounded, 'Hosts',
                  onTap: () => onNavigate('/hosts')),
              _MobileNavBtn(Icons.qr_code_scanner_rounded, 'QR Scan',
                  color: const Color(0xFF0097A7),
                  onTap: () => onNavigate('/qr-scan')),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final Color?   color;
  final VoidCallback onTap;
  const _MobileNavBtn(this.icon, this.label,
      {this.selected = false, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = selected ? AppTheme.primary : color ?? AppTheme.textMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: c),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: c)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  ERROR VIEW
// ─────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppTheme.statusError.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.cloud_off_rounded,
              size: 30, color: AppTheme.statusError)),
        const SizedBox(height: 16),
        Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again')),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────
//  QR BANNER  (tappable card that opens the QR scanner)
// ─────────────────────────────────────────────────────────
class _QrBanner extends StatelessWidget {
  const _QrBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openScanner(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppTheme.r16,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0097A7).withOpacity(0.30),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick QR Check-in / Out',
                  style: TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('Tap to scan visitor badge',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )),
          ElevatedButton(
            onPressed: () => _openScanner(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0097A7),
              minimumSize: const Size(72, 38),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Scan', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  void _openScanner(BuildContext context) {
    Navigator.of(context, rootNavigator: true)
        .pushNamed('/qr-scan')
        .then((_) {
      // Dashboard will auto-refresh via its 10s timer; no manual reload needed
    });
  }
}