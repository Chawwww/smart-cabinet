// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { 
  unauthenticated, 
  authenticating, 
  authenticated, 
  error 
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  AuthStatus _status = AuthStatus.unauthenticated;
  String? _errorMessage;
  
  StreamSubscription<User?>? _authSubscription;

  // ✅ Callback for logout
  VoidCallback? _onLogoutCallback;

  // ── Getters ──────────────────────────────────────────────
  UserModel? get currentUser => _currentUser;
  AuthStatus get status => _status;
  bool get isLoading => _status == AuthStatus.authenticating;
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get isEmailVerified => _authService.isEmailVerified;
  String? get errorMessage => _errorMessage;
  String get userId => _authService.currentUserId;

  // ✅ Set logout callback
  void setOnLogout(VoidCallback callback) {
    _onLogoutCallback = callback;
  }

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _authSubscription?.cancel();
    
    _authSubscription = _authService.authStateChanges.listen(
      (User? user) async {
        if (user != null) {
          _status = AuthStatus.authenticating;
          notifyListeners();
          
          final data = await _authService.getUserData(user.uid);
          if (data != null) {
            _currentUser = UserModel.fromMap(data, user.uid);
            _status = AuthStatus.authenticated;
            _errorMessage = null;
            debugPrint('✅ User loaded: ${_currentUser?.name} (${_currentUser?.email})');
          } else {
            _status = AuthStatus.error;
            _errorMessage = 'Failed to load user data';
          }
        } else {
          // ✅ Clear user data on logout
          _currentUser = null;
          _status = AuthStatus.unauthenticated;
          _errorMessage = null;
          debugPrint('🔴 User logged out, data cleared');
        }
        notifyListeners();
      },
      onError: (error) {
        _status = AuthStatus.error;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // ── Check Auth Status ───────────────────────────────────
  Future<bool> checkAuthStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _status = AuthStatus.authenticating;
      notifyListeners();
      
      final data = await _authService.getUserData(user.uid);
      if (data != null) {
        _currentUser = UserModel.fromMap(data, user.uid);
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        debugPrint('✅ Check auth: ${_currentUser?.name}');
        notifyListeners();
        return true;
      }
    }
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    notifyListeners();
    return false;
  }

  // ── Google Sign-In ──────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        final data = await _authService.getUserData(user.uid);
        if (data != null) {
          _currentUser = UserModel.fromMap(data, user.uid);
          _status = AuthStatus.authenticated;
          _errorMessage = null;
          debugPrint('✅ Google sign-in: ${_currentUser?.name}');
          notifyListeners();
          return true;
        }
      }
      
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Email/Password Register ─────────────────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      if (password != confirmPassword) {
        throw Exception('Passwords do not match');
      }

      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final data = await _authService.getUserData(user.uid);
        if (data != null) {
          _currentUser = UserModel.fromMap(data, user.uid);
          _status = AuthStatus.authenticated;
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Email/Password Login ────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      await _authService.loginWithEmailAndPassword(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final data = await _authService.getUserData(user.uid);
        if (data != null) {
          _currentUser = UserModel.fromMap(data, user.uid);
          _status = AuthStatus.authenticated;
          debugPrint('✅ Login: ${_currentUser?.name}');
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Phone Authentication ────────────────────────────────
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      await _authService.sendPhoneVerificationCode(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          onCodeSent(verificationId);
          _status = AuthStatus.unauthenticated;
          notifyListeners();
        },
        onError: (error) {
          _status = AuthStatus.error;
          _errorMessage = error;
          onError(error);
          notifyListeners();
        },
        onCodeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      await _authService.signInWithPhoneNumber(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final data = await _authService.getUserData(user.uid);
        if (data != null) {
          _currentUser = UserModel.fromMap(data, user.uid);
          _status = AuthStatus.authenticated;
        }
      }
      
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Anonymous Login ─────────────────────────────────────
  Future<bool> signInAnonymously() async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      await _authService.signInAnonymously();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final data = await _authService.getUserData(user.uid);
        if (data != null) {
          _currentUser = UserModel.fromMap(data, user.uid);
          _status = AuthStatus.authenticated;
        }
      }
      
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Reset Password ──────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      await _authService.resetPassword(email);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Change Password ─────────────────────────────────────
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Update Profile ──────────────────────────────────────
  Future<void> updateProfile({
    String? name,
    String? avatar,
    Map<String, dynamic>? settings,
  }) async {
    try {
      await _authService.updateProfile(
        name: name,
        photoURL: avatar,
        settings: settings,
      );
      
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          name: name,
          avatar: avatar,
          settings: settings ?? _currentUser!.settings,
          updatedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ── Delete Account ──────────────────────────────────────
  Future<bool> deleteAccount() async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      await _authService.deleteAccount();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Logout ──────────────────────────────────────────────
  Future<void> logout() async {
    try {
      _status = AuthStatus.authenticating;
      notifyListeners();
      
      // ✅ Clear local data first
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      
      // ✅ Call logout callback to clear provider data
      _onLogoutCallback?.call();
      
      // Then sign out from Firebase
      await _authService.signOut();
      
      debugPrint('🔴 Logout complete - user data cleared');
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ── Clear Error ─────────────────────────────────────────
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Refresh User Data ──────────────────────────────────
  Future<void> refreshUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      if (data != null) {
        _currentUser = UserModel.fromMap(data, user.uid);
        _status = AuthStatus.authenticated;
        debugPrint('🔄 User data refreshed: ${_currentUser?.name}');
        notifyListeners();
      }
    }
  }

  // ── Dispose ─────────────────────────────────────────────
  @override
  void dispose() {
    _authSubscription?.cancel();
    _authService.dispose();
    super.dispose();
  }
}