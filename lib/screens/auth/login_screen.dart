// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _State();
}

class _State extends State<LoginScreen> {
  final _fk   = GlobalKey<FormState>();
  final _em   = TextEditingController();
  final _pw   = TextEditingController();
  bool _hide  = true;
  bool _busy  = false;

  @override
  void dispose() { _em.dispose(); _pw.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await context.read<AuthProvider>().login(_em.text.trim(), _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final r  = Responsive.of(context);
    final err = context.watch<AuthProvider>().error;

    return Scaffold(
      body: r.isWide
          ? Row(children: [_Brand(r: r), Expanded(flex: r.isDesktop ? 4 : 4, child: _FormPanel(r: r, err: err, s: this))])
          : _MobileLayout(r: r, err: err, s: this),
    );
  }
}

// ── Wide brand panel ──────────────────────────────────────
class _Brand extends StatelessWidget {
  final Responsive r;
  const _Brand({required this.r});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: r.isDesktop ? 3 : 3,
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGrad),
        child: Stack(children: [
          Positioned(top: -80, right: -80, child: _Glow(300, AppTheme.primary.withOpacity(0.25))),
          Positioned(bottom: -60, left: -40, child: _Glow(220, AppTheme.accent.withOpacity(0.18))),
          Padding(
            padding: EdgeInsets.all(r.pagePadding * 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              _Logo(),
              SizedBox(height: r.sectionGap),
              Text('Visitor\nManagement', style: TextStyle(
                fontSize: r.isDesktop ? 44 : 34, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1.1, letterSpacing: -1.2)),
              const SizedBox(height: 12),
              Text('Smart, secure visitor\ntracking for modern workplaces.',
                  style: TextStyle(fontSize: r.bodyFontSize,
                      color: Colors.white.withOpacity(0.55), height: 1.65)),
              const SizedBox(height: 40),
              Wrap(spacing: 10, runSpacing: 10, children: const [
                _Pill(Icons.qr_code_rounded,    'QR Check-in'),
                _Pill(Icons.bar_chart_rounded,  'Live Dashboard'),
                _Pill(Icons.shield_rounded,     'Role Access'),
                _Pill(Icons.people_alt_rounded, 'Host Mgmt'),
              ]),
              const Spacer(),
              Text('© 2025 VisitorHub', style: TextStyle(
                  fontSize: 11, color: Colors.white.withOpacity(0.25))),
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Wide form panel ───────────────────────────────────────
class _FormPanel extends StatelessWidget {
  final Responsive r; final String? err; final _State s;
  const _FormPanel({required this.r, required this.err, required this.s});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(r.pagePadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.formMaxWidth),
            child: Container(
              padding: EdgeInsets.all(r.pagePadding),
              decoration: BoxDecoration(color: AppTheme.surface,
                  borderRadius: AppTheme.r24,
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.cardShadow),
              child: _Fields(r: r, err: err, s: s),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile layout ─────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final Responsive r; final String? err; final _State s;
  const _MobileLayout({required this.r, required this.err, required this.s});
  @override
  Widget build(BuildContext context) => Column(children: [
    Expanded(flex: 2, child: Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGrad),
      child: Stack(children: [
        Positioned(top: -40, right: -40, child: _Glow(200, AppTheme.primary.withOpacity(0.28))),
        SafeArea(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Logo(),
          const SizedBox(height: 14),
          const Text('Visitor Management', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 5),
          Text('Security Portal', style: TextStyle(
              fontSize: 13, color: Colors.white.withOpacity(0.5))),
        ]))),
      ]),
    )),
    Expanded(flex: 3, child: Container(
      decoration: const BoxDecoration(color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(r.pagePadding, r.pagePadding + 4, r.pagePadding, 0),
      child: SingleChildScrollView(child: _Fields(r: r, err: err, s: s)),
    )),
  ]);
}

// ── Form fields ───────────────────────────────────────────
class _Fields extends StatelessWidget {
  final Responsive r; final String? err; final _State s;
  const _Fields({required this.r, required this.err, required this.s});

  @override
  Widget build(BuildContext context) => Form(
    key: s._fk,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Welcome back', style: TextStyle(fontSize: r.titleFontSize + 2,
          fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.6)),
      const SizedBox(height: 5),
      Text('Sign in to continue', style: TextStyle(
          fontSize: r.bodyFontSize, color: AppTheme.textSecondary)),
      SizedBox(height: r.sectionGap),

      if (err != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
              color: AppTheme.statusError.withOpacity(0.06),
              borderRadius: AppTheme.r12,
              border: Border.all(color: AppTheme.statusError.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.statusError, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(err!, style: TextStyle(
                color: AppTheme.statusError, fontSize: r.captionFontSize + 1,
                fontWeight: FontWeight.w500))),
          ]),
        ),
        SizedBox(height: r.itemGap),
      ],

      _Label('Email address'),
      const SizedBox(height: 6),
      TextFormField(
        controller: s._em, keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: TextStyle(fontSize: r.bodyFontSize, color: AppTheme.textPrimary),
        decoration: const InputDecoration(hintText: 'you@company.com',
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 18)),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Email is required';
          if (!v.contains('@')) return 'Enter a valid email';
          return null;
        },
      ),
      SizedBox(height: r.itemGap + 4),

      _Label('Password'),
      const SizedBox(height: 6),
      StatefulBuilder(builder: (_, setSt) => TextFormField(
        controller: s._pw, obscureText: s._hide,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => s._submit(),
        style: TextStyle(fontSize: r.bodyFontSize, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: '••••••••',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
          suffixIcon: IconButton(
            icon: Icon(s._hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 17, color: AppTheme.textMuted),
            onPressed: () { s._hide = !s._hide; setSt(() {}); },
          ),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
      )),
      SizedBox(height: r.sectionGap),

      GradientButton(label: 'Sign In', icon: Icons.login_rounded,
          onTap: s._busy ? null : s._submit, loading: s._busy, height: r.buttonHeight),
    ]),
  );
}

// ── Shared helpers ────────────────────────────────────────
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(gradient: AppTheme.brandGrad,
        borderRadius: BorderRadius.circular(15), boxShadow: AppTheme.btnShadow),
    child: const Icon(Icons.badge_rounded, color: Colors.white, size: 26),
  );
}

class _Label extends StatelessWidget {
  final String t;
  const _Label(this.t);
  @override
  Widget build(BuildContext context) => Text(t, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));
}

class _Glow extends StatelessWidget {
  final double sz; final Color c;
  const _Glow(this.sz, this.c);
  @override
  Widget build(BuildContext context) => Container(
      width: sz, height: sz,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}

class _Pill extends StatelessWidget {
  final IconData icon; final String label;
  const _Pill(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white.withOpacity(0.65)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.65))),
    ]),
  );
}