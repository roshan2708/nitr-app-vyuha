// FILE: ProfileCheckRouter.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vyuha/Screens/HomeScren.dart';
import 'package:vyuha/Screens/SetupProfileScreen.dart';
import 'package:vyuha/controllers/AuthController.dart';
import 'package:vyuha/AppThemes.dart'; // Make sure this import is correct

class ProfileCheckRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AuthController auth = Get.find<AuthController>();
    final customTheme = Theme.of(context).extension<CustomTheme>()!;

    return FutureBuilder<bool>(
      future: auth.isProfileComplete(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a full-screen loading indicator
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  customTheme.accentOrange,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          // Handle error state, maybe send back to login
          Get.offAllNamed('/login');
          return Scaffold(body: Center(child: Text('Error loading profile.')));
        }

        if (snapshot.data == true) {
          // Profile is complete, show the real HomeScreen
          return HomeScreen();
        } else {
          // Profile is incomplete, show the setup screen
          return SetupProfileScreen();
        }
      },
    );
  }
}