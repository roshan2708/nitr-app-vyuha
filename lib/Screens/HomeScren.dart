// FILE: HomeScreen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:vyuha/AppThemes.dart'; // <-- REMOVED
import 'package:vyuha/Screens/VyuhaScreen.dart';
import 'dart:math';

import 'package:vyuha/controllers/AuthController.dart';
// import 'package:vyuha/controllers/ThemeController.dart'; // <-- REMOVED

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthController auth = Get.find<AuthController>();
  // final ThemeController themeController = Get.find<ThemeController>(); // <-- REMOVED
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Color> _cardColors = [
    Color(0xFFF9B487),
    Color(0xFF427A76),
    Color(0xFF3B9797),
    Color(0xFFFF9013),
    Color(0xFF8D5F8C),
  ];

  // --- Hardcoded Dark Mode Colors & Styles ---
  final Color _accentOrange = Color(0xFFFF9013);
  final Color _accentBlue = Color(0xFF3B9797);
  final Color _dialogBg = Color(0xFF2a2a2a);
  final Color _scaffoldBg = Color(0xFF121212);
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _textMutedColor = Colors.white.withOpacity(0.7);
  final Color _hintColor = Colors.white54;
  final Color _dividerColor = Colors.white.withOpacity(0.12);
  final Color _errorColor = Colors.red.shade300;
  final Color _secondaryColor = Colors.white.withOpacity(0.3); // For borders

  // --- TEXTSTYLES MOVED FROM HERE ---

  String _generatePasskey() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  Future<void> _createRoom() async {
    final nameController = TextEditingController();
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    // +++ Local TextStyles for Dialogs +++
    // We define them here because the `build` context's styles aren't available.
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _bodyLarge = TextStyle(color: _textColor, fontSize: 16);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ End of Local TextStyles +++

    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg, // <-- CHANGED
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.psychology,
                color: _accentOrange, size: 24), // <-- CHANGED
            SizedBox(width: 12),
            Text('New Vyuha', style: _titleLarge), // <-- CHANGED
          ],
        ),
        content: TextField(
          controller: nameController,
          style: _bodyLarge, // <-- CHANGED
          decoration: InputDecoration(
            labelText: 'Vyuha Name',
            labelStyle: _labelMedium, // <-- CHANGED
            hintText: 'Enter a name for your Vyuha...',
            hintStyle: TextStyle(color: _hintColor), // <-- CHANGED
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _secondaryColor, // <-- CHANGED
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: _accentOrange, width: 2), // <-- CHANGED
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text(
              'Cancel',
              style: _labelMedium, // <-- CHANGED
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange, // <-- CHANGED
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final text = nameController.text.trim();
              Navigator.of(c).pop(text.isEmpty ? 'New Vyuha' : text);
            },
            child: Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (name == null) return;

    final id = _firestore.collection('rooms').doc().id;
    final passkey = _generatePasskey();
    print('Creating Vyuha with owner: ${auth.uid}, passkey: $passkey');

    await _firestore.collection('rooms').doc(id).set({
      'title': name,
      'owner': auth.uid,
      'passkey': passkey,
      'collaborators': [],
      'bannedUsers': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    Get.toNamed('/vyuha/$id');
  }

  Future<void> _joinVyuha() async {
    final passkeyController = TextEditingController();
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    // +++ Local TextStyles for Dialogs +++
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _bodyLarge = TextStyle(color: _textColor, fontSize: 16);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ End of Local TextStyles +++

    final passkey = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg, // <-- CHANGED
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.group_add, color: _accentBlue, size: 24), // <-- CHANGED
            SizedBox(width: 12),
            Text('Join Vyuha', style: _titleLarge), // <-- CHANGED
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-digit passkey to join a Vyuha:',
              style: TextStyle(
                color: _textMutedColor, // <-- CHANGED
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: passkeyController,
              style: _bodyLarge, // <-- CHANGED
              decoration: InputDecoration(
                labelText: 'Passkey',
                labelStyle: _labelMedium, // <-- CHANGED
                hintText: 'Enter 6-digit passkey',
                hintStyle: TextStyle(color: _hintColor), // <-- CHANGED
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _secondaryColor, // <-- CHANGED
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _accentBlue, // <-- CHANGED
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text(
              'Cancel',
              style: _labelMedium, // <-- CHANGED
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue, // <-- CHANGED
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final text = passkeyController.text.trim();
              Navigator.of(c).pop(text);
            },
            child: Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (passkey == null || passkey.isEmpty) return;

    if (passkey.length != 6) {
      _showCustomNotification(
        'Please enter a 6-digit passkey',
        isError: true,
      );
      return;
    }

    try {
      final snap = await _firestore
          .collection('rooms')
          .where('passkey', isEqualTo: passkey)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _showCustomNotification(
          'No Vyuha found with this passkey',
          isError: true,
        );
        return;
      }

      final roomDoc = snap.docs.first;
      final roomId = roomDoc.id;
      final owner = roomDoc.get('owner') ?? '';
      final collaborators = List<String>.from(
        roomDoc.get('collaborators') ?? [],
      );

      final bannedUsers = List<String>.from(
        roomDoc.get('bannedUsers') ?? [],
      );

      if (bannedUsers.contains(auth.uid)) {
        _showCustomNotification(
          'You are not allowed to join this Vyuha',
          isError: true,
        );
        return;
      }

      if (owner == auth.uid) {
        _showCustomNotification('You are the owner of this Vyuha');
        Get.toNamed('/vyuha/$roomId');
        return;
      }

      if (collaborators.contains(auth.uid)) {
        _showCustomNotification('You are already a collaborator');
        Get.toNamed('/vyuha/$roomId');
        return;
      }

      await _firestore.collection('rooms').doc(roomId).update({
        'collaborators': FieldValue.arrayUnion([auth.uid]),
      });

      _showCustomNotification('Joined Vyuha successfully!');

      Get.toNamed('/vyuha/$roomId');
    } catch (e) {
      String errorMessage = 'Failed to join Vyuha. Please try again.';
      String errorTitle = 'Error';

      if (e is FirebaseException) {
        if (e.code == 'not-found') {
          errorTitle = 'Not Found';
          errorMessage = 'No Vyuha found with this passkey.';
        } else if (e.code == 'failed-precondition') {
          errorTitle = 'Database Error';
          errorMessage =
              'The required database index is missing or building. Please check Firebase.';
        } else {
          errorMessage = e.message ?? 'An unknown Firebase error occurred.';
        }
      } else {
        errorMessage = e.toString();
      }

      print('Error joining Vyuha: $e');

      _showCustomNotification(errorMessage, isError: true);
    }
  }

  Future<void> _deleteRoom(String roomId, String title) async {
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    // +++ Local TextStyles for Dialogs +++
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ End of Local TextStyles +++

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg, // <-- CHANGED
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Vyuha',
          style: _titleLarge, // <-- CHANGED
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(
              color: _textMutedColor, // <-- CHANGED
              fontSize: 15,
            ),
            children: [
              TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: '"$title"',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _accentOrange, // <-- CHANGED
                ),
              ),
              TextSpan(
                text:
                    '?\n\nThis will permanently delete the Vyuha and all its nodes.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              'Cancel',
              style: _labelMedium, // <-- CHANGED
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor, // <-- CHANGED
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final nodesSnapshot = await _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('nodes')
            .get();

        final batch = _firestore.batch();
        for (var doc in nodesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        batch.delete(_firestore.collection('rooms').doc(roomId));
        await batch.commit();
      } catch (e) {
        print('Error deleting Vyuha: $e');
      }
    }
  }

  Future<void> _renameRoom(String roomId, String currentTitle) async {
    final nameController = TextEditingController(text: currentTitle);
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    // +++ Local TextStyles for Dialogs +++
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _bodyLarge = TextStyle(color: _textColor, fontSize: 16);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ End of Local TextStyles +++

    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg, // <-- CHANGED
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rename Vyuha',
          style: _titleLarge, // <-- CHANGED
        ),
        content: TextField(
          controller: nameController,
          style: _bodyLarge, // <-- CHANGED
          decoration: InputDecoration(
            labelText: 'New Name',
            labelStyle: _labelMedium, // <-- CHANGED
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _secondaryColor, // <-- CHANGED
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: _accentOrange, width: 2), // <-- CHANGED
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text(
              'Cancel',
              style: _labelMedium, // <-- CHANGED
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange, // <-- CHANGED
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final text = nameController.text.trim();
              Navigator.of(c).pop(text.isEmpty ? currentTitle : text);
            },
            child: Text('Rename', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName != currentTitle) {
      await _firestore.collection('rooms').doc(roomId).update({
        'title': newName,
      });
    }
  }

  Widget _buildRoomOptionsButton(
    String roomId,
    String title,
    bool isOwner, [
    Color? iconColor,
  ]) {
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'open') {
          Get.toNamed('/vyuha/$roomId');
        } else if (value == 'rename' && isOwner) {
          _renameRoom(roomId, title);
        } else if (value == 'delete' && isOwner) {
          _deleteRoom(roomId, title);
        } else if (value == 'leave' && !isOwner) {
          _leaveVyuha(roomId, title);
        }
      },
      icon: Icon(
        Icons.more_vert,
        color: iconColor ?? _textMutedColor, // <-- CHANGED
        size: 20,
      ),
      color: _dialogBg, // <-- CHANGED
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        _buildPopupMenuItem(
          label: 'Open Vyuha',
          icon: Icons.open_in_new,
          color: _accentOrange, // <-- CHANGED
          value: 'open',
        ),
        if (isOwner) ...[
          _buildPopupMenuItem(
            label: 'Rename',
            icon: Icons.edit_outlined,
            color: _accentBlue, // <-- CHANGED
            value: 'rename',
          ),
          _buildPopupMenuItem(
            label: 'Delete',
            icon: Icons.delete_outline,
            color: _errorColor, // <-- CHANGED
            value: 'delete',
          ),
        ] else ...[
          _buildPopupMenuItem(
            label: 'Leave Vyuha',
            icon: Icons.exit_to_app,
            color: Colors.orange.shade400,
            value: 'leave',
          ),
        ],
      ],
    );
  }

  Future<void> _leaveVyuha(String roomId, String title) async {
    // +++ Local TextStyles for Dialogs +++
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ End of Local TextStyles +++

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg, // <-- CHANGED
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Leave Vyuha',
          style: _titleLarge, // <-- CHANGED
        ),
        content: Text(
          'Are you sure you want to leave "$title"?\n\nYou can rejoin using the passkey.',
          style: TextStyle(
            color: _textMutedColor, // <-- CHANGED
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              'Cancel',
              style: _labelMedium, // <-- CHANGED
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('rooms').doc(roomId).update({
          'collaborators': FieldValue.arrayRemove([auth.uid]),
        });

        _showCustomNotification('You have left "$title"');
      } catch (e) {
        print('Error leaving Vyuha: $e');
      }
    }
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String label,
    required IconData icon,
    required Color color,
    required String value,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: _textColor, // <-- CHANGED
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(String currentName) async {
    final nameController = TextEditingController(text: currentName);
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    // +++ Local TextStyles for Dialogs +++
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _bodyLarge = TextStyle(color: _textColor, fontSize: 16);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ End of Local TextStyles +++

    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg, // <-- CHANGED
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Your Name',
          style: _titleLarge, // <-- CHANGED
        ),
        content: TextField(
          controller: nameController,
          style: _bodyLarge, // <-- CHANGED
          decoration: InputDecoration(
            labelText: 'New Name',
            labelStyle: _labelMedium, // <-- CHANGED
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _secondaryColor, // <-- CHANGED
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: _accentOrange, width: 2), // <-- CHANGED
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text(
              'Cancel',
              style: _labelMedium, // <-- CHANGED
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange, // <-- CHANGED
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final text = nameController.text.trim();
              Navigator.of(c).pop(text.isEmpty ? currentName : text);
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName != currentName) {
      await _firestore.collection('users').doc(auth.uid).update({
        'name': newName,
      });
    }
  }

  Future<void> _showProfileDialog(Map<String, dynamic> userData) async {
    final String name = userData['name'] ?? 'No Name';
    final String username = userData['username'] ?? 'No Username';
    final String email = userData['email'] ?? 'No Email';
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    // +++ Local TextStyles for Dialogs +++
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _bodyLarge = TextStyle(color: _textColor, fontSize: 16);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ End of Local TextStyles +++

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg, // <-- CHANGED
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person_pin_outlined,
                color: _accentOrange, size: 24), // <-- CHANGED
            SizedBox(width: 12),
            Text('Your Profile', style: _titleLarge), // <-- CHANGED
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- EMAIL (Read-only) ---
            ListTile(
              leading: Icon(Icons.email_outlined, color: _hintColor), // <-- CHANGED
              title: Text('Email', style: _labelMedium), // <-- CHANGED
              subtitle: Text(
                email,
                style: _bodyLarge, // <-- CHANGED
              ),
            ),
            // --- USERNAME (Read-only) ---
            ListTile(
              leading: Icon(Icons.alternate_email, color: _hintColor), // <-- CHANGED
              title: Text('Username', style: _labelMedium), // <-- CHANGED
              subtitle: Text(
                username,
                style: _bodyLarge, // <-- CHANGED
              ),
            ),
            // --- NAME (Editable) ---
            ListTile(
              leading: Icon(Icons.person_outline, color: _hintColor), // <-- CHANGED
              title: Text('Name', style: _labelMedium), // <-- CHANGED
              subtitle: Text(
                name,
                style: _bodyLarge, // <-- CHANGED
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 20, color: _accentOrange), // <-- CHANGED
                tooltip: 'Edit Name',
                onPressed: () {
                  Navigator.of(c).pop();
                  _showEditNameDialog(name);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: Text(
              'Close',
              style: _labelMedium, // <-- CHANGED
            ),
          ),
        ],
      ),
    );
  }

  // +++ NEW +++
  // This is the new function to handle the feedback form.
  Future<void> _showFeedbackDialog() async {
    final messageController = TextEditingController();
    // 0 = Bug Report, 1 = Testimonial
    List<bool> _isSelected = [true, false];
    // To show a loading spinner
    bool _isSubmitting = false;

    // +++ Local TextStyles for Dialogs +++
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _bodyLarge = TextStyle(color: _textColor, fontSize: 16);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ End of Local TextStyles +++

    await showDialog<void>(
      context: context,
      builder: (c) {
        // Use StatefulBuilder to manage the state of the toggle and loading
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _dialogBg, // <-- Style
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.feedback_outlined,
                      color: _accentOrange, size: 24), // <-- Style
                  SizedBox(width: 12),
                  Text('Send Feedback', style: _titleLarge), // <-- Style
                ],
              ),
              content: SingleChildScrollView(
                // In case keyboard appears
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Type:',
                      style: _labelMedium, // <-- Style
                    ),
                    SizedBox(height: 8),
                    ToggleButtons(
                      isSelected: _isSelected,
                      onPressed: (index) {
                        setState(() {
                          for (int i = 0; i < _isSelected.length; i++) {
                            _isSelected[i] = i == index;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Colors.white,
                      fillColor: _accentBlue, // <-- Style
                      color: _textMutedColor, // <-- Style
                      borderColor: _secondaryColor, // <-- Style
                      selectedBorderColor: _accentBlue, // <-- Style
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Icon(Icons.bug_report_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Bug Report'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Icon(Icons.star_outline, size: 16),
                              SizedBox(width: 8),
                              Text('Testimonial'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: messageController,
                      style: _bodyLarge, // <-- Style
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Your Message',
                        labelStyle: _labelMedium, // <-- Style
                        hintText: 'Please provide details...',
                        hintStyle: TextStyle(color: _hintColor), // <-- Style
                        alignLabelWithHint: true, // Good for multiline
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: _secondaryColor), // <-- Style
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: _accentOrange, width: 2), // <-- Style
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: Text(
                    'Cancel',
                    style: _labelMedium, // <-- Style
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentOrange, // <-- Style
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final message = messageController.text.trim();
                          if (message.isEmpty) {
                            Navigator.of(c).pop(); // Close dialog first
                            _showCustomNotification(
                              'Please enter a message before submitting.',
                              isError: true,
                            );
                            return;
                          }

                          // Set loading state
                          setState(() {
                            _isSubmitting = true;
                          });

                          final feedbackType =
                              _isSelected[0] ? 'Bug Report' : 'Testimonial';

                          try {
                            // Save to a new 'feedback' collection
                            await _firestore.collection('feedback').add({
                              'type': feedbackType,
                              'message': message,
                              'userId': auth.uid, // Track who sent it
                              'timestamp': FieldValue.serverTimestamp(),
                              'status': 'New', // For you to track in Firebase
                            });

                            Navigator.of(c).pop(); // Close dialog
                            _showCustomNotification(
                                'Thank you for your feedback!'); // Show success
                          } catch (e) {
                            print('Error submitting feedback: $e');
                            // Reset loading state and show error
                            Navigator.of(c).pop();
                            _showCustomNotification(
                              'Failed to send feedback. Please try again.',
                              isError: true,
                            );
                          }
                        },
                  // Show loading indicator or text
                  child: _isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text('Submit', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomNotification(String message, {bool isError = false}) {
    // final bool isDarkMode = Get.isDarkMode; // <-- REMOVED
    final Color bgColor = Color(0xFF1E1E1E); // <-- CHANGED
    final Color textColor =
        isError ? Colors.red.shade300 : Colors.white; // <-- CHANGED
    final Color borderColor =
        isError ? Colors.red.shade300 : Color(0xFF333333); // <-- CHANGED

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 720;
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    // +++ TEXTSTYLES MOVED HERE +++
    final TextStyle _titleLarge =
        TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
    final TextStyle _bodyLarge = TextStyle(color: _textColor, fontSize: 16);
    final TextStyle _labelMedium =
        TextStyle(color: _textMutedColor, fontSize: 12);
    final TextStyle _bodyMedium =
        TextStyle(color: _textMutedColor, fontSize: 14);
    final TextStyle _headlineSmall =
        TextStyle(color: _textColor, fontSize: 24, fontWeight: FontWeight.w400);
    final TextStyle _headlineMedium =
        TextStyle(color: _textColor, fontSize: 28, fontWeight: FontWeight.w600);
    final TextStyle _bodySmall = TextStyle(color: _textMutedColor, fontSize: 12);
    // +++ END OF TEXTSTYLE DEFINITIONS +++

    return Scaffold(
      backgroundColor: _scaffoldBg, // <-- CHANGED
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70.0),
        child: AppBar(
          toolbarHeight: 70.0, // <-- THIS IS THE FIX
          automaticallyImplyLeading: false,
          backgroundColor: _cardColor, // <-- CHANGED
          elevation: 0,
          shape: Border(
            bottom: BorderSide(
              color: _dividerColor, // <-- CHANGED
              width: 1.0,
            ),
          ),
          title: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    if (isWideScreen) ...[
                      ClipOval(
                        child: Image.asset(
                          'assets/images/icon.png',
                          height: 34,
                          width: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                    Text(
                      'Vyuha',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: _textColor), // <-- CHANGED
                    ),
                    SizedBox(width: 24),
                    Spacer(),

                    // --- THEME BUTTON (REMOVED) ---

                    // +++ NEW +++
                    // Feedback button added here
                    IconButton(
                      onPressed: _showFeedbackDialog,
                      icon: Icon(
                        Icons.feedback_outlined,
                        color: _textColor, // <-- Use hardcoded style
                        size: 22,
                      ),
                      tooltip: 'Send Feedback',
                    ),
                    SizedBox(width: 8),
                    // +++ END NEW +++

                    // --- (NEW) PROFILE ICON BUTTON ---
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection('users')
                          .doc(auth.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data?.data() == null) {
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                _secondaryColor.withOpacity(0.5), // <-- CHANGED
                            child: Icon(Icons.person_outline,
                                size: 18, color: Colors.white54),
                          );
                        }

                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final name = data['name'] as String? ?? 'U';
                        final String initial =
                            name.isNotEmpty ? name[0].toUpperCase() : 'U';

                        return IconButton(
                          onPressed: () => _showProfileDialog(data),
                          icon: CircleAvatar(
                            radius: 16,
                            backgroundColor: _accentOrange, // <-- CHANGED
                            child: Text(
                              initial,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                          ),
                          tooltip: 'View Profile',
                        );
                      },
                    ),

                    SizedBox(width: 8),

                    // --- LOGOUT BUTTON (Unchanged) ---
                    IconButton(
                      onPressed: () async {
                        await auth.signOut();
                        Get.offAllNamed('/login');
                      },
                      icon: Icon(
                        Icons.logout,
                        color: _textColor, // <-- CHANGED
                        size: 22,
                      ),
                      tooltip: 'Logout',
                    ),
                    SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1200),
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('rooms')
                .where('owner', isEqualTo: auth.uid)
                .snapshots(),
            builder: (context, ownedSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('rooms')
                    .where('collaborators', arrayContains: auth.uid)
                    .snapshots(),
                builder: (context, collaboratingSnap) {
                  if (!ownedSnap.hasData && !collaboratingSnap.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _accentOrange, // <-- CHANGED
                        ),
                      ),
                    );
                  }

                  final ownedDocs = ownedSnap.data?.docs ?? [];
                  final collaboratingDocs = collaboratingSnap.data?.docs ?? [];
                  final allDocs = [...ownedDocs, ...collaboratingDocs];

                  allDocs.sort((a, b) {
                    final aTime = a['createdAt'] as Timestamp?;
                    final bTime = b['createdAt'] as Timestamp?;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  final bool isEmpty = allDocs.isEmpty;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWideScreen)
                        _buildWebHeader(
                          // customTheme, // <-- REMOVED
                          ownedDocs,
                          collaboratingDocs,
                          _headlineMedium, // Pass styles
                          _bodyLarge, // Pass styles
                          _headlineSmall, // Pass styles
                          _bodySmall, // Pass styles
                        ),
                      if (isWideScreen && !isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Text(
                            'All Your Vyuha',
                            style: _headlineSmall.copyWith(
                                fontWeight: FontWeight.w400), // <-- CHANGED
                          ),
                        ),
                      Expanded(
                        child: isEmpty
                            ? _buildEmptyState(_bodyMedium, _labelMedium)
                            : _buildGridView(
                                allDocs,
                                isWideScreen,
                                _titleLarge, // Pass styles
                                _bodySmall, // Pass styles
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: isWideScreen
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'join',
                  onPressed: _joinVyuha,
                  backgroundColor: _accentBlue, // <-- CHANGED
                  elevation: 2,
                  icon: Icon(Icons.lock_outlined, color: Colors.white),
                  label: Text(
                    'Join Vyuha',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'create',
                  onPressed: _createRoom,
                  backgroundColor: _accentOrange, // <-- CHANGED
                  elevation: 2,
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text(
                    'New Vyuha',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWebHeader(
    // CustomTheme customTheme, // <-- REMOVED
    List<QueryDocumentSnapshot> ownedDocs,
    List<QueryDocumentSnapshot> collaboratingDocs,
    // +++ Pass styles from build method +++
    TextStyle _headlineMedium,
    TextStyle _bodyLarge,
    TextStyle _headlineSmall,
    TextStyle _bodySmall,
  ) {
    final int totalCount = ownedDocs.length + collaboratingDocs.length;
    final int collabCount = collaboratingDocs.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Dashboard',
                style: _headlineMedium, // <-- CHANGED
              ),
              Spacer(),
              ElevatedButton.icon(
                onPressed: _joinVyuha,
                icon: Icon(Icons.group_add_outlined, size: 18),
                label: Text('Join Vyuha'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cardColor, // <-- CHANGED
                  foregroundColor: _textColor, // <-- CHANGED
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: _dividerColor), // <-- CHANGED
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _createRoom,
                icon: Icon(Icons.add, size: 18),
                label: Text('New Vyuha'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange, // <-- CHANGED
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              _buildStatCard(
                'Total Vyuha',
                totalCount.toString(),
                Icons.account_tree_outlined,
                _accentOrange, // <-- CHANGED
                _headlineSmall, // Pass style
                _bodySmall, // Pass style
              ),
              SizedBox(width: 16),
              _buildStatCard(
                'Collaborations',
                collabCount.toString(),
                Icons.people_alt_outlined,
                _accentBlue, // <-- CHANGED
                _headlineSmall, // Pass style
                _bodySmall, // Pass style
              ),
              Spacer(),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 400),
                  child: TextField(
                    style: _bodyLarge, // <-- CHANGED
                    decoration: InputDecoration(
                      hintText: 'Search your Vyuha...',
                      hintStyle: TextStyle(color: _hintColor), // <-- CHANGED
                      prefixIcon: Icon(
                        Icons.search,
                        color: _hintColor, // <-- CHANGED
                        size: 20,
                      ),
                      filled: true,
                      fillColor: _cardColor, // <-- CHANGED
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _dividerColor, // <-- CHANGED
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _dividerColor, // <-- CHANGED
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _accentBlue, // <-- CHANGED
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    // +++ Pass styles from build method +++
    TextStyle _headlineSmall,
    TextStyle _bodySmall,
  ) {
    return Container(
      width: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor, // <-- CHANGED
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dividerColor), // <-- CHANGED
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: _headlineSmall.copyWith(
                    fontWeight: FontWeight.w600), // <-- CHANGED
              ),
              Text(title, style: _bodySmall), // <-- CHANGED
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(
    List<QueryDocumentSnapshot> allDocs,
    bool isWideScreen,
    // +++ Pass styles from build method +++
    TextStyle _titleLarge,
    TextStyle _bodySmall,
  ) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isWideScreen ? 380 : 250,
        childAspectRatio: isWideScreen ? 1.8 / 1 : 1 / 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: allDocs.length,
      itemBuilder: (context, i) {
        final d = allDocs[i];
        final title = d['title'] ?? 'Untitled';
        final createdAt = d['createdAt'] as Timestamp?;
        final owner = d['owner'] ?? '';
        final isOwner = owner == auth.uid;
        final accentColor = _cardColors[i % _cardColors.length];
        return _buildRoomCard(
          d.id,
          title,
          createdAt,
          accentColor,
          isOwner,
          _titleLarge, // Pass style
          _bodySmall, // Pass style
        );
      },
    );
  }

  Widget _buildRoomCard(
    String docId,
    String title,
    Timestamp? createdAt,
    Color accentColor,
    bool isOwner,
    // +++ Pass styles from build method +++
    TextStyle _titleLarge,
    TextStyle _bodySmall,
  ) {
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    return InkWell(
      onTap: () => Get.toNamed('/vyuha/$docId'),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _dividerColor.withOpacity(0.5), // <-- CHANGED
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor, // <-- CHANGED
            border: Border(left: BorderSide(color: accentColor, width: 6)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isOwner) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accentBlue.withOpacity(0.1), // <-- CHANGED
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    _accentBlue.withOpacity(0.5), // <-- CHANGED
                              ),
                            ),
                            child: Text(
                              'COLLABORATOR',
                              style: TextStyle(
                                color: _accentBlue, // <-- CHANGED
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                        ],
                        Text(
                          title,
                          style: _titleLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ), // <-- CHANGED
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Text(
                      createdAt != null
                          ? _formatDate(createdAt.toDate())
                          : 'Just now',
                      style: _bodySmall, // <-- CHANGED
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _buildRoomOptionsButton(
                  docId,
                  title,
                  isOwner,
                  _textMutedColor, // <-- CHANGED
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    // +++ Pass styles from build method +++
    TextStyle _bodyMedium,
    TextStyle _labelMedium,
  ) {
    // final customTheme = Theme.of(context).extension<CustomTheme>()!; // <-- REMOVED

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          SizedBox(height: 24),
          Text(
            'अद्यापि व्यूहो नास्ति',
            style: TextStyle(
              fontSize: 24,
              color: _textMutedColor, // <-- CHANGED
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Create your first Vyuha or join one',
            style: TextStyle(
              fontSize: 14,
              color: _hintColor, // <-- CHANGED
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: 32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: _joinVyuha,
                icon: Icon(Icons.group_add, size: 20),
                label: Text('Join Vyuha'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue, // <-- CHANGED
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _createRoom,
                icon: Icon(Icons.add, size: 20),
                label: Text('Create Vyuha'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange, // <-- CHANGED
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}