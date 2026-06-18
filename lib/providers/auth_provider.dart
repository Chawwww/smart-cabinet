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
    _authService.authStateChanges.listen(
      (User? user) {
        if (user != null) {
          _loadUserData(user.uid);
        } else {
          _currentUser = null;
          _isLoggedIn = false;
          notifyListeners();
        }
      },
    );
  }

  // ==========================
  // Load User Data
  // ==========================
  Future<void> _loadUserData(
    String uid,
  ) async {
    try {
      final data =
          await _authService.getUserData(uid);

      if (data != null) {
        _currentUser = UserModel.fromMap(
          data,
          uid,
        );

        _isLoggedIn = true;
      }
    } catch (e) {
      debugPrint(
        'Error loading user data: $e',
      );
    }

    notifyListeners();
  }

  // ==========================
  // Check Login Status
  // ==========================
  Future<void> checkAuthStatus() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user != null) {
      await _loadUserData(
        user.uid,
      );
    } else {
      _currentUser = null;
      _isLoggedIn = false;

      notifyListeners();
    }
  }

  // ==========================
  // Register
  // ==========================
  Future<bool> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      _setLoading(true);

      _errorMessage = null;

      await _authService
          .registerWithEmailAndPassword(
        email,
        password,
        name,
      );

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Login
  // ==========================
  Future<bool> login(
    String email,
    String password,
  ) async {
    try {
      _setLoading(true);

      _errorMessage = null;

      await _authService
          .loginWithEmailAndPassword(
        email,
        password,
      );

      return true;
    } catch (e) {
      _errorMessage = e.toString();

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
  Future<bool> resetPassword(
    String email,
  ) async {
    try {
      _setLoading(true);

      _errorMessage = null;

      await _authService.resetPassword(
        email,
      );

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================
  // Update Profile
  // ==========================
  Future<void> updateProfile({
    String? name,
    String? avatar,
  }) async {
    try {
      _setLoading(true);

      await _authService.updateProfile(
        name: name,
        avatar: avatar,
      );

      if (_currentUser != null) {
        _currentUser =
            _currentUser!.copyWith(
          name: name,
          avatar: avatar,
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint(
        'Update profile error: $e',
      );
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
      debugPrint(
        'Delete account error: $e',
      );
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

  void _setLoading(
    bool value,
  ) {
    _isLoading = value;

    notifyListeners();
  }
}