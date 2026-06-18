import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  // ==========================
  // Register
  // ==========================
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Failed to create account');
      }

      await user.updateDisplayName(name);

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'email': email.trim(),
        'name': name,
        'avatar': '',
        'settings': {
          'language': 'en',
          'theme': 'light',
          'notificationEnabled': true,
          'expiryNotification': true,
          'stockNotification': true,
          'biometricEnabled': false,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _createDefaultCategories(user.uid);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ==========================
  // Login
  // ==========================
  Future<UserCredential> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ==========================
  // Sign Out
  // ==========================
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==========================
  // Reset Password
  // ==========================
  Future<void> resetPassword(
    String email,
  ) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ==========================
  // Change Password
  // ==========================
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final credential =
          EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(
        credential,
      );

      await user.updatePassword(
        newPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
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
      final user = currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      if (name != null) {
        await user.updateDisplayName(name);
      }

      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) {
        data['name'] = name;
      }

      if (avatar != null) {
        data['avatar'] = avatar;
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update(data);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ==========================
  // Get User Data
  // ==========================
  Future<Map<String, dynamic>?> getUserData(
    String uid,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      return snapshot.data();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user data: $e');
      }

      return null;
    }
  }

  // ==========================
  // Delete Account
  // ==========================
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .delete();

      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ==========================
  // Create Default Categories
  // ==========================
  Future<void> _createDefaultCategories(
    String userId,
  ) async {
    final batch = _firestore.batch();

    for (final category in AppConstants.defaultCategories) {
      final docRef =
          _firestore.collection(
            AppConstants.categoriesCollection,
          ).doc();

      batch.set(docRef, {
        ...category,
        'userId': userId,
        'itemCount': 0,
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ==========================
  // Error Handling
  // ==========================
  String _handleAuthException(
    FirebaseAuthException e,
  ) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';

      case 'wrong-password':
        return 'Wrong password provided.';

      case 'email-already-in-use':
        return 'Email already exists.';

      case 'invalid-email':
        return 'Invalid email address.';

      case 'weak-password':
        return 'Password is too weak.';

      case 'too-many-requests':
        return 'Too many requests. Please try again later.';

      case 'network-request-failed':
        return 'Network connection failed.';

      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}