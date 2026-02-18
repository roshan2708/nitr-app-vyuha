import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // This screen is designed for web, so we'll use dark theme colors
    // directly to emulate that "Next.js" startup feel.
    final Color bgColor = Color(0xFF0D0D0D);
    final Color primaryColor = Color(0xFFF4991A);
    final Color textColor = Colors.white;
    final Color subtleTextColor = Colors.white70;

    return Scaffold(
      backgroundColor: bgColor,
      // 1. NAVIGATION BAR
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        toolbarHeight: 80,
        title: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/icon.png',
                  height: 34,
                  width: 34,
                  fit: BoxFit.cover,
                ),
                SizedBox(width: 12),
                Text(
                  'Vyuha',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                // Links (optional)
                // TextButton(
                //   onPressed: () {}, // Scroll to features
                //   child: Text(
                //     'Features',
                //     style: TextStyle(color: subtleTextColor, fontSize: 16),
                //   ),
                // ),
                SizedBox(width: 24),
                // TextButton(
                //   onPressed: () {},
                //   child: Text(
                //     'Pricing',
                //     style: TextStyle(color: subtleTextColor, fontSize: 16),
                //   ),
                // ),
                SizedBox(width: 32),
                ElevatedButton(
                  onPressed: () => Get.toNamed('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32.0),
            child: Column(
              children: [
                // 2. HERO SECTION
                _buildHeroSection(primaryColor, textColor, subtleTextColor),

                SizedBox(height: 100),

                // 3. FEATURES SECTION
                _buildFeaturesSection(textColor, subtleTextColor, primaryColor),

                SizedBox(height: 100),

                // 4. FOOTER
                _buildFooter(subtleTextColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    Color primaryColor,
    Color textColor,
    Color subtleTextColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Text(
            'Visually Orchestrate Your Ideas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 60,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Welcome to Vyuha. The real-time, collaborative mind-mapping tool\n'
            'built to bring your team\'s thoughts to life.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subtleTextColor, fontSize: 20, height: 1.5),
          ),
          SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Get.toNamed('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                ),
                child: Text(
                  'Start Mapping for Free',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse(
                    'https://github.com/roshan2708/nitr-app-vyuha/releases/download/V01/app-release.apk',
                  );
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    print('Could not launch $url');
                  }
                },
                icon: Icon(Icons.android, color: primaryColor),
                label: Text(
                  'Download App',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(
    Color textColor,
    Color subtleTextColor,
    Color primaryColor,
  ) {
    return Column(
      children: [
        Text(
          'Everything you need. Nothing you don\'t.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Vyuha is designed to be powerful, not complicated.',
          textAlign: TextAlign.center,
          style: TextStyle(color: subtleTextColor, fontSize: 18),
        ),
        SizedBox(height: 60),
        Wrap(
          spacing: 32,
          runSpacing: 32,
          alignment: WrapAlignment.center,
          children: [
            _buildFeatureCard(
              icon: Icons.hub_outlined,
              title: 'Intuitive Mapping',
              description:
                  'Create, link, and organize nodes with a simple and fluid interface. Your ideas flow as fast as you think.',
              iconColor: primaryColor,
            ),
            _buildFeatureCard(
              icon: Icons.people_alt_outlined,
              title: 'Real-time Collaboration',
              description:
                  'Invite your team and map out ideas together. See changes from everyone instantly, on any device.',
              iconColor: Color(0xFF427A76), // Vyuha Teal
            ),
            _buildFeatureCard(
              icon: Icons.devices_outlined,
              title: 'Cross-Platform Sync',
              description:
                  'Work seamlessly across web, desktop, and mobile. Your Vyuha is always with you and always in sync.',
              iconColor: Color(0xFF3B9797), // Vyuha Blue
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
  }) {
    return Container(
      width: 350,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: iconColor),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color subtleTextColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Divider(color: Colors.white12),
          SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© ${DateTime.now().year} Vyuha. All rights reserved.',
                style: TextStyle(color: subtleTextColor, fontSize: 14),
              ),
              Text(
                'Built by Senatrius',
                style: TextStyle(color: subtleTextColor, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
