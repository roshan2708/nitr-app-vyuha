// FILE: SetupProfileScreen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vyuha/controllers/AuthController.dart';
import 'package:vyuha/AppThemes.dart'; // Make sure this import is correct

class SetupProfileScreen extends StatefulWidget {
  @override
  _SetupProfileScreenState createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final AuthController auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final RxBool _isLoading = false.obs;

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();

    // 1. Check if username is unique
    final bool isUnique = await auth.checkUsernameUnique(username);

    if (!isUnique) {
      Get.snackbar(
        'Username Taken',
        'This username is already in use. Please try another.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
      );
      _isLoading.value = false;
      return;
    }

    // 2. Save the profile
    await auth.saveProfile(name, username);
    _isLoading.value = false;

    // 3. Navigate to the app's home
    Get.offAllNamed('/home');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<CustomTheme>()!;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One Last Step...',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Let\'s set up your profile. Your username must be unique.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  SizedBox(height: 32),
                  // Full Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: _buildInputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g., Roshan Singh',
                      icon: Icons.person_outline,
                      customTheme: customTheme
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: _buildInputDecoration(
                      labelText: 'Username',
                      hintText: 'e.g., roshan_singh',
                      icon: Icons.alternate_email,
                      customTheme: customTheme
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.contains(' ') || value.length < 3) {
                        return 'No spaces, min 3 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 32),
                  // Submit Button
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading.value ? null : _submitProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customTheme.accentOrange,
                          disabledBackgroundColor:
                              customTheme.accentOrange.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading.value
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Save and Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
    required CustomTheme customTheme
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: Theme.of(context).textTheme.labelMedium,
      hintText: hintText,
      hintStyle: TextStyle(color: Theme.of(context).hintColor),
      prefixIcon: Icon(icon, color: customTheme.accentOrange),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: customTheme.accentOrange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Colors.red.shade400,
          width: 2,
        ),
      ),
    );
  }
}