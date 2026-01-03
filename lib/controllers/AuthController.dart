import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  var user = Rxn<User>();
  var isLoading = false.obs;
  var isSendingLink = false.obs;
  bool get isLoggedIn => user.value != null;

  static const String _emailLinkPrefsKey = 'emailForSignIn';

  @override
  void onInit() {
    super.onInit();
    _auth.authStateChanges().listen((u) {
      user.value = u;
    });
  }

  String get uid => _auth.currentUser?.uid ?? '';

  /// Checks if a given URL is a Firebase sign-in link
  bool isSignInLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  // ----------------- Custom Notification Helper -----------------
  void _showCustomNotification(String message, {bool isError = false}) {
    final bool isDarkMode = Get.isDarkMode;
    final Color bgColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isError
        ? Colors.red.shade300
        : (isDarkMode ? Colors.white : Colors.black);
    final Color borderColor = isError
        ? Colors.red.shade300
        : (isDarkMode ? Color(0xFF333333) : Color(0xFFE0E0E0));

    Get.rawSnackbar(
      messageText: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
      backgroundColor: bgColor,
      snackPosition: SnackPosition.BOTTOM,
      borderRadius: 10,
      margin: EdgeInsets.only(bottom: 30, left: 15, right: 15),
      maxWidth: 500,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderColor: borderColor,
      borderWidth: 1,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
      duration: Duration(seconds: 3),
      animationDuration: Duration(milliseconds: 300),
      snackStyle: SnackStyle.FLOATING,
    );
  }

  // ----------------- EMAIL SIGN UP -----------------
  // UPDATED: Now sends verification email and signs user out.
  Future<bool> signUp(String email, String password) async {
    try {
      isLoading.value = true;
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user was created
      if (userCredential.user != null) {
        // Send verification email
        await userCredential.user!.sendEmailVerification();

        _showCustomNotification(
            'Account created! Please check your email to verify your account.');

        // Sign the user out so they have to log in *after* verification
        await _auth.signOut();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      String message = switch (e.code) {
        'weak-password' => 'Password is too weak',
        'email-already-in-use' => 'Email is already registered',
        'invalid-email' => 'Invalid email address',
        _ => 'An error occurred',
      };
      _showCustomNotification(message, isError: true);
      return false;
    } catch (e) {
      _showCustomNotification('Sign up failed: $e', isError: true);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------- EMAIL SIGN IN -----------------
  // UPDATED: Now checks if email is verified.
  Future<bool> signIn(String email, String password) async {
    try {
      isLoading.value = true;
      final userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      // ADDED: Verification Check
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        // Resend verification email and notify user
        await userCredential.user!.sendEmailVerification();
        _showCustomNotification(
            'Please verify your email. A new verification link has been sent.',
            isError: true);

        await _auth.signOut(); // Sign them out
        return false;
      }

      // If we get here, user is not null AND is emailVerified
      _showCustomNotification('Logged in successfully!');
      return true;
    } on FirebaseAuthException catch (e) {
      String message = switch (e.code) {
        'user-not-found' => 'No user found with this email',
        'wrong-password' => 'Incorrect password',
        'invalid-email' => 'Invalid email address',
        'user-disabled' => 'This account has been disabled',
        _ => 'An error occurred',
      };
      _showCustomNotification(message, isError: true);
      return false;
    } catch (e) {
      _showCustomNotification('Login failed: $e', isError: true);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------- GOOGLE SIGN IN (Web + Android) -----------------
  // UPDATED: Now checks if email is verified.
  Future<bool> signInWithGoogle() async {
    UserCredential? userCredential;
    try {
      isLoading.value = true;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // Mobile (Android/iOS): Existing flow
        final signIn = GoogleSignIn.instance;
        await signIn.initialize();
        final googleUser = await signIn.authenticate();
        if (googleUser == null) {
          isLoading.value = false;
          return false;
        }
        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null) {
          throw Exception("Google ID Token is null");
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        userCredential = await _auth.signInWithCredential(credential);
      }

      // ADDED: Verification Check (for both web and mobile)
      if (userCredential != null &&
          userCredential.user != null &&
          !userCredential.user!.emailVerified) {
        _showCustomNotification(
            'Your email is not verified. Please check your inbox.',
            isError: true);

        // This happens if they signed up with email/pass first
        // and are now linking with Google.
        await userCredential.user!.sendEmailVerification();

        await _auth.signOut();
        await GoogleSignIn.instance.signOut();
        return false;
      }

      // If we get here, user is verified.
      _showCustomNotification('Logged in with Google successfully!');
      return true;
    } on FirebaseAuthException catch (e) {
      _showCustomNotification(e.message ?? 'Unknown Firebase error',
          isError: true);
      return false;
    } catch (e) {
      _showCustomNotification('Google sign-in failed: $e', isError: true);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------- EMAIL LINK SIGN IN (PASSWORDLESS) -----------------
  Future<bool> sendSignInLink(String email) async {
    // ... (This method is unchanged)
    final actionCodeSettings = ActionCodeSettings(
      url: kIsWeb
          ? '${Uri.base.origin}'
          : 'https://vyuha.page.link/auth', // <--- !! REPLACE THIS !!
      handleCodeInApp: true,
      iOSBundleId: 'com.example.vyuha', // <--- !! REPLACE THIS !!
      androidPackageName: 'com.example.vyuha', // <--- !! REPLACE THIS !!
      androidInstallApp: true,
      androidMinimumVersion: '12',
    );

    try {
      isSendingLink.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emailLinkPrefsKey, email);
      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
      _showCustomNotification('Sign-in link sent! Please check your email.');
      return true;
    } on FirebaseAuthException catch (e) {
      _showCustomNotification(e.message ?? 'Failed to send link', isError: true);
      return false;
    } catch (e) {
      _showCustomNotification('An error occurred: $e', isError: true);
      return false;
    } finally {
      isSendingLink.value = false;
    }
  }

  /// Checks if the user is returning from a sign-in link
  /// and completes the authentication.
  Future<bool> handleEmailLinkSignIn(String link) async {
    // ... (This method is unchanged)
    if (!_auth.isSignInWithEmailLink(link)) {
      return false;
    }
    try {
      isLoading.value = true;
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_emailLinkPrefsKey);

      if (email == null || email.isEmpty) {
        throw Exception('Email not found. Please try sending the link again.');
      }
      // This method automatically signs in and verifies the email.
      await _auth.signInWithEmailLink(email: email, emailLink: link);
      await prefs.remove(_emailLinkPrefsKey);
      _showCustomNotification('Logged in successfully!');
      return true;
    } on FirebaseAuthException catch (e) {
      _showCustomNotification(e.message ?? 'Invalid link or link expired',
          isError: true);
      return false;
    } catch (e) {
      _showCustomNotification('Login failed: $e', isError: true);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------- SIGN OUT -----------------
  Future<void> signOut() async {
    // ... (This method is unchanged)
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.signOut();
      await _auth.signOut();
      _showCustomNotification('You have been logged out successfully');
    } catch (e) {
      // _showCustomNotification('Failed to log out: $e', isError: true);
    }
  }

  /// Checks if the current user's profile is complete (has name & username).
  Future<bool> isProfileComplete() async {
    if (_auth.currentUser == null) return false;

    try {
      final doc =
          await _firestore.collection('users').doc(_auth.currentUser!.uid).get();

      if (!doc.exists) {
        // Document doesn't exist, profile is incomplete
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Check if 'name' and 'username' fields exist and are not empty
      final name = data['name'] as String?;
      final username = data['username'] as String?;

      return (name != null && name.isNotEmpty) &&
          (username != null && username.isNotEmpty);
    } catch (e) {
      print("Error checking profile: $e");
      // If there's an error, assume incomplete to be safe
      return false;
    }
  }

  /// Checks if a username is unique across the 'users' collection.
  // REPLACE this method in AuthController.dart

  /// --- NEW METHOD 2 (Updated) ---
  /// Checks if a username is unique across the 'users' collection.
  Future<bool> checkUsernameUnique(String username) async {
    // Added this check
    if (_auth.currentUser == null) return false;
    final String currentUid = _auth.currentUser!.uid;

    try {
      final snap = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1) // Only need to find one
          .get();

      if (snap.docs.isEmpty) {
        // 1. No documents were found with this username.
        // It is 100% unique and available.
        return true;
      }

      // 2. A document was found. We must check who it belongs to.
      final String docOwnerUid = snap.docs.first.id;

      if (docOwnerUid == currentUid) {
        // 3. The document found belongs to the current user.
        // This means they are just re-saving their own username.
        // We will allow this.
        return true;
      }

      // 4. The document found belongs to a *different* user.
      // The username is truly taken.
      return false;
    } catch (e) {
      print("Error checking username: $e");

      // --- MODIFIED: Replaced Get.snackbar with _showCustomNotification ---
      _showCustomNotification(
        'Database Error: Failed to check username. Check console for details. You may be missing a Firestore Index.',
        isError: true,
      );
      return false; // Safer to fail validation on error
    }
  }

  /// Saves the user's name and username to their document.
  Future<void> saveProfile(String name, String username) async {
    if (_auth.currentUser == null) return;

    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
        'name': name,
        'username': username,
        'email': _auth.currentUser!.email, // Good to save this too
        'uid': _auth.currentUser!.uid,
      }, SetOptions(merge: true)); // merge: true won't overwrite other fields
    } catch (e) {
      // --- MODIFIED: Replaced Get.snackbar with _showCustomNotification ---
      _showCustomNotification(
        'Failed to save profile: ${e.toString()}',
        isError: true,
      );
    }
  }

  // In your AuthController class:
  Future<void> sendPasswordReset(String email) async {
    isLoading.value = true;
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      // --- MODIFIED: Replaced Get.snackbar with _showCustomNotification ---
      _showCustomNotification(
        'Password Reset Sent! Please check your email ($email) for a password reset link.',
      );
    } on FirebaseAuthException catch (e) {
      // Show a more specific error if possible
      String errorMessage = e.message ?? 'An unknown error occurred.';
      // --- MODIFIED: Replaced Get.snackbar with _showCustomNotification ---
      _showCustomNotification(
        errorMessage,
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }
}