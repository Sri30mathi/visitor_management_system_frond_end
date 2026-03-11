// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthState    _state        = AuthState.unknown;
  UserProfile? _user;
  String?      _error;
  bool         _serverOnline = false;
  bool         _checkingServer = false;
  Timer?       _retryTimer;

  AuthState    get state          => _state;
  UserProfile? get user           => _user;
  String?      get error          => _error;
  bool         get serverOnline   => _serverOnline;
  bool         get checkingServer => _checkingServer;
  bool         get isAdmin        => _user?.role == 'Admin';
  bool         get isSecurity     => _user?.role == 'Security' || isAdmin;

  // ── Init ────────────────────────────────────────────────
  Future<void> init() async {
    await _checkServer();
    if (!_serverOnline) {
      // Server offline — stay on unknown state but start retrying
      _startRetrying();
      return;
    }
    await _restoreSession();
  }

  // ── Check if server is reachable ────────────────────────
  Future<void> _checkServer() async {
    _checkingServer = true;
    notifyListeners();
    try {
      _serverOnline = await ApiService.ping();
    } catch (_) {
      _serverOnline = false;
    }
    _checkingServer = false;
    notifyListeners();
  }

  // ── Retry connecting every 5 seconds when offline ───────
  void _startRetrying() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkServer();
      if (_serverOnline) {
        _retryTimer?.cancel();
        await _restoreSession();
      }
    });
  }

  // Manual retry button press
  Future<void> retryConnection() async {
    _retryTimer?.cancel();
    _error = null;
    _state = AuthState.unknown;
    notifyListeners();
    await _checkServer();
    if (_serverOnline) {
      await _restoreSession();
    } else {
      _startRetrying();
    }
  }

  // ── Restore session from saved token ────────────────────
  Future<void> _restoreSession() async {
    final token = await ApiService.getToken();
    if (token == null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      _user  = await ApiService.getMe();
      _state = AuthState.authenticated;
    } catch (_) {
      await ApiService.clearToken();
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // ── Login ───────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _error = null;
    notifyListeners();

    // Quick server check before attempting login
    if (!_serverOnline) {
      await _checkServer();
      if (!_serverOnline) {
        _error = 'Server is offline. Please wait and try again.';
        notifyListeners();
        return false;
      }
    }

    try {
      final resp = await ApiService.login(email, password);
      _user = UserProfile(
        userId:    resp.userId,
        fullName:  resp.fullName,
        email:     email,
        role:      resp.role,
        createdAt: DateTime.now(),
      );
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _serverOnline = false;
      _error = 'Cannot reach server. Please check the backend is running.';
      _startRetrying();
      notifyListeners();
      return false;
    }
  }

  // ── Logout ──────────────────────────────────────────────
  Future<void> logout() async {
    _retryTimer?.cancel();
    await ApiService.logout();
    _user  = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}