// lib/services/auth_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
  );

  // ── Streams ──────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();
  Stream<User?> get userChanges => _auth.userChanges();

  User? get currentUser => _auth.currentUser;
  String get currentUserId => _auth.currentUser?.uid ?? '';
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // ═══════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════

  Future<void> initGoogleSignIn() async {
    try {
      await _googleSignIn.signOut();
      if (kDebugMode) {
        print('✅ Google Sign-In initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Google Sign-In initialization error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GOOGLE SIGN-IN
  // ═══════════════════════════════════════════════════════════

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Google Sign-In Firebase error: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      if (e.toString().contains('canceled')) {
        return null;
      }
      throw Exception('Google sign-in failed. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // EMAIL/PASSWORD REGISTRATION
  // ═══════════════════════════════════════════════════════════

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _validateEmail(email);
      _validatePassword(password);
      _validateName(name);

      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final User? user = credential.user;
      if (user == null) throw Exception('Failed to create account');

      await user.updateDisplayName(name);
      await user.sendEmailVerification();

      await _createUserDocument(user, name, email);
      await _createDefaultCategories(user.uid);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════
  // EMAIL/PASSWORD LOGIN
  // ═══════════════════════════════════════════════════════════

  Future<UserCredential> loginWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      _validateEmail(email);
      _validatePassword(password);

      final UserCredential credential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final User? user = credential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        throw Exception(
          'Please verify your email first. '
          'A new verification email has been sent to ${user.email}.'
        );
      }

      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.lastEmailKey, email.trim());
        await prefs.setBool(AppConstants.rememberMeKey, true);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PHONE AUTHENTICATION
  // ═══════════════════════════════════════════════════════════

  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(int? resendToken) onCodeAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            onError('Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_handleAuthException(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
          onCodeAutoRetrievalTimeout(resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onCodeAutoRetrievalTimeout(null);
        },
        timeout: AppConstants.authTimeout,
      );
    } catch (e) {
      onError('Failed to send verification code: $e');
    }
  }

  Future<UserCredential> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      final UserCredential userCredential = await _auth
          .signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ANONYMOUS LOGIN
  // ═══════════════════════════════════════════════════════════

  Future<UserCredential> signInAnonymously() async {
    try {
      final UserCredential credential = await _auth
          .signInAnonymously();
      
      if (credential.user != null) {
        await _createUserDocument(
          credential.user!,
          'Guest User',
          'guest@temporary.local',
        );
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PASSWORD MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  Future<void> resetPassword(String email) async {
    try {
      _validateEmail(email);
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      if (user.email == null) throw Exception('No email associated');
      
      _validatePassword(newPassword);

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ PROFILE MANAGEMENT (ADDED)
  // ═══════════════════════════════════════════════════════════

  Future<void> updateProfile({
    String? name,
    String? photoURL,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      if (name != null || photoURL != null) {
        if (name != null) await user.updateDisplayName(name);
        if (photoURL != null) await user.updatePhotoURL(photoURL);
      }

      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (photoURL != null) updates['avatar'] = photoURL;
      if (settings != null) updates['settings'] = settings;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      if (updates.isNotEmpty) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .update(updates);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ ACCOUNT MANAGEMENT (ADDED)
  // ═══════════════════════════════════════════════════════════

  Future<void> deleteAccount() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final batch = _firestore.batch();
      
      final collections = [
        AppConstants.itemsCollection,
        AppConstants.categoriesCollection,
        AppConstants.cabinetsCollection,
        AppConstants.boxesCollection,
        AppConstants.notificationsCollection,
        AppConstants.doorLogsCollection,
      ];

      for (final collection in collections) {
        final snapshot = await _firestore
            .collection(collection)
            .where('userId', isEqualTo: user.uid)
            .get();
        
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      batch.delete(
        _firestore.collection(AppConstants.usersCollection).doc(user.uid),
      );
      
      await batch.commit();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      if (user.email == null) throw Exception('No email associated');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SIGN OUT
  // ═══════════════════════════════════════════════════════════

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.rememberMeKey);
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      await _auth.signOut();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // USER DATA METHODS
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      
      return snapshot.exists ? snapshot.data() : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user data: $e');
      }
      return null;
    }
  }

  Future<void> _createOrUpdateUser(User user) async {
    try {
      final docRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid);
      
      final doc = await docRef.get();
      
      if (!doc.exists) {
        await _createUserDocument(
          user,
          user.displayName ?? 'User',
          user.email ?? '',
        );
        await _createDefaultCategories(user.uid);
      } else {
        await docRef.update({
          'email': user.email ?? '',
          'name': user.displayName ?? 'User',
          'avatar': user.photoURL ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating/updating user: $e');
      }
    }
  }

  Future<void> _createUserDocument(User user, String name, String email) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'email': email.trim(),
      'name': name.trim(),
      'avatar': user.photoURL ?? '',
      'emailVerified': user.emailVerified,
      'settings': {
        'language': 'en',
        'theme': 'light',
        'notificationEnabled': true,
        'expiryNotification': true,
        'stockNotification': true,
        'biometricEnabled': false,
        'doorNotifications': true,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createDefaultCategories(String userId) async {
    try {
      final batch = _firestore.batch();
      
      for (final category in AppConstants.defaultCategories) {
        final docRef = _firestore
            .collection(AppConstants.categoriesCollection)
            .doc();
        
        batch.set(docRef, {
          ...category,
          'userId': userId,
          'itemCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating default categories: $e');
      }
    }
  }

  // ── Validation ──────────────────────────────────────────
  void _validateEmail(String email) {
    if (email.trim().isEmpty) {
      throw Exception('Email is required');
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      throw Exception('Please enter a valid email address');
    }
  }

  void _validatePassword(String password) {
    if (password.isEmpty) {
      throw Exception('Password is required');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
  }

  void _validateName(String name) {
    if (name.trim().isEmpty) {
      throw Exception('Name is required');
    }
    if (name.length < 2) {
      throw Exception('Name must be at least 2 characters');
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Invalid email address. Please check and try again.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return AppConstants.authErrorTooManyRequests;
      case 'network-request-failed':
        return AppConstants.authErrorNetwork;
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please use another method.';
      case 'requires-recent-login':
        return 'Please sign in again to continue this action.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method. Please sign in using ${e.email}.';
      case 'credential-already-in-use':
        return 'This account is already linked to another user.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-phone-number':
        return 'Invalid phone number. Please enter a valid number.';
      default:
        return e.message ?? AppConstants.authErrorDefault;
    }
  }

  void dispose() {
    // Clean up
  }
}