// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/visitors/visitor_log_screen.dart';
import 'screens/visitors/visitor_form_screen.dart';
import 'screens/visitors/visitor_detail_screen.dart';
import 'screens/hosts/host_list_screen.dart';
import 'screens/hosts/host_form_screen.dart';
import 'screens/qr/qr_scanner_screen.dart';
import 'screens/qr/registration_qr_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (_) => AuthProvider()..init(),
    child: const App(),
  ));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final base  = AppTheme.theme;
    final theme = base.copyWith(
        textTheme: GoogleFonts.outfitTextTheme(base.textTheme));
    return MaterialApp(
      title: 'Visitor Management',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const _Root(),
      routes: {
        '/login':        (_) => const LoginScreen(),
        '/dashboard':    (_) => const DashboardScreen(),
        '/visitors':     (_) => const VisitorLogScreen(),
        '/visitors/new': (_) => const VisitorFormScreen(),
        '/hosts':        (_) => const HostListScreen(),
        '/hosts/new':    (_) => const HostFormScreen(),
        '/qr-scan':      (_) => const QrScannerScreen(),
        '/register-qr':  (_) => const RegistrationQrScreen(),
      },
      onGenerateRoute: (s) {
        if (s.name == '/visitors/detail') return MaterialPageRoute(
            builder: (_) => VisitorDetailScreen(entryId: s.arguments as String));
        return null;
      },
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        // ── Still checking server / session ────────────────
        if (auth.state == AuthState.unknown) {
          if (!auth.serverOnline && !auth.checkingServer) {
            // Server is confirmed offline — show offline screen
            return _OfflineScreen(onRetry: auth.retryConnection);
          }
          // Either checking server or restoring session
          return const _SplashScreen();
        }
        // ── Server online + session resolved ───────────────
        if (auth.state == AuthState.authenticated) return const DashboardScreen();
        return const LoginScreen();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  SPLASH — shown while checking server / restoring session
// ─────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGrad,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.btnShadow,
            ),
            child: const Icon(Icons.badge_rounded,
                color: Colors.white, size: 34),
          ),
          const SizedBox(height: 24),
          const Text('VisitorHub',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text('Connecting…',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 28),
          const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppTheme.primary)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  OFFLINE SCREEN — shown when server cannot be reached
// ─────────────────────────────────────────────────────────
class _OfflineScreen extends StatefulWidget {
  final Future<void> Function() onRetry;
  const _OfflineScreen({required this.onRetry});
  @override
  State<_OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<_OfflineScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await widget.onRetry();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.statusError.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 38, color: AppTheme.statusError),
              ),
              const SizedBox(height: 24),

              // Title
              const Text('Server Unreachable',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary, letterSpacing: -0.4)),
              const SizedBox(height: 10),

              // Message
              const Text(
                'Cannot connect to the backend server.\n'
                'Make sure the API is running and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary,
                    height: 1.6),
              ),
              const SizedBox(height: 8),

              // How to fix hint
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Quick fix:', style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    SizedBox(height: 6),
                    Text('Run in your terminal:',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    SizedBox(height: 4),
                    Text('cd path/to/your/api/project',
                        style: TextStyle(fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontFamily: 'monospace')),
                    SizedBox(height: 2),
                    Text('dotnet run',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            fontFamily: 'monospace')),
                    SizedBox(height: 4),
                    Text('App will auto-detect the port.',
                        style: TextStyle(fontSize: 11,
                            color: AppTheme.accent)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Auto-retry notice
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(
                        color: AppTheme.statusWait, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Retrying automatically every 5 seconds…',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 20),

              // Retry button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: _retrying
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_retrying ? 'Connecting…' : 'Retry Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}