// FILE: main.dart
import 'package:flutter/foundation.dart';
import 'package:vyuha/Screens/KramScreen.dart';
import 'package:vyuha/Screens/LandingPageScree.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_storage/get_storage.dart';
import 'package:vyuha/AppThemes.dart';
import 'package:vyuha/Screens/IntroScreen.dart'; 
import 'package:vyuha/Screens/LoginScreen.dart';
import 'package:vyuha/Screens/VyuhaScreen.dart';
import 'package:vyuha/controllers/AuthController.dart';
import 'package:vyuha/controllers/ThemeController.dart';
import 'package:vyuha/firebase_options.dart';

// --- IMPORT THE 2 NEW FILES ---
import 'package:vyuha/Screens/SetupProfileScreen.dart';
import 'package:vyuha/ProfileCheckRouter.dart'; // Adjust path if needed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize GetStorage
  await GetStorage.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize controllers
  Get.put(AuthController());
  Get.put(ThemeController());

  runApp(MindMapApp());
}

class MindMapApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    return GetMaterialApp(
      title: 'Vyuha',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeController.initialThemeMode,
      home: InitialRouter(),
      getPages: [
        GetPage(name: '/', page: () => InitialRouter()),
        
        // --- MODIFIED /home ROUTE ---
        // It now points to our new gatekeeper widget
        GetPage(name: '/home', page: () => ProfileCheckRouter()),
        
        GetPage(name: '/login', page: () => LoginScreen()),
        GetPage(name: '/intro', page: () => IntroScreen()),
        GetPage(name: '/landing', page: () => LandingScreen()),
        GetPage(
      name: '/kram/:roomId',
      page: () => KramScreen(roomId: Get.parameters['roomId']),
    ),
        

        // --- ADDED /setup-profile ROUTE ---
        GetPage(name: '/setup-profile', page: () => SetupProfileScreen()),

        // Add the dynamic route for Vyuha/MindMap screens
        GetPage(
          name: '/vyuha/:roomId',
          page: () {
            final roomId = Get.parameters['roomId'];
            if (roomId == null || roomId.isEmpty) {
              // If no roomId, redirect to home (which goes via profile check)
              return ProfileCheckRouter();
            }
            return VyuhaScreen(roomId: roomId);
          },
        ),
      ],
    );
  }
}

/// This router decides the very first screen to show.
/// On Web: Skips splash/intro and goes directly to Landing/Home.
/// On Mobile: Checks if the IntroScreen has been seen.
class InitialRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 1. WEB LOGIC
    if (kIsWeb) {
      // On web, skip intro and splash, go straight to auth check.
      // UPDATED: Show LandingScreen if not authed, HomeScreen if authed.
      final AuthController authController = Get.find<AuthController>();
      return Obx(() {
        if (authController.user.value == null) {
          // NOT LOGGED IN: Show the new LandingScreen
          return LandingScreen();
        } else {
          // LOGGED IN: Go to the profile check router
          return ProfileCheckRouter();
        }
      });
    }

    // 2. MOBILE LOGIC (Unchanged from previous step)
    // On mobile, check if intro has been seen
    final box = GetStorage();
    // Default to false if 'seenIntro' is null
    final bool seenIntro = box.read('seenIntro') ?? false;

    if (!seenIntro) {
      // Show intro screen for the first time
      return IntroScreen();
    }

    // If intro has been seen, show the normal animated splash router
    return SplashRouter();
  }
}

// Simple routing: if logged in -> home else -> login
class SplashRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Color(0xFF0F0F1E), Color(0xFF1A1A2E), Color(0xFF16213E)]
                : [Color(0xFFF0F4FF), Color(0xFFE8EFFF), Color(0xFFDDE7FF)],
          ),
        ),
        child: Obx(() {
          // This logic now only runs AFTER the IntroScreen check (on mobile)
          // or is skipped entirely (on web)
          if (authController.user.value == null) {
            return FutureBuilder(
              // This future is just for the splash animation duration
              future: Future.delayed(Duration(milliseconds: 1500)), // Shortened splash
              builder: (context, snapshot) {
                // While splash is animating, show animation
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Stack(
                    children: [
                      // ... (Animated background particles - unchanged)
                      ...List.generate(20, (index) {
                        final random = (index * 123) % 100;
                        final size = 2.0 + (random % 4);
                        final left = (random * 3.7) % 100;
                        final top = (random * 4.3) % 100;

                        return Positioned(
                          left:
                              MediaQuery.of(context).size.width * (left / 100),
                          top:
                              MediaQuery.of(context).size.height * (top / 100),
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0.2, end: 1.0),
                            duration:
                                Duration(milliseconds: 3000 + (random * 20)),
                            curve: Curves.easeInOut,
                            builder: (context, double value, child) {
                              return Opacity(
                                opacity: value * 0.6,
                                child: Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),

                      // Main content
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated logo with glow
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 1200),
                              curve: Curves.elasticOut,
                              builder: (context, double scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 1.0, end: 1.15),
                                    duration: Duration(milliseconds: 2000),
                                    curve: Curves.easeInOut,
                                    builder:
                                        (context, double pulse, child) {
                                      return Container(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.15,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.4,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.4 * pulse),
                                              blurRadius: 40 * pulse,
                                              spreadRadius: 10 * pulse,
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          backgroundColor: Colors.transparent,
                                          backgroundImage: AssetImage(
                                              'assets/images/icon.png'),
                                        ),
                                      );
                                    },
                                    onEnd: () {},
                                  ),
                                );
                              },
                            ),

                            SizedBox(height: 40),

                            // Animated text with shimmer effect
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 800),
                              curve: Curves.easeIn,
                              builder: (context, double opacity, child) {
                                return Opacity(
                                  opacity: opacity,
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.secondary,
                                        Theme.of(context).colorScheme.primary,
                                      ],
                                      stops: [0.0, 0.5, 1.0],
                                    ).createShader(bounds),
                                    child: Text(
                                      'Vyuha',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            SizedBox(height: 50),

                            // Modern loading indicator
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 800),
                              curve: Curves.easeIn,
                              builder: (context, double opacity, child) {
                                return Opacity(
                                  opacity: opacity,
                                  child: SizedBox(
                                    width: 200,
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.2),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                // When splash animation is done, show LoginScreen
                return LoginScreen();
              },
            );
          } else {
            // User is logged in, go to the profile check router
            return ProfileCheckRouter();
          }
        }),
      ),
    );
  }
}