// lib/utils/app_constants.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AppConstants {
  // ── Auto-detects the right base URL per platform ──────────────────────
  //
  //  Flutter Web (browser)    → localhost       (you are here now ✅)
  //  Android Emulator         → 10.0.2.2        (emulator loopback to host PC)
  //  iOS Simulator            → localhost
  //  Real device (USB/WiFi)   → change _deviceIp to your PC's local IP
  //
  static const String _port     = '5000';
  //static const String _deviceIp = '192.168.1.100'; // ← change for real device

  static String get baseUrl {
    if (kIsWeb) {
      // Running in a browser — API must be on same machine
      return 'http://localhost:$_port/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator reaches host PC via 10.0.2.2
        // Real device: swap to _deviceIp
        return 'http://10.0.2.2:$_port/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'http://localhost:$_port/api';
      default:
        return 'http://localhost:$_port/api';
    }
  }

  // Auth
  static const String login          = '/auth/login';
  static const String me             = '/auth/me';
  static const String register       = '/auth/register';
  static const String changePassword = '/auth/change-password';

  // Visitors
  static const String visitors        = '/visitors';
  static const String checkin         = '/visitors/checkin';
  static const String checkout        = '/visitors/checkout';
  static const String dashboard       = '/visitors/dashboard';
  static const String visitorExport   = '/visitors/export';

  // Hosts
  static const String hosts = '/hosts';

  // Status values
  static const String registered = 'Registered';
  static const String checkedIn  = 'CheckedIn';
  static const String checkedOut = 'CheckedOut';

  // Roles
  static const String admin    = 'Admin';
  static const String security = 'Security';

  // Purposes for dropdown
  static const List<String> purposes = [
    'Business Meeting',
    'Interview',
    'Vendor Meeting',
    'Client Visit',
    'Delivery',
    'Maintenance',
    'Other',
  ];

  // ID types for dropdown
  static const List<String> idTypes = [
    'Aadhaar',
    'PAN Card',
    'Passport',
    'Driving License',
    'Voter ID',
  ];
}