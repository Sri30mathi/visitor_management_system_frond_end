// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int?   statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static const _tokenKey = 'access_token';

  // ══════════════════════════════════════════════════════
  //  PORT AUTO-DISCOVERY
  //  Scans common .NET dev ports so the app works regardless
  //  of which port `dotnet run` picked.
  // ══════════════════════════════════════════════════════
  static String? _resolvedBase;

  static const _candidatePorts = [
    5000, 5001, 7000, 7001, 7080, 7100, 7200,
    8000, 8080, 8081, 44300, 44360,
  ];

  /// Try each port until one answers. Caches the result.
  static Future<String?> _discoverBase() async {
    if (_resolvedBase != null) return _resolvedBase;
    for (final port in _candidatePorts) {
      final base = 'http://localhost:$port';
      try {
        final res = await http.get(
          Uri.parse('$base/api/auth/me'),
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 2));
        // 401 = server up but not authed — that's fine
        if (res.statusCode < 500) {
          // ignore: avoid_print
          print('[API] Discovered server at $base');
          _resolvedBase = '$base/api';
          return _resolvedBase;
        }
      } catch (_) { /* port not responding, try next */ }
    }
    return null;
  }

  static void resetDiscovery() => _resolvedBase = null;

  static Future<bool> ping() async {
    resetDiscovery();
    return await _discoverBase() != null;
  }

  // ══════════════════════════════════════════════════════
  //  TOKEN MANAGEMENT
  // ══════════════════════════════════════════════════════
  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  static Future<void> saveToken(String t) async =>
      (await SharedPreferences.getInstance()).setString(_tokenKey, t);

  static Future<void> clearToken() async =>
      (await SharedPreferences.getInstance()).remove(_tokenKey);

  // ══════════════════════════════════════════════════════
  //  HTTP HELPERS
  // ══════════════════════════════════════════════════════
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    // Use discovered base, fall back to constant if not yet discovered
    final base = _resolvedBase ?? AppConstants.baseUrl;
    final uri  = Uri.parse('$base$path');
    if (query == null) return uri;
    final q = <String, String>{};
    query.forEach((k, v) { if (v != null) q[k] = v.toString(); });
    return uri.replace(queryParameters: q);
  }

  static dynamic _parse(http.Response res) {
    // ignore: avoid_print
    print('[API] ${res.request?.url} ${res.statusCode}');
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body['data'] ?? body;
    }
    final msg = body['message'] ?? 'Request failed (${res.statusCode})';
    throw ApiException(msg, statusCode: res.statusCode);
  }

  // Ensure we have a resolved base before making any call
  static Future<void> _ensureDiscovered() async {
    if (_resolvedBase == null) await _discoverBase();
  }

  static Future<dynamic> _get(String path,
      [Map<String, dynamic>? query]) async {
    await _ensureDiscovered();
    final params = {
      ...?query,
      '_t': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    final res = await http.get(_uri(path, params), headers: await _headers());
    return _parse(res);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    await _ensureDiscovered();
    final res = await http.post(_uri(path),
        headers: await _headers(auth: auth), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    await _ensureDiscovered();
    final res = await http.put(_uri(path),
        headers: await _headers(), body: jsonEncode(body));
    return _parse(res);
  }

  static Future<void> _delete(String path) async {
    await _ensureDiscovered();
    final res = await http.delete(_uri(path), headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body);
      throw ApiException(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════════════════
  //  AUTH
  // ══════════════════════════════════════════════════════
  static Future<LoginResponse> login(String email, String password) async {
    final data = await _post(
        AppConstants.login, {'email': email, 'password': password},
        auth: false);
    final resp = LoginResponse.fromJson(data);
    await saveToken(resp.accessToken);
    return resp;
  }

  static Future<UserProfile> getMe() async {
    final data = await _get(AppConstants.me);
    return UserProfile.fromJson(data);
  }

  static Future<void> logout() async => clearToken();

  static Future<void> changePassword(String current, String newPass) async =>
      _post(AppConstants.changePassword,
          {'currentPassword': current, 'newPassword': newPass});

  static Future<void> registerUser({
    required String fullName,
    required String email,
    required String password,
    String role = 'Security',
  }) async =>
      _post(AppConstants.register,
          {'fullName': fullName, 'email': email,
           'password': password, 'role': role});

  // ══════════════════════════════════════════════════════
  //  HOSTS
  // ══════════════════════════════════════════════════════
  static Future<PagedResult<HostDto>> getHosts({
    String? search, bool? isActive,
    int page = 1, int pageSize = 50,
  }) async {
    final data = await _get(AppConstants.hosts, {
      if (search   != null) 'search':   search,
      if (isActive != null) 'isActive': isActive.toString(),
      'page': page, 'pageSize': pageSize,
    });
    return PagedResult<HostDto>(
      items:      (data['items'] as List).map((e) => HostDto.fromJson(e)).toList(),
      totalCount: data['totalCount'],
      page:       data['page'],
      pageSize:   data['pageSize'],
      totalPages: data['totalPages'],
    );
  }

  static Future<HostDto> createHost({
    required String name, required String email,
    String? phone,        required String department,
  }) async {
    final data = await _post(AppConstants.hosts, {
      'name': name, 'email': email,
      if (phone != null) 'phone': phone,
      'department': department,
    });
    return HostDto.fromJson(data);
  }

  static Future<HostDto> updateHost(String hostId, {
    required String name, required String email,
    String? phone,        required String department,
  }) async {
    final data = await _put('${AppConstants.hosts}/$hostId', {
      'name': name, 'email': email,
      if (phone != null) 'phone': phone,
      'department': department,
    });
    return HostDto.fromJson(data);
  }

  static Future<void> deactivateHost(String hostId) async =>
      _delete('${AppConstants.hosts}/$hostId');

  static Future<void> reactivateHost(String hostId) async =>
      _post('${AppConstants.hosts}/$hostId/reactivate', {});

  // ══════════════════════════════════════════════════════
  //  VISITORS
  // ══════════════════════════════════════════════════════
  static Future<PagedResult<VisitorEntryDto>> getVisitors({
    String? search, String? status, String? hostId,
    DateTime? dateFrom, DateTime? dateTo,
    int page = 1, int pageSize = 20,
  }) async {
    final data = await _get(AppConstants.visitors, {
      if (search   != null) 'search':   search,
      if (status   != null) 'status':   status,
      if (hostId   != null) 'hostId':   hostId,
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
      if (dateTo   != null) 'dateTo':   dateTo.toIso8601String(),
      'page': page, 'pageSize': pageSize,
    });
    return PagedResult<VisitorEntryDto>(
      items:      (data['items'] as List)
          .map((e) => VisitorEntryDto.fromJson(e)).toList(),
      totalCount: data['totalCount'],
      page:       data['page'],
      pageSize:   data['pageSize'],
      totalPages: data['totalPages'],
    );
  }

  static Future<VisitorEntryDetailDto> getVisitorById(String id) async {
    final data = await _get('${AppConstants.visitors}/$id');
    return VisitorEntryDetailDto.fromJson(data);
  }

  static Future<VisitorEntryDto> createVisitor({
    required String visitorName, required String mobile,
    String? email,  String? company,
    required String purpose,     required String hostId,
    String? idType, String? idNumber,
    bool isWalkIn = true,        DateTime? visitDateTime,
  }) async {
    final data = await _post(AppConstants.visitors, {
      'visitorName': visitorName, 'mobile': mobile,
      if (email   != null) 'email':   email,
      if (company != null) 'company': company,
      'purpose': purpose, 'hostId': hostId,
      if (idType   != null) 'idType':   idType,
      if (idNumber != null) 'idNumber': idNumber,
      'isWalkIn': isWalkIn,
      if (visitDateTime != null)
        'visitDateTime': visitDateTime.toIso8601String(),
    });
    return VisitorEntryDto.fromJson(data);
  }

  static Future<CheckInOutResponse> checkIn(String entryId,
      {String? qrToken}) async {
    final data = await _post(AppConstants.checkin, {
      'entryId': entryId,
      if (qrToken != null) 'qrToken': qrToken,
    });
    return CheckInOutResponse.fromJson(data);
  }

  static Future<CheckInOutResponse> checkOut(String entryId,
      {String? remarks}) async {
    final data = await _post(AppConstants.checkout, {
      'entryId': entryId,
      if (remarks != null) 'remarks': remarks,
    });
    return CheckInOutResponse.fromJson(data);
  }

  static Future<DashboardStats> getDashboard() async {
    final data = await _get(AppConstants.dashboard);
    return DashboardStats.fromJson(data);
  }

  /// Single API call: looks up QR token AND performs check-in or check-out.
  /// Returns null only if the server itself is unreachable.
  static Future<SmartScanResult> smartScan(String token, {String? remarks}) async {
    final data = await _post('/visitors/smart-scan', {
      'qrToken':  token,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return SmartScanResult.fromJson(data);
  }

  /// Fetch the base64 PNG QR code image for a visitor badge.
  /// Returns the raw base64 string (no data-URI prefix).
  static Future<String> getQrCodeImage(String entryId) async {
    await _ensureDiscovered();
    final uri = _uri('/visitors/$entryId/qrcode');
    final res = await http.get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 10));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(body['message'] ?? 'Failed to load QR code');
    }
    // .NET serialises QrImageBase64 → qrImageBase64
    // Strip any whitespace/newlines .NET may have inserted in the base64 string
    final raw = body['data']['qrImageBase64'] as String;
    return raw.replaceAll(RegExp(r'\s+'), '');
  }

  static Future<QrScanResult?> qrLookup(String token) async {
    try {
      final data = await _get('/visitors/scan/$token');
      return QrScanResult.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<VisitorEntryDto?> lookupByQr(String token) async {
    try {
      final data = await _get('/visitors/by-token/$token');
      return VisitorEntryDetailDto.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}