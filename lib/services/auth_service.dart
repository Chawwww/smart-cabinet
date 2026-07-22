// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Auth State Stream ──────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String get currentUserId => _auth.currentUser?.uid ?? '';
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // ── User Data ─────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Update User Data ────────────────────────────────────
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  // ── Upload Profile Image (FIXED) ────────────────────────
  // - Adds a hard timeout so a dropped connection fails fast
  //   instead of hanging until Firebase cancels it silently
  //   (StorageException Code -13040, HttpResult: 0).
  // - Surfaces the real FirebaseException code/message instead
  //   of burying it in a generic wrapper.
  // - Explicitly cancels the upload task on timeout so it
  //   doesn't keep retrying in the background.
  Future<String?> uploadProfileImage(File image, String userId) async {
    late final UploadTask uploadTask;
    try {
      final ref = _storage.ref().child(
            'profile_images/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

      uploadTask = ref.putFile(image);

      // Log progress/state — helpful for diagnosing dropped connections.
      uploadTask.snapshotEvents.listen((event) {
        debugPrint(
          '📤 Upload state: ${event.state}, '
          '${event.bytesTransferred}/${event.totalBytes} bytes',
        );
      });

      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          uploadTask.cancel();
          throw Exception(
            'Upload timed out — check your internet connection and try again.',
          );
        },
      );

      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('❌ FirebaseException during upload: ${e.code} — ${e.message}');
      if (e.code == 'canceled') {
        throw Exception(
          'Photo upload was interrupted — check your connection and try again.',
        );
      }
      throw Exception('Failed to upload image (${e.code}): ${e.message}');
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // ── Email/Password Register ──────────────────────────
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _createUserDocument(
        uid: credential.user!.uid,
        email: email,
        name: name,
      );

      await credential.user!.sendEmailVerification();

      return credential;
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ── Email/Password Login ─────────────────────────────
  Future<UserCredential> loginWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_email', email);
        await prefs.setBool('remember_me', true);
      }

      return credential;
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ── Google Sign-In ────────────────────────────────────
  // NOTE: If this throws ApiException/DEVELOPER_ERROR (statusCode
  // DEVELOPER_ERROR), the code itself is fine — it means the SHA-1/
  // SHA-256 fingerprint of your signing key isn't registered in the
  // Firebase console for this app, or google-services.json is stale.
  // Run `cd android && ./gradlew signingReport`, add the debug
  // fingerprints under Firebase Console → Project Settings → your
  // Android app, then re-download google-services.json.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? googleUser.email,
          name: userCredential.user!.displayName ?? googleUser.displayName ?? 'User',
          avatar: userCredential.user!.photoURL,
        );
      }

      return userCredential;
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  // ── Phone Authentication ─────────────────────────────
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(String timeout) onCodeAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onCodeAutoRetrievalTimeout(verificationId);
        },
      );
    } catch (e) {
      onError(e.toString());
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
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ── Anonymous Login ───────────────────────────────────
  Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ── Reset Password ────────────────────────────────────
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ── Change Password ───────────────────────────────────
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ── Update Profile ────────────────────────────────────
  Future<void> updateProfile({
    String? name,
    String? photoURL,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      if (name != null) await user.updateDisplayName(name);
      if (photoURL != null) await user.updatePhotoURL(photoURL);

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) updates['name'] = name;
      if (photoURL != null) updates['avatar'] = photoURL;
      if (settings != null) updates['settings'] = settings;

      await _firestore.collection('users').doc(user.uid).update(updates);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // ── Delete Account ────────────────────────────────────
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      await _firestore.collection('users').doc(user.uid).delete();

      final ref = _storage.ref().child('profile_images/${user.uid}');
      try {
        await ref.listAll().then((result) {
          for (final item in result.items) {
            item.delete();
          }
        });
      } catch (_) {}

      await user.delete();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // ── Sign Out ──────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // ── Private Helpers ────────────────────────────────────

  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String name,
    String? avatar,
  }) async {
    final userData = {
      'uid': uid,
      'email': email,
      'name': name,
      'avatar': avatar,
      'emailVerified': false,
      'settings': {
        'darkMode': false,
        'notificationsEnabled': true,
        'biometricEnabled': false,
        'doorNotifications': true,
        'language': 'en',
      },
      'isPublic': false,
      'interests': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(uid).set(userData);
  }

  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        default:
          return error.message ?? 'Authentication failed.';
      }
    }
    return error.toString();
  }

  void dispose() {
    // Clean up if needed
  }
}