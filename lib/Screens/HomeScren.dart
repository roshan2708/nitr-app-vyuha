// FILE: lib/screens/HomeScreen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

import 'package:vyuha/controllers/AuthController.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthController auth = Get.find<AuthController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Hardcoded Dark Mode Colors & Styles ---
  final Color _accentOrange = Color(0xFFFF9013);
  final Color _accentBlue = Color(0xFF3B9797);
  final Color _accentKram = Color(0xFF8D5F8C);
  final Color _dialogBg = Color(0xFF2a2a2a);
  final Color _scaffoldBg = Color(0xFF121212);
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _textMutedColor = Colors.white.withOpacity(0.7);
  final Color _hintColor = Colors.white54;
  final Color _dividerColor = Colors.white.withOpacity(0.12);
  final Color _errorColor = Colors.red.shade300;
  final Color _secondaryColor = Colors.white.withOpacity(0.3);

  // --- TEXTSTYLES ---
  TextStyle get _titleLarge =>
      TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.w500);
  TextStyle get _bodyLarge => TextStyle(color: _textColor, fontSize: 16);
  TextStyle get _labelMedium => TextStyle(color: _textMutedColor, fontSize: 12);
  TextStyle get _bodyMedium => TextStyle(color: _textMutedColor, fontSize: 14);
  TextStyle get _headlineSmall =>
      TextStyle(color: _textColor, fontSize: 24, fontWeight: FontWeight.w400);
  TextStyle get _headlineMedium =>
      TextStyle(color: _textColor, fontSize: 28, fontWeight: FontWeight.w600);
  TextStyle get _bodySmall => TextStyle(color: _textMutedColor, fontSize: 12);

  // --- HELPER METHODS ---

  String _generatePasskey() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  // --- (MODIFIED) MAIN FAB DIALOG ---
  // Removed Kram creation options here. Only Vyuha and Join remain.
  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuOption(
                icon: Icons.psychology_outlined,
                label: 'Create New Vyuha',
                color: _accentOrange,
                onTap: () {
                  Navigator.pop(context);
                  _createRoomDialog('vyuha');
                },
              ),
              Divider(color: _dividerColor, height: 24),
              _buildMenuOption(
                icon: Icons.account_tree_outlined,
                label: 'Create New Kram',
                color: _accentKram,
                onTap: () {
                  Navigator.pop(context);
                  _createKramDialog();
                },
              ),
              Divider(color: _dividerColor, height: 24),
              _buildMenuOption(
                icon: Icons.group_add_outlined,
                label: 'Join Vyuha or Kram',
                color: _accentBlue,
                onTap: () {
                  Navigator.pop(context);
                  _joinVyuhaDialog();
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // --- Kram Flowchart Types ---
  static const List<Map<String, dynamic>> _kramTypes = [
    {
      'label': 'Technical',
      'icon': Icons.code,
      'value': 'technical',
      'desc': 'Architecture, system design, API flows',
    },
    {
      'label': 'Marketing',
      'icon': Icons.campaign_outlined,
      'value': 'marketing',
      'desc': 'Funnels, campaigns, user journeys',
    },
    {
      'label': 'Business',
      'icon': Icons.business_center_outlined,
      'value': 'business',
      'desc': 'Operations, workflows, processes',
    },
    {
      'label': 'Product',
      'icon': Icons.widgets_outlined,
      'value': 'product',
      'desc': 'User flows, feature maps, sprints',
    },
    {
      'label': 'Education',
      'icon': Icons.school_outlined,
      'value': 'education',
      'desc': 'Learning paths, concept maps',
    },
    {
      'label': 'Custom',
      'icon': Icons.tune,
      'value': 'custom',
      'desc': 'General purpose flowchart',
    },
  ];

  // --- Create Kram Dialog (Multi-Step) ---
  Future<void> _createKramDialog() async {
    final nameController = TextEditingController();
    final ideaController = TextEditingController();
    String selectedType = 'technical';
    String source = 'idea'; // 'idea' or 'vyuha'
    String? selectedVyuhaId;
    String? selectedVyuhaTitle;
    int step =
        0; // 0=name, 1=source, 2=type selection, 3=idea input / vyuha select

    await showModalBottomSheet(
      context: context,
      backgroundColor: _dialogBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedContainer(
              duration: Duration(milliseconds: 200),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header ---
                  Row(
                    children: [
                      Icon(Icons.account_tree, color: _accentKram, size: 24),
                      SizedBox(width: 12),
                      Text(
                        step == 0
                            ? 'Name Your Kram'
                            : step == 1
                            ? 'Choose Source'
                            : step == 2
                            ? 'Flowchart Type'
                            : source == 'idea'
                            ? 'Describe Your Idea'
                            : 'Select a Vyuha',
                        style: _titleLarge,
                      ),
                      Spacer(),
                      // Step indicator
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _accentKram.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${step + 1}/4',
                          style: TextStyle(
                            color: _accentKram,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // --- Step 0: Name ---
                  if (step == 0) ...[
                    TextField(
                      controller: nameController,
                      style: _bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Kram Name',
                        labelStyle: _labelMedium,
                        hintText: 'e.g., User Signup Flow',
                        hintStyle: TextStyle(color: _hintColor),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _secondaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _accentKram, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      autofocus: true,
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentKram,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setModalState(() {
                            step = 1;
                          });
                        },
                        child: Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // --- Step 1: Source ---
                  if (step == 1) ...[
                    _buildKramSourceOption(
                      icon: Icons.lightbulb_outline,
                      label: 'From an Idea',
                      desc: 'Type your idea and AI will generate a flowchart',
                      isSelected: source == 'idea',
                      onTap: () => setModalState(() {
                        source = 'idea';
                      }),
                    ),
                    SizedBox(height: 12),
                    _buildKramSourceOption(
                      icon: Icons.psychology_outlined,
                      label: 'From a Vyuha',
                      desc: 'Use an existing Vyuha mind-map as context',
                      isSelected: source == 'vyuha',
                      onTap: () => setModalState(() {
                        source = 'vyuha';
                      }),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setModalState(() {
                            step = 0;
                          }),
                          child: Text('Back', style: _labelMedium),
                        ),
                        Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentKram,
                            padding: EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => setModalState(() {
                            step = 2;
                          }),
                          child: Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // --- Step 2: Flowchart Type ---
                  if (step == 2) ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _kramTypes.map((t) {
                        final bool isSelected = selectedType == t['value'];
                        return GestureDetector(
                          onTap: () => setModalState(() {
                            selectedType = t['value'];
                          }),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 150),
                            width: MediaQuery.of(context).size.width / 2 - 40,
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _accentKram.withOpacity(0.15)
                                  : _cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? _accentKram : _dividerColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  t['icon'] as IconData,
                                  color: isSelected
                                      ? _accentKram
                                      : _textMutedColor,
                                  size: 22,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  t['label'],
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  t['desc'],
                                  style: TextStyle(
                                    color: _hintColor,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setModalState(() {
                            step = 1;
                          }),
                          child: Text('Back', style: _labelMedium),
                        ),
                        Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentKram,
                            padding: EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => setModalState(() {
                            step = 3;
                          }),
                          child: Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // --- Step 3: Idea input OR Vyuha selection ---
                  if (step == 3) ...[
                    if (source == 'idea') ...[
                      TextField(
                        controller: ideaController,
                        style: _bodyLarge,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Your Idea',
                          labelStyle: _labelMedium,
                          hintText:
                              'Describe what the flowchart should cover...',
                          hintStyle: TextStyle(color: _hintColor),
                          alignLabelWithHint: true,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _secondaryColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _accentKram,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        autofocus: true,
                      ),
                    ] else ...[
                      // Vyuha list
                      Container(
                        height: 250,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('rooms')
                              .where('type', isEqualTo: 'vyuha')
                              .where('owner', isEqualTo: auth.uid)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData)
                              return Center(
                                child: CircularProgressIndicator(
                                  color: _accentKram,
                                ),
                              );
                            final docs = snap.data!.docs;
                            if (docs.isEmpty) {
                              return Center(
                                child: Text(
                                  'No Vyuha rooms found. Create one first!',
                                  style: _bodyMedium,
                                ),
                              );
                            }
                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final d = docs[i];
                                final title = d['title'] ?? 'Untitled';
                                final bool isSelected = selectedVyuhaId == d.id;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedVyuhaId = d.id;
                                      selectedVyuhaTitle = title;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 150),
                                    padding: EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _accentKram.withOpacity(0.15)
                                          : _cardColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? _accentKram
                                            : _dividerColor,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.psychology_outlined,
                                          color: isSelected
                                              ? _accentKram
                                              : _accentOrange,
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: _bodyLarge.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: _accentKram,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setModalState(() {
                            step = 2;
                          }),
                          child: Text('Back', style: _labelMedium),
                        ),
                        Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentKram,
                            padding: EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            'Generate Kram',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () async {
                            final kramName = nameController.text.trim().isEmpty
                                ? 'New Kram'
                                : nameController.text.trim();

                            String generationTopic = kramName;
                            String generationContext = '';

                            if (source == 'idea') {
                              generationContext = ideaController.text.trim();
                              if (generationContext.isEmpty) {
                                generationContext = kramName;
                              }
                            } else if (source == 'vyuha' &&
                                selectedVyuhaId != null) {
                              // Fetch vyuha nodes to use as context
                              try {
                                final nodesSnap = await _firestore
                                    .collection('rooms')
                                    .doc(selectedVyuhaId)
                                    .collection('nodes')
                                    .get();
                                final nodeTexts = nodesSnap.docs
                                    .map((d) => d['text']?.toString() ?? '')
                                    .where((t) => t.isNotEmpty)
                                    .toList();
                                generationContext =
                                    'Based on Vyuha "${selectedVyuhaTitle ?? ''}": ${nodeTexts.join(", ")}';
                                generationTopic =
                                    selectedVyuhaTitle ?? kramName;
                              } catch (e) {
                                generationContext =
                                    'Based on Vyuha: ${selectedVyuhaTitle ?? kramName}';
                              }
                            }

                            Navigator.pop(ctx);
                            _createKramRoom(
                              name: kramName,
                              topic: generationTopic,
                              context: generationContext,
                              flowchartType: selectedType,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKramSourceOption({
    required IconData icon,
    required String label,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _accentKram.withOpacity(0.12) : _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _accentKram : _dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? _accentKram : _textMutedColor,
              size: 28,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: _hintColor, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: _accentKram, size: 20),
          ],
        ),
      ),
    );
  }

  // --- Create Kram Room (sets generation fields for KramController to pick up) ---
  Future<void> _createKramRoom({
    required String name,
    required String topic,
    required String context,
    required String flowchartType,
  }) async {
    try {
      final newRoomRef = await _firestore.collection('rooms').add({
        'title': name,
        'owner': auth.uid,
        'passkey': _generatePasskey(),
        'collaborators': [],
        'bannedUsers': [],
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'kram',
        'generationTopic': topic,
        'generationContext': context,
        'flowchartType': flowchartType,
      });

      Get.toNamed('/kram/${newRoomRef.id}');
    } catch (e) {
      print('Error creating Kram: $e');
      _showCustomNotification('Failed to create Kram. $e', isError: true);
    }
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        label,
        style: _bodyLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }

  // --- Create Room Dialog ---
  Future<void> _createRoomDialog(String type, {String? initialTopic}) async {
    final nameController = TextEditingController(text: initialTopic ?? '');

    // We strictly use this for Vyuha now in the Home Screen
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.psychology, color: _accentOrange, size: 24),
            SizedBox(width: 12),
            Text('New Vyuha', style: _titleLarge),
          ],
        ),
        content: TextField(
          controller: nameController,
          style: _bodyLarge,
          decoration: InputDecoration(
            labelText: 'Vyuha Name',
            labelStyle: _labelMedium,
            hintText: 'Enter a name...',
            hintStyle: TextStyle(color: _hintColor),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _secondaryColor),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _accentOrange, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text('Cancel', style: _labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange,
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

    _createRoom(name: name, type: type);
  }

  // --- Generic Create Room Function ---
  Future<void> _createRoom({required String name, required String type}) async {
    try {
      final newRoomRef = await _firestore.collection('rooms').add({
        'title': name,
        'owner': auth.uid,
        'passkey': _generatePasskey(),
        'collaborators': [],
        'bannedUsers': [],
        'createdAt': FieldValue.serverTimestamp(),
        'type': type, // 'vyuha' or 'kram'
      });

      final id = newRoomRef.id;

      if (type == 'kram') {
        Get.toNamed('/kram/$id');
      } else {
        Get.toNamed('/vyuha/$id');
      }
    } catch (e) {
      print('Error creating Vyuha: $e');
      _showCustomNotification('Failed to create. $e', isError: true);
    }
  }

  // --- Join Vyuha Dialog ---
  Future<void> _joinVyuhaDialog() async {
    final passkeyController = TextEditingController();

    final passkey = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.group_add, color: _accentBlue, size: 24),
            SizedBox(width: 12),
            Text('Join Room', style: _titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-digit passkey to join a Vyuha or Kram:',
              style: _bodyMedium,
            ),
            SizedBox(height: 16),
            TextField(
              controller: passkeyController,
              style: _bodyLarge,
              decoration: InputDecoration(
                labelText: 'Passkey',
                labelStyle: _labelMedium,
                hintText: 'Enter 6-digit passkey',
                hintStyle: TextStyle(color: _hintColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _secondaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _accentBlue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text('Cancel', style: _labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
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
      _showCustomNotification('Please enter a 6-digit passkey', isError: true);
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
          'No room found with this passkey',
          isError: true,
        );
        return;
      }

      final roomDoc = snap.docs.first;
      final roomId = roomDoc.id;
      final roomData = roomDoc.data() as Map<String, dynamic>;
      final roomType = roomData['type'] as String? ?? 'vyuha';
      final owner = roomData['owner'] ?? '';
      final collaborators = List<String>.from(roomData['collaborators'] ?? []);
      final bannedUsers = List<String>.from(roomData['bannedUsers'] ?? []);

      if (bannedUsers.contains(auth.uid)) {
        _showCustomNotification(
          'You are not allowed to join this room',
          isError: true,
        );
        return;
      }

      if (owner == auth.uid) {
        _showCustomNotification('You are the owner of this room');
        Get.toNamed(roomType == 'kram' ? '/kram/$roomId' : '/vyuha/$roomId');
        return;
      }

      if (collaborators.contains(auth.uid)) {
        _showCustomNotification('You are already a collaborator');
        Get.toNamed(roomType == 'kram' ? '/kram/$roomId' : '/vyuha/$roomId');
        return;
      }

      await _firestore.collection('rooms').doc(roomId).update({
        'collaborators': FieldValue.arrayUnion([auth.uid]),
      });

      _showCustomNotification('Joined room successfully!');
      Get.toNamed(roomType == 'kram' ? '/kram/$roomId' : '/vyuha/$roomId');
    } catch (e) {
      print('Error joining room: $e');
      _showCustomNotification('Failed to join room', isError: true);
    }
  }

  // --- Delete Room ---
  Future<void> _deleteRoom(String roomId, String title, String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete ${type == 'kram' ? 'Kram' : 'Vyuha'}',
          style: _titleLarge,
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: _textMutedColor, fontSize: 15),
            children: [
              TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: '"$title"',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _accentOrange,
                ),
              ),
              TextSpan(text: '?\n\nThis will be permanently deleted.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('Cancel', style: _labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
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
        final roomRef = _firestore.collection('rooms').doc(roomId);
        final batch = _firestore.batch();

        if (type == 'vyuha' || type.isEmpty) {
          final nodesSnap = await roomRef.collection('nodes').get();
          for (var doc in nodesSnap.docs) {
            batch.delete(doc.reference);
          }
        } else {
          final elementsSnap = await roomRef.collection('elements').get();
          for (var doc in elementsSnap.docs) {
            batch.delete(doc.reference);
          }
          final edgesSnap = await roomRef.collection('edges').get();
          for (var doc in edgesSnap.docs) {
            batch.delete(doc.reference);
          }
        }

        batch.delete(roomRef);
        await batch.commit();
        _showCustomNotification('"$title" was deleted.');
      } catch (e) {
        print('Error deleting room: $e');
        _showCustomNotification('Failed to delete. $e', isError: true);
      }
    }
  }

  // --- Rename Room ---
  Future<void> _renameRoom(String roomId, String currentTitle) async {
    final nameController = TextEditingController(text: currentTitle);

    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename', style: _titleLarge),
        content: TextField(
          controller: nameController,
          style: _bodyLarge,
          decoration: InputDecoration(
            labelText: 'New Name',
            labelStyle: _labelMedium,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _secondaryColor),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _accentOrange, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text('Cancel', style: _labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange,
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

  // --- Room Options Button ---
  Widget _buildRoomOptionsButton(
    String roomId,
    String title,
    String type,
    bool isOwner, [
    Color? iconColor,
  ]) {
    final safeType = type.isEmpty ? 'vyuha' : type;

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'open') {
          Get.toNamed(safeType == 'kram' ? '/kram/$roomId' : '/vyuha/$roomId');
        } else if (value == 'rename' && isOwner) {
          _renameRoom(roomId, title);
        } else if (value == 'delete' && isOwner) {
          _deleteRoom(roomId, title, safeType);
        } else if (value == 'leave' && !isOwner) {
          _leaveVyuha(roomId, title);
        }
      },
      icon: Icon(
        Icons.more_vert,
        color: iconColor ?? _textMutedColor,
        size: 20,
      ),
      color: _dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        _buildPopupMenuItem(
          label: 'Open',
          icon: Icons.open_in_new,
          color: _accentOrange,
          value: 'open',
        ),
        if (isOwner) ...[
          _buildPopupMenuItem(
            label: 'Rename',
            icon: Icons.edit_outlined,
            color: _accentBlue,
            value: 'rename',
          ),
          _buildPopupMenuItem(
            label: 'Delete',
            icon: Icons.delete_outline,
            color: _errorColor,
            value: 'delete',
          ),
        ] else ...[
          _buildPopupMenuItem(
            label: 'Leave',
            icon: Icons.exit_to_app,
            color: Colors.orange.shade400,
            value: 'leave',
          ),
        ],
      ],
    );
  }

  // --- Leave Vyuha ---
  Future<void> _leaveVyuha(String roomId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leave Room', style: _titleLarge),
        content: Text(
          'Are you sure you want to leave "$title"?\n\nYou can rejoin using the passkey.',
          style: _bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('Cancel', style: _labelMedium),
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
        print('Error leaving room: $e');
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
          Text(label, style: TextStyle(color: _textColor)),
        ],
      ),
    );
  }

  // --- Profile / Feedback / Logout ---

  Future<void> _showEditNameDialog(String currentName) async {
    final nameController = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Your Name', style: _titleLarge),
        content: TextField(
          controller: nameController,
          style: _bodyLarge,
          decoration: InputDecoration(
            labelText: 'New Name',
            labelStyle: _labelMedium,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _secondaryColor),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _accentOrange, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text('Cancel', style: _labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange,
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

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person_pin_outlined, color: _accentOrange, size: 24),
            SizedBox(width: 12),
            Text('Your Profile', style: _titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email_outlined, color: _hintColor),
              title: Text('Email', style: _labelMedium),
              subtitle: Text(email, style: _bodyLarge),
            ),
            ListTile(
              leading: Icon(Icons.alternate_email, color: _hintColor),
              title: Text('Username', style: _labelMedium),
              subtitle: Text(username, style: _bodyLarge),
            ),
            ListTile(
              leading: Icon(Icons.person_outline, color: _hintColor),
              title: Text('Name', style: _labelMedium),
              subtitle: Text(name, style: _bodyLarge),
              trailing: IconButton(
                icon: Icon(Icons.edit_outlined, size: 20, color: _accentOrange),
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
            child: Text('Close', style: _labelMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _showFeedbackDialog() async {
    final messageController = TextEditingController();
    List<bool> _isSelected = [true, false];
    bool _isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.feedback_outlined, color: _accentOrange, size: 24),
                  SizedBox(width: 12),
                  Text('Send Feedback', style: _titleLarge),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Type:', style: _labelMedium),
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
                      fillColor: _accentBlue,
                      color: _textMutedColor,
                      borderColor: _secondaryColor,
                      selectedBorderColor: _accentBlue,
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
                      style: _bodyLarge,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Your Message',
                        labelStyle: _labelMedium,
                        hintText: 'Please provide details...',
                        hintStyle: TextStyle(color: _hintColor),
                        alignLabelWithHint: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _secondaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _accentOrange,
                            width: 2,
                          ),
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
                  child: Text('Cancel', style: _labelMedium),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final message = messageController.text.trim();
                          if (message.isEmpty) {
                            Navigator.of(c).pop();
                            _showCustomNotification(
                              'Please enter a message.',
                              isError: true,
                            );
                            return;
                          }
                          setState(() {
                            _isSubmitting = true;
                          });
                          final feedbackType = _isSelected[0]
                              ? 'Bug Report'
                              : 'Testimonial';
                          try {
                            await _firestore.collection('feedback').add({
                              'type': feedbackType,
                              'message': message,
                              'userId': auth.uid,
                              'timestamp': FieldValue.serverTimestamp(),
                              'status': 'New',
                            });
                            Navigator.of(c).pop();
                            _showCustomNotification(
                              'Thank you for your feedback!',
                            );
                          } catch (e) {
                            print('Error submitting feedback: $e');
                            Navigator.of(c).pop();
                            _showCustomNotification(
                              'Failed to send feedback.',
                              isError: true,
                            );
                          }
                        },
                  child: _isSubmitting
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
    final Color bgColor = Color(0xFF1E1E1E);
    final Color textColor = isError ? Colors.red.shade300 : Colors.white;
    final Color borderColor = isError ? Colors.red.shade300 : Color(0xFF333333);

    Get.rawSnackbar(
      messageText: Text(
        message,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
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

  // --- MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 720;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70.0),
        child: AppBar(
          toolbarHeight: 70.0,
          automaticallyImplyLeading: false,
          backgroundColor: _cardColor,
          elevation: 0,
          shape: Border(bottom: BorderSide(color: _dividerColor, width: 1.0)),
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
                        color: _textColor,
                      ),
                    ),
                    SizedBox(width: 24),
                    Spacer(),
                    IconButton(
                      onPressed: _showFeedbackDialog,
                      icon: Icon(
                        Icons.feedback_outlined,
                        color: _textColor,
                        size: 22,
                      ),
                      tooltip: 'Send Feedback',
                    ),
                    SizedBox(width: 8),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection('users')
                          .doc(auth.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData ||
                            snapshot.data?.data() == null) {
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: _secondaryColor.withOpacity(0.5),
                            child: Icon(
                              Icons.person_outline,
                              size: 18,
                              color: Colors.white54,
                            ),
                          );
                        }
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final name = data['name'] as String? ?? 'U';
                        final String initial = name.isNotEmpty
                            ? name[0].toUpperCase()
                            : 'U';
                        return IconButton(
                          onPressed: () => _showProfileDialog(data),
                          icon: CircleAvatar(
                            radius: 16,
                            backgroundColor: _accentOrange,
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          tooltip: 'View Profile',
                        );
                      },
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        await auth.signOut();
                        Get.offAllNamed('/login');
                      },
                      icon: Icon(Icons.logout, color: _textColor, size: 22),
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
                .where('collaborators', arrayContains: auth.uid)
                .snapshots(),
            builder: (context, collaboratingSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('rooms')
                    .where('owner', isEqualTo: auth.uid)
                    .snapshots(),
                builder: (context, ownedSnap) {
                  if (!ownedSnap.hasData && !collaboratingSnap.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _accentOrange,
                        ),
                      ),
                    );
                  }

                  final ownedDocs = ownedSnap.data?.docs ?? [];
                  final collaboratingDocs = collaboratingSnap.data?.docs ?? [];

                  final allDocsMap = <String, QueryDocumentSnapshot>{};
                  for (var doc in ownedDocs) {
                    allDocsMap[doc.id] = doc;
                  }
                  for (var doc in collaboratingDocs) {
                    allDocsMap[doc.id] = doc;
                  }
                  final allDocs = allDocsMap.values.toList();

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
                        _buildWebHeader(ownedDocs, collaboratingDocs),
                      if (isWideScreen && !isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Text(
                            'All Your Rooms',
                            style: _headlineSmall.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      Expanded(
                        child: isEmpty
                            ? _buildEmptyState()
                            : _buildGridView(allDocs, isWideScreen),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_fab',
        onPressed: _showCreateMenu,
        backgroundColor: _accentOrange,
        child: Icon(Icons.add, color: Colors.white, size: 28),
        tooltip: 'Create or Join',
      ),
    );
  }

  // --- Web Header ---
  Widget _buildWebHeader(
    List<QueryDocumentSnapshot> ownedDocs,
    List<QueryDocumentSnapshot> collaboratingDocs,
  ) {
    final collabIds = collaboratingDocs.map((d) => d.id).toSet();
    final ownedIds = ownedDocs.map((d) => d.id).toSet();
    final totalCount = collabIds.union(ownedIds).length;
    final collabCount = collaboratingDocs
        .where((d) => !ownedIds.contains(d.id))
        .length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Dashboard', style: _headlineMedium),
              Spacer(),
              ElevatedButton.icon(
                onPressed: _joinVyuhaDialog,
                icon: Icon(Icons.group_add_outlined, size: 18),
                label: Text('Join Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cardColor,
                  foregroundColor: _textColor,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: _dividerColor),
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _createRoomDialog('vyuha'),
                icon: Icon(Icons.add, size: 18),
                label: Text('Create Vyuha'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _createKramDialog,
                icon: Icon(Icons.account_tree_outlined, size: 18),
                label: Text('Create Kram'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentKram,
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
                'Total Rooms',
                totalCount.toString(),
                Icons.layers_outlined,
                _accentOrange,
              ),
              SizedBox(width: 16),
              _buildStatCard(
                'Collaborations',
                collabCount.toString(),
                Icons.people_alt_outlined,
                _accentBlue,
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
  ) {
    return Container(
      width: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dividerColor),
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
                style: _headlineSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(title, style: _bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  // --- Grid View ---
  Widget _buildGridView(
    List<QueryDocumentSnapshot> allDocs,
    bool isWideScreen,
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

        final roomData = d.data() as Map<String, dynamic>;
        final type = roomData['type'] as String? ?? 'vyuha';

        final Color accentColor = type == 'kram' ? _accentKram : _accentOrange;

        return _buildRoomCard(
          d.id,
          title,
          createdAt,
          accentColor,
          isOwner,
          type,
        );
      },
    );
  }

  // --- Room Card ---
  Widget _buildRoomCard(
    String docId,
    String title,
    Timestamp? createdAt,
    Color accentColor,
    bool isOwner,
    String type,
  ) {
    final safeType = type.isEmpty ? 'vyuha' : type;
    final String typeLabel = safeType.toUpperCase();
    final IconData typeIcon = safeType == 'kram'
        ? Icons.account_tree_outlined
        : Icons.psychology_outlined;

    return InkWell(
      onTap: () =>
          Get.toNamed(safeType == 'kram' ? '/kram/$docId' : '/vyuha/$docId'),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _dividerColor.withOpacity(0.5), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor,
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
                        // Type label
                        Row(
                          children: [
                            Icon(typeIcon, color: accentColor, size: 12),
                            SizedBox(width: 4),
                            Text(
                              typeLabel,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (!isOwner) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _accentBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _accentBlue.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  'COLLABORATOR',
                                  style: TextStyle(
                                    color: _accentBlue,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          title,
                          style: _titleLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Text(
                      createdAt != null
                          ? _formatDate(createdAt.toDate())
                          : 'Just now',
                      style: _bodySmall,
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
                  safeType,
                  isOwner,
                  _textMutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Empty State ---
  Widget _buildEmptyState() {
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
            'अद्यापि कोष्ठो नास्ति',
            style: TextStyle(
              fontSize: 24,
              color: _textMutedColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Create your first Vyuha',
            style: TextStyle(
              fontSize: 14,
              color: _hintColor,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showCreateMenu,
            icon: Icon(Icons.add, size: 20),
            label: Text('Create Vyuha'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange,
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
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
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
