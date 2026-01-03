import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class IntroScreen extends StatefulWidget {
  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _onGetStarted() async {
    final box = GetStorage();
    await box.write('seenIntro', true);
    // Navigate to the root, InitialRouter will redirect to SplashRouter
    Get.offAllNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Color(0xFFF4991A); // Vyuha Orange
    final Color bgColor = isDarkMode ? Color(0xFF0D0D0D) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Color(0xFF0D0D0D);
    final Color subtextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _onGetStarted,
                child: Text(
                  'Skip',
                  style: TextStyle(color: primaryColor, fontSize: 16),
                ),
              ),
            ),

            // PageView for slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildIntroSlide(
                    context: context,
                    imageAsset: 'assets/images/icon.png', // Assuming this path
                    title: 'Welcome to Vyuha',
                    description:
                        'Visually orchestrate your ideas and bring your thoughts to life.',
                    titleColor: textColor,
                    descColor: subtextColor,
                  ),
                  _buildIntroSlide(
                    context: context,
                    // You can create/add more assets for other slides
                    iconData: Icons.hub_outlined,
                    iconColor: primaryColor,
                    title: 'Structure Your Mind',
                    description:
                        'Create beautiful, interconnected mind maps with ease.',
                    titleColor: textColor,
                    descColor: subtextColor,
                  ),
                  _buildIntroSlide(
                    context: context,
                    iconData: Icons.people_alt_outlined,
                    iconColor: Color(0xFF427A76), // Vyuha Teal
                    title: 'Collaborate in Real-Time',
                    description:
                        'Invite others and build your Vyuha together, instantly.',
                    titleColor: textColor,
                    descColor: subtextColor,
                  ),
                ],
              ),
            ),

            // Page Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? primaryColor
                        : Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),

            SizedBox(height: 40),

            // Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _onGetStarted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Get Started',
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
    );
  }

  Widget _buildIntroSlide({
    required BuildContext context,
    String? imageAsset,
    IconData? iconData,
    Color? iconColor,
    required String title,
    required String description,
    required Color titleColor,
    required Color descColor,
  }) {
    final double iconSize = MediaQuery.of(context).size.width * 0.3;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageAsset != null)
            Image.asset(
              imageAsset,
              height: iconSize,
              width: iconSize,
            )
          else if (iconData != null)
            Icon(
              iconData,
              size: iconSize,
              color: iconColor ?? titleColor,
            ),
          SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: descColor,
            ),
          ),
        ],
      ),
    );
  }
}
