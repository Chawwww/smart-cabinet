import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    // Listen to Firebase auth state — handles app restart / token expiry
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _currentUser = null;
        _isLoggedIn = false;
        notifyListeners();
      }
    });
  }

  // ==========================
  // Google Sign-In
  // ==========================
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      _errorMessage = null;
      final result = await _authService.signInWithGoogle();
      if (result == null) return false; // user cancelled
      final uid = result.user?.uid;
      if (uid != null) await _loadUserData(uid);
      return _isLoggedIn;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Load User Data
  // ==========================
  Future<void> _loadUserData(String uid) async {
    try {
      final data = await _authService.getUserData(uid);
      if (data != null) {
        _currentUser = UserModel.fromMap(data, uid);
        _isLoggedIn = true;
      } else {
        // User exists in Firebase Auth but not in Firestore yet (race after register)
        // Retry once after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        final retryData = await _authService.getUserData(uid);
        if (retryData != null) {
          _currentUser = UserModel.fromMap(retryData, uid);
          _isLoggedIn = true;
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
    notifyListeners();
  }

  // ==========================
  // Check Login Status
  // ==========================
  Future<void> checkAuthStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _loadUserData(user.uid);
    } else {
      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  // ==========================
  // Register
  // ==========================
  Future<bool> register(String name, String email, String password) async {
    try {
      _setLoading(true);
      _errorMessage = null;
      await _authService.registerWithEmailAndPassword(email, password, name);
      // Wait for Firestore write to propagate, then load user
      await Future.delayed(const Duration(milliseconds: 800));
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await _loadUserData(user.uid);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Login
  // ==========================
  Future<bool> login(String email, String password) async {
    try {
      _setLoading(true);
      _errorMessage = null;
      final credential =
          await _authService.loginWithEmailAndPassword(email, password);
      final uid = credential.user?.uid;
      if (uid != null) await _loadUserData(uid);
      return _isLoggedIn;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Logout
  // ==========================
  Future<void> logout() async {
    try {
      _setLoading(true);
      await _authService.signOut();
      _currentUser = null;
      _isLoggedIn = false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Reset Password
  // ==========================
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _errorMessage = null;
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Update Profile
  // ==========================
  Future<void> updateProfile({String? name, String? avatar}) async {
    try {
      _setLoading(true);
      await _authService.updateProfile(name: name, avatar: avatar);
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          name: name,
          avatar: avatar,
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Delete Account
  // ==========================
  Future<void> deleteAccount() async {
    try {
      _setLoading(true);
      await _authService.deleteAccount();
      _currentUser = null;
      _isLoggedIn = false;
    } catch (e) {
      debugPrint('Delete account error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Helpers
  // ==========================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}