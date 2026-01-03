// LoginScreen.dart (Updated)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vyuha/controllers/AuthController.dart';
// REMOVED: kIsWeb import
// REMOVED: platform_helper import

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController auth = Get.find<AuthController>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  // REMOVED: _isEmailLinkMode
  // REMOVED: PlatformHelper instance

  @override
  void initState() {
    super.initState();
    // REMOVED: _handleEmailLinkOnLoad();
  }

  // REMOVED: _handleEmailLinkOnLoad method

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ADDED: Method to handle forgot password
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !GetUtils.isEmail(email)) {
      Get.snackbar(
        'Error',
        'Please enter a valid email address in the field above.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
      );
      return;
    }

    // This will call the new method you add to AuthController
    // The controller will handle showing its own loading state and snackbars.
    await auth.sendPasswordReset(email);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    

    // SIMPLIFIED: Removed _isEmailLinkMode logic
    if (_isSignUp) {
      bool success = await auth.signUp(email, password);
      if (success) {
        setState(() {
          _isSignUp = false;
        });
      }
    } else {
      bool success = await auth.signIn(email, password);
      if (success) {
        Get.offAllNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (build method is unchanged)
    return Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 720) {
                return _buildWebLayout();
              } else {
                return _buildMobileLayout();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    // ... (This widget is unchanged)
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 900,
        maxHeight: 580,
      ),
      child: Card(
        elevation: 0,
        color: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.all(32),
                color: Colors.black.withOpacity(0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // MODIFIED: Changed from .start to .center
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 80,
                      width: 80,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.transparent,
                        backgroundImage:
                            AssetImage('assets/images/icon.png'),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Vyuha',
                      // MODIFIED: Added center align
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Visually orchestrate your ideas. Collaborate and create in real-time.',
                      // MODIFIED: Added center align
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                      child: _buildForm(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 16),
                    child: Text(
                      'Built by Senatrius',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    // ... (This widget is unchanged)
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // MODIFIED: Added cross axis alignment center
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.15,
              width: MediaQuery.of(context).size.width * 0.4,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage('assets/images/icon.png'),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Vyuha',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32),
            _buildForm(),
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                'Built by Senatrius',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    // SIMPLIFIED: Always return the password form
    return _buildPasswordForm();
  }

  // REMOVED: _buildEmailLinkForm widget

  Widget _buildPasswordForm() {
    // ... (This widget is unchanged)
    return Form(
      key: _formKey,
      child: Column(
        // MODIFIED: Changed from .start to .center
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isSignUp ? 'Create Account' : 'Welcome Back',
            // MODIFIED: Added center align
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _isSignUp ? 'स्वस्य खातं निर्मास्यताम्' : 'पुनरागमनं शुभं भवतु',
            // MODIFIED: Added center align
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ),
          SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            style: TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: _buildInputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              icon: Icons.email_outlined,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!GetUtils.isEmail(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            style: TextStyle(color: Colors.white),
            obscureText: _obscurePassword,
            decoration: _buildInputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              icon: Icons.lock_outline,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white54,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (_isSignUp && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          // ADDED: Forgot Password button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xFF9ECAD6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16), // Adjusted spacing
          Obx(
            () => SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: auth.isLoading.value ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF4991A),
                  disabledBackgroundColor: Color(0xFFF4991A).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: auth.isLoading.value
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isSignUp ? 'Sign Up' : 'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: Color(0xFF9ECAD6))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('OR', style: TextStyle(color: Colors.white54)),
              ),
              Expanded(child: Divider(color: Color(0xFF9ECAD6))),
            ],
          ),
          SizedBox(height: 20),
          Obx(
            () => SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: auth.isLoading.value
                    ? null
                    : () async {
                        bool success = await auth.signInWithGoogle();
                        if (success) {
                          Get.offAllNamed('/home');
                        }
                      },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF9ECAD6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // REMOVED: "Sign in with Email Link" button
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isSignUp
                    ? 'Already have an account?'
                    : "Don't have an account?",
                style: TextStyle(color: Colors.white54),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                  });
                },
                child: Text(
                  _isSignUp ? 'Login' : 'Sign Up',
                  style: TextStyle(
                    color: Color(0xFFF4991A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
  }) {
    // ... (This widget is unchanged)
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.white54),
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white38),
      prefixIcon: Icon(
        icon,
        color: Color(0xFFF4991A),
      ),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFF9ECAD6).withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Color(0xFFF4991A),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.red.shade400,
          width: 2,
        ),
      ),
    );
  }
}