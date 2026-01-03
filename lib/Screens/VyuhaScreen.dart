// FILE: lib/screens/VyuhaScreen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Node;
import 'package:graphview/GraphView.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vyuha/controllers/VyuhaController.dart';
import 'package:vyuha/models/NodeModel.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:typed_data';

import 'package:vyuha/helpers/platform_helper.dart';
import 'package:vyuha/models/CollaboratorModel.dart';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VyuhaScreen extends StatefulWidget {
  final String roomId;
  VyuhaScreen({Key? key, String? roomId})
      : roomId = roomId ?? Get.arguments as String? ?? '',
        super(key: key);

  @override
  State<VyuhaScreen> createState() => _VyuhaScreenState();
}

class _VyuhaScreenState extends State<VyuhaScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _graphKey = GlobalKey();
  final PlatformHelper _platformHelper = PlatformHelper();
  double _currentScale = 1.0;
  int _orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

  bool _isDarkMode = Get.isDarkMode;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _notificationMessage;
  bool _isNotificationError = false;
  Timer? _notificationTimer;

  Offset? _tapPosition;

  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    if (widget.roomId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed('/home');
      });
      return;
    }

    if (!Get.isRegistered<VyuhaController>(tag: widget.roomId)) {
      Get.put(VyuhaController(widget.roomId), tag: widget.roomId);
    }
    _transformationController.addListener(_onTransformationChanged);

    _platformHelper.listenForFullscreen((isNowFullscreen) {
      setState(() {
        _isFullscreen = isNowFullscreen;
      });
    });

    if (kIsWeb) {
      setState(() {
        _isFullscreen = _platformHelper.isFullscreen;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final VyuhaController ctrl = Get.find<VyuhaController>(tag: widget.roomId);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final scaffoldBg = _isDarkMode ? Color(0xFF0D0D0D) : Color(0xFFF4F4F4);

    final iconColor = _isDarkMode ? Colors.white70 : Colors.black54;
    final List<Widget> actions = _buildActions(ctrl, iconColor);

    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          Get.offAllNamed('/home');
          return false;
        },
        child: Scaffold(
          backgroundColor: scaffoldBg,
          appBar: (isLargeScreen || _isSearching)
              ? null
              : _MobileAppBar(
                  ctrl: ctrl,
                  isDarkMode: _isDarkMode,
                  actions: actions,
                ),
          body: Obx(() {
            final nodes = ctrl.nodes;
            return Stack(
              children: [
                CustomPaint(
                  painter: GridBackgroundPainter(isDarkMode: _isDarkMode),
                  child: Container(),
                ),
                if (nodes.isNotEmpty)
                  _GraphWidget(
                    ctrl: ctrl,
                    isLargeScreen: isLargeScreen,
                    isDarkMode: _isDarkMode,
                    orientation: _orientation,
                    graphKey: _graphKey,
                    transformationController: _transformationController,
                    onNodeTapDown: (details) {
                      _tapPosition = details.globalPosition;
                    },
                    onNodeTap: (ctx, node) {
                      if (_tapPosition != null) {
                        _showNodeOptions(ctx, ctrl, node, _tapPosition!);
                      }
                    },
                    onNodeLongPress: (ctx, node) =>
                        _showEditDialog(ctx, ctrl, node),
                  ),
                if (nodes.isEmpty && !_isSearching)
                  _EmptyState(
                    isDarkMode: _isDarkMode,
                    isLargeScreen: isLargeScreen,
                    onAddIdea: () => _showAddDialog(context, ctrl, null),
                  ),
                if (isLargeScreen && !_isSearching)
                  _TopLeftControls(
                    ctrl: ctrl,
                    isLargeScreen: isLargeScreen,
                    isDarkMode: _isDarkMode,
                  ),
                if (isLargeScreen && !_isSearching)
                  _TopRightControls(
                    isDarkMode: _isDarkMode,
                    actions: actions,
                  ),
                if (!_isSearching)
                  _ZoomControls(
                    isDarkMode: _isDarkMode,
                    currentScale: _currentScale,
                  ),
                if (_isSearching)
                  _SearchOverlay(
                    isDarkMode: _isDarkMode,
                    ctrl: ctrl,
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    onCloseSearch: _stopSearch,
                    onQuerySubmitted: (query) {
                      if (query.isNotEmpty) {
                        final results = ctrl.searchNodes(query);
                        _stopSearch();
                        _showSearchResults(context, ctrl, results, query);
                      } else {
                        _stopSearch();
                      }
                    },
                  ),
                _NotificationWidget(
                  notificationMessage: _notificationMessage,
                  isNotificationError: _isNotificationError,
                  isDarkMode: _isDarkMode,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _generatePasskey() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  Future<void> _generateKramForNode(NodeModel node) async {
    _showCustomNotification('Creating Kram for "${node.text}"...');

    try {
      final firestore = FirebaseFirestore.instance;
      final ctrl = Get.find<VyuhaController>(tag: widget.roomId);
      final uid = ctrl.uid;

      final newRoomRef = await firestore.collection('rooms').add({
        'title': '${node.text} Kram',
        'owner': uid,
        'passkey': _generatePasskey(),
        'collaborators': [],
        'bannedUsers': [],
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'kram',
        'generationTopic': node.text,
        'generationContext': 'Derived from Vyuha node: ${node.text}',
        'parentVyuhaId': widget.roomId,
        'parentNodeId': node.id,
      });

      Get.toNamed('/kram/${newRoomRef.id}');

    } catch (e) {
      print('Error generating Kram: $e');
      _showCustomNotification('Failed to generate Kram. $e', isError: true);
    }
  }

  void _toggleFullScreen() {
    if (!kIsWeb) return;
    _platformHelper.toggleFullScreen();
  }

  void _onTransformationChanged() {
    final newScale = _transformationController.value.getMaxScaleOnAxis();
    if ((_currentScale - newScale).abs() > 0.01) {
      setState(() {
        _currentScale = newScale;
      });
    }
  }

  void _showCustomNotification(String message, {bool isError = false}) {
    setState(() {
      _notificationMessage = message;
      _isNotificationError = isError;
      _notificationTimer?.cancel();
      _notificationTimer = Timer(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _notificationMessage = null;
          });
        }
      });
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    _searchFocusNode.requestFocus();
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  List<Widget> _buildActions(VyuhaController ctrl, Color iconColor) {
    return [
      _buildToolbarButton(
        _isDarkMode
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
        _isDarkMode ? 'Light Mode' : 'Dark Mode',
        iconColor,
        () {
          setState(() {
            _isDarkMode = !_isDarkMode;
          });
        },
      ),
      _buildToolbarButton(
        _orientation ==
                BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
            ? Icons.account_tree_outlined
            : Icons.device_hub_outlined,
        _orientation ==
                BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
            ? 'Vertical Layout'
            : 'Horizontal Layout',
        iconColor,
        () {
          setState(() {
            _orientation = _orientation ==
                    BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
                ? BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
                : BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
          });
        },
      ),
      if (kIsWeb)
        _buildToolbarButton(
          _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          _isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
          iconColor,
          _toggleFullScreen,
        ),
      _buildToolbarButton(
        Icons.search,
        'Search',
        iconColor,
        _startSearch,
      ),
      Obx(() {
        if (ctrl.isOwner.value) {
          return _buildToolbarButton(
            Icons.share_outlined,
            'Share Vyuha',
            iconColor,
            () => _showShareDialog(context, ctrl),
          );
        }
        return SizedBox.shrink();
      }),
      Obx(() {
        if (ctrl.isOwner.value) {
          return _buildToolbarButton(
            Icons.group_outlined,
            'Manage Collaborators',
            iconColor,
            () => _showCollaboratorDialog(context, ctrl),
          );
        }
        return SizedBox.shrink();
      }),
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: iconColor, size: 22),
        color: _isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFFDFDFD),
        tooltip: 'More options',
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'export_image',
            child: Row(
              children: [
                Icon(Icons.image_outlined, size: 18, color: iconColor),
                SizedBox(width: 12),
                Text('Export as Image',
                    style: TextStyle(
                        color: _isDarkMode
                            ? Colors.white70
                            : Colors.black87)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'export',
            child: Row(
              children: [
                Icon(Icons.download_outlined, size: 18, color: iconColor),
                SizedBox(width: 12),
                Text('Export as Text',
                    style: TextStyle(
                        color: _isDarkMode
                            ? Colors.white70
                            : Colors.black87)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'clear',
            child: Row(
              children: [
                Icon(Icons.delete_outline,
                    size: 18, color: Colors.red.shade300),
                SizedBox(width: 12),
                Text('Clear All',
                    style: TextStyle(color: Colors.red.shade300)),
              ],
            ),
          ),
        ],
        onSelected: (value) async {
          if (value == 'export') {
            _exportVyuha(context, ctrl);
          } else if (value == 'export_image') {
            _exportVyuhaAsImage(context);
          } else if (value == 'clear') {
            final confirm =
                await _confirmAction(context, 'Clear all nodes?');
            if (confirm) await ctrl.clearAllNodes();
          }
        },
      ),
    ];
  }

  Widget _buildToolbarButton(
      IconData icon, String tooltip, Color iconColor, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: iconColor, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 20,
      padding: EdgeInsets.all(10),
    );
  }

  Future<void> _showShareDialog(BuildContext ctx, VyuhaController ctrl) async {
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;

    await showDialog(
      context: ctx,
      builder: (c) => Obx(() => AlertDialog(
            backgroundColor: dialogBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.share, color: Color(0xFF6B7FFF)),
                SizedBox(width: 12),
                Text('Share Vyuha',
                    style: TextStyle(color: mainText, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share this passkey with others to collaborate:',
                  style: TextStyle(color: subText, fontSize: 14),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? Color(0xFF2A2A2A)
                        : Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFF6B7FFF),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ctrl.passkey.value,
                        style: TextStyle(
                          color: mainText,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, color: Color(0xFF6B7FFF)),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: ctrl.passkey.value));
                          _showCustomNotification(
                              'Passkey copied to clipboard');
                        },
                        tooltip: 'Copy passkey',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Anyone with this passkey can contribute to this Vyuha.',
                  style: TextStyle(
                    color: subText,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Close', style: TextStyle(color: subText)),
              ),
            ],
          )),
    );
  }

  Future<void> _showCollaboratorDialog(
      BuildContext ctx, VyuhaController ctrl) async {
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;
    final dividerColor = _isDarkMode ? Colors.white12 : Colors.black12;

    Widget _buildSectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
        child: Text(
          title,
          style: TextStyle(
            color: mainText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    Widget _buildEmptyState(String message) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            message,
            style: TextStyle(color: subText, fontSize: 14),
          ),
        ),
      );
    }

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.group_outlined, color: Color(0xFF6B7FFF)),
            SizedBox(width: 12),
            Text('Manage Collaborators',
                style: TextStyle(color: mainText, fontSize: 18)),
          ],
        ),
        content: Container(
          width: kIsWeb ? 450 : double.maxFinite,
          constraints: BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('In this Vyuha'),
                Obx(() {
                  if (ctrl.collaborators.isEmpty) {
                    return _buildEmptyState('Loading collaborators...');
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: ctrl.collaborators.length,
                    itemBuilder: (context, index) {
                      final collaborator = ctrl.collaborators[index];
                      final isOwner = collaborator.isOwner;

                      return ListTile(
                        leading:
                            Icon(Icons.person_outline, color: subText),
                        title: Text(
                          collaborator.name,
                          style: TextStyle(
                              color: mainText,
                              fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          "@${collaborator.username}",
                          style: TextStyle(color: subText, fontSize: 12),
                        ),
                        trailing: isOwner
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color:
                                        Color(0xFFF4991A).withOpacity(0.2),
                                    borderRadius:
                                        BorderRadius.circular(6)),
                                child: Text('Owner',
                                    style: TextStyle(
                                        color: Color(0xFFF4991A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              )
                            : IconButton(
                                icon: Icon(Icons.person_remove_outlined,
                                    color: Colors.red.shade300),
                                tooltip: 'Remove ${collaborator.name}',
                                onPressed: () async {
                                  final confirm = await _confirmAction(
                                      ctx,
                                      'Remove ${collaborator.name} from this Vyuha? They will be banned from re-joining.');
                                  if (confirm) {
                                    try {
                                      await ctrl.removeCollaborator(
                                          collaborator.id);
                                      _showCustomNotification(
                                          '${collaborator.name} has been removed and banned.');
                                    } catch (e) {
                                      _showCustomNotification(
                                          e.toString(),
                                          isError: true);
                                    }
                                  }
                                },
                              ),
                      );
                    },
                  );
                }),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: dividerColor, height: 1),
                ),

                _buildSectionTitle('Banned Users'),
                Obx(() {
                  if (ctrl.bannedUsers.isEmpty) {
                    return _buildEmptyState('No users are banned.');
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: ctrl.bannedUsers.length,
                    itemBuilder: (context, index) {
                      final bannedUser = ctrl.bannedUsers[index];

                      return ListTile(
                        leading: Icon(Icons.block, color: subText),
                        title: Text(
                          bannedUser.name,
                          style: TextStyle(
                              color: mainText.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.lineThrough),
                        ),
                        subtitle: Text(
                          "@${bannedUser.username}",
                          style:
                              TextStyle(color: subText, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.undo,
                              color: Colors.green.shade400),
                          tooltip: 'Unblock ${bannedUser.name}',
                          onPressed: () async {
                            final confirm = await _confirmAction(
                                ctx,
                                'Unblock ${bannedUser.name}? They will be able to re-join using the passkey.');
                            if (confirm) {
                              try {
                                await ctrl
                                    .unblockCollaborator(bannedUser.id);
                                _showCustomNotification(
                                    '${bannedUser.name} has been unblocked.');
                              } catch (e) {
                                _showCustomNotification(e.toString(),
                                    isError: true);
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: subText)),
          ),
        ],
      ),
    );
  }

  Future<void> _showNodeOptions(BuildContext ctx, VyuhaController ctrl,
      NodeModel node, Offset tapPosition) async {
    final isMyNode = node.authorId == ctrl.uid;
    final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox;
    final mainText = _isDarkMode ? Colors.white : Colors.black;

    final String? selectedAction = await showMenu(
      context: ctx,
      color: _isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFFDFDFD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 30, 30),
        Offset.zero & overlay.size,
      ),
      items: [
        _buildContextMenuItem(
          icon: Icons.add_circle_outline,
          label: 'Add Child',
          color: Color(0xFFF4991A),
          value: 'add_child',
        ),
        _buildContextMenuItem(
          icon: Icons.auto_awesome,
          label: 'AI Expand',
          color: Color(0xFF6B7FFF),
          value: 'ai_expand',
        ),
        _buildContextMenuItem(
          icon: Icons.auto_stories_outlined,
          label: 'AI Explain',
          color: Color(0xFF6B7FFF),
          value: 'ai_explain',
        ),
        _buildContextMenuItem(
          icon: Icons.account_tree_outlined,
          label: 'Generate Kram',
          color: Color(0xFF8D5F8C),
          value: 'generate_kram',
        ),
        if (isMyNode)
          _buildContextMenuItem(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: mainText.withOpacity(0.8),
            value: 'edit',
          ),
        if (isMyNode)
          _buildContextMenuItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: Colors.red.shade300,
            value: 'delete',
          ),
      ],
      elevation: 8.0,
    );

    if (selectedAction == null) return;

    switch (selectedAction) {
      case 'add_child':
        _showAddDialog(ctx, ctrl, node.id);
        break;
      case 'ai_expand':
        _showAIExpandDialog(ctx, ctrl,
            parentId: node.id, topic: node.text);
        break;
      case 'ai_explain':
        _showAIExplainDialog(ctx, ctrl, node);
        break;
      case 'generate_kram':
        _generateKramForNode(node);
        break;
      case 'edit':
        _showEditDialog(ctx, ctrl, node);
        break;
      case 'delete':
        final confirm = await _confirmAction(
            ctx, 'Delete this node and its children?');
        if (confirm) await ctrl.deleteNode(node.id);
        break;
    }
  }

  PopupMenuItem<String> _buildContextMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required String value,  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(
      BuildContext ctx, VyuhaController ctrl, String? parentId) async {
    final txt = TextEditingController();
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final hintText = _isDarkMode ? Colors.white38 : Colors.black38;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;
    final borderColor = _isDarkMode ? Color(0xFF9ECAD6) : Color(0xFF007A9B);

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          parentId == null ? 'Add Root Idea' : 'Add Child Idea',
          style: TextStyle(color: mainText, fontSize: 18),
        ),
        content: Container(
          width: kIsWeb ? 450 : null,
          child: TextField(
            controller: txt,
            style: TextStyle(color: mainText),
            decoration: InputDecoration(
              hintText: 'Enter your idea...',
              hintStyle: TextStyle(color: hintText),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFF4991A), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF4991A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final t = txt.text.trim();
              if (t.isNotEmpty) {
                await ctrl.addNode(t, parentId: parentId ?? 'root');
              }
              Get.back();
            },
            child: Text('Add', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext ctx, VyuhaController ctrl, NodeModel node) async {
    final txt = TextEditingController(text: node.text);
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;
    final borderColor = _isDarkMode ? Color(0xFF9ECAD6) : Color(0xFF007A9B);

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Idea',
            style: TextStyle(color: mainText, fontSize: 18)),
        content: Container(
          width: kIsWeb ? 450 : null,
          child: TextField(
            controller: txt,
            style: TextStyle(color: mainText),
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFF4991A), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF4991A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final t = txt.text.trim();
              if (t.isNotEmpty && t != node.text) {
                await ctrl.updateNode(node.id, t);
              }
              Get.back();
            },
            child: Text('Update', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _showAIExpandDialog(BuildContext ctx, VyuhaController ctrl,
      {String? parentId, String? topic}) async {
    final topicCtrl = TextEditingController(text: topic ?? '');
    final countCtrl = TextEditingController(text: '5');
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final hintText = _isDarkMode ? Colors.white38 : Colors.black38;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;
    final borderColor = _isDarkMode ? Color(0xFF9ECAD6) : Color(0xFF007A9B);

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF6B7FFF)),
            SizedBox(width: 12),
            Text('AI Brainstorm',
                style: TextStyle(color: mainText, fontSize: 18)),
          ],
        ),
        content: Container(
          width: kIsWeb ? 450 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() {
                final uses = ctrl.aiUsesRemaining.value;
                final resetTime = ctrl.aiUseResetTime.value;
                String message;
                Color msgColor;

                if (uses > 0) {
                  message = 'You have $uses AI expansions remaining.';
                  msgColor = Color(0xFF6B7FFF);
                } else if (resetTime != null &&
                    resetTime.isAfter(DateTime.now())) {
                  final hours = resetTime.difference(DateTime.now()).inHours;
                  message = 'AI limit reached. Resets in ~${hours}h.';
                  msgColor = Colors.red.shade300;
                } else {
                  message = 'AI limit reached. Resets soon.';
                  msgColor = Colors.red.shade300;
                }

                return Container(
                  width: double.maxFinite,
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: msgColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: msgColor.withOpacity(0.5))),
                  child: Text(
                    message,
                    style: TextStyle(
                        color: msgColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
              TextField(
                controller: topicCtrl,
                style: TextStyle(color: mainText),
                decoration: InputDecoration(
                  labelText: 'Topic',
                  labelStyle: TextStyle(color: subText),
                  hintText: 'What should AI brainstorm about?',
                  hintStyle: TextStyle(color: hintText),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6B7FFF), width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: countCtrl,
                style: TextStyle(color: mainText),
                decoration: InputDecoration(
                  labelText: 'Number of ideas (1-9)',
                  labelStyle: TextStyle(color: subText),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6B7FFF), width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text == '0') return oldValue;
                    return newValue;
                  }),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: subText)),
          ),
          Obx(() {
            final canPress = ctrl.aiUsesRemaining.value > 0 && !ctrl.isPerformingAI.value;
            return ElevatedButton.icon(
                icon: ctrl.isPerformingAI.value 
                  ? Container(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.auto_awesome, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6B7FFF),
                  disabledBackgroundColor: Color(0xFF6B7FFF).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: canPress
                    ? () async {
                        final t = topicCtrl.text.trim();
                        final count = int.tryParse(countCtrl.text) ?? 5;

                        if (t.isNotEmpty && count > 0) {
                          Get.back();
                          _showCustomNotification('AI is generating ideas...');
                          try {
                            await ctrl.expandWithAI(
                                topic: t, count: count, parentId: parentId);
                            _showCustomNotification(
                                'AI generation complete. ${ctrl.aiUsesRemaining.value} uses remaining.');
                          } catch (e) {
                            _showCustomNotification(
                                e.toString().replaceFirst("Exception: ", ""),
                                isError: true);
                          }
                        } else if (t.isEmpty) {
                          _showCustomNotification('Please enter a topic',
                              isError: true);
                        } else {
                          _showCustomNotification(
                              'Please enter a valid number (1-9)',
                              isError: true);
                        }
                      }
                    : null,
                label: Text(ctrl.isPerformingAI.value ? 'Generating...' : 'Generate', style: TextStyle(color: Colors.white)),
              );
          })
        ],
      ),
    );
  }

  Future<void> _showAIExplainDialog(
      BuildContext ctx, VyuhaController ctrl, NodeModel node) async {
    final dialogBg = _isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final mainText = _isDarkMode ? Colors.white : Colors.black;

    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            width: kIsWeb ? 600 : MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
              border: Border.all(
                color: _isDarkMode ? Colors.white10 : Colors.black12,
                width: 1,
              ),
            ),
            child: _AIExplainDialogContent(
              node: node,
              isDarkMode: _isDarkMode,
              ctrl: ctrl,
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack).value,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  void _showSearchResults(BuildContext ctx, VyuhaController ctrl,
      List<NodeModel> results, String query) {
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;

    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Results for "$query"',
            style: TextStyle(color: mainText, fontSize: 18)),
        content: results.isEmpty
            ? Text('No matching nodes found',
                style: TextStyle(color: subText))
            : Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final node = results[i];
                    return ListTile(
                      title: Text(
                        node.text,
                        style: TextStyle(color: mainText.withOpacity(0.9)),
                      ),
                      trailing: Icon(Icons.arrow_forward,
                          color: Color(0xFFF4991A), size: 18),
                      onTap: () {
                        Get.back();
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: subText)),
          )
        ],
      ),
    );
  }

  void _exportVyuha(BuildContext ctx, VyuhaController ctrl) {
    final export = ctrl.exportAsText();
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;

    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Export Vyuha as Text',
            style: TextStyle(color: mainText, fontSize: 18)),
        content: SingleChildScrollView(
          child: SelectableText(
            export,
            style: TextStyle(
              color: mainText.withOpacity(0.85),
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: subText)),
          )
        ],
      ),
    );
  }

  Future<void> _exportVyuhaAsImage(BuildContext context) async {
    _showCustomNotification('Generating image...');

    try {
      final RenderRepaintBoundary boundary =
          _graphKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Could not convert image to byte data.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        await _platformHelper.saveImage(pngBytes, 'Vyuha-Export.png');
        _showCustomNotification('Image export started');
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/Vyuha-Export.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Check out this Vyuha brainstorm!',
        );
        _showCustomNotification('Image shared');
      }
    } catch (e) {
      print('Error exporting image: $e');
      _showCustomNotification('Failed to generate image', isError: true);
    }
  }

  Future<bool> _confirmAction(BuildContext ctx, String message) async {
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;

    final res = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm',
            style: TextStyle(color: mainText, fontSize: 18)),
        content:
            Text(message, style: TextStyle(color: mainText.withOpacity(0.85))),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: TextStyle(color: subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Get.back(result: true),
            child: Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

class _AIExplainDialogContent extends StatefulWidget {
  final NodeModel node;
  final bool isDarkMode;
  final VyuhaController ctrl;

  const _AIExplainDialogContent({
    Key? key,
    required this.node,
    required this.isDarkMode,
    required this.ctrl,
  }) : super(key: key);

  @override
  State<_AIExplainDialogContent> createState() => _AIExplainDialogContentState();
}

class _AIExplainDialogContentState extends State<_AIExplainDialogContent> {
  String? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    try {
      final report = await widget.ctrl.explainNodeWithAI(widget.node.text);
      
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainText = widget.isDarkMode ? Colors.white : Colors.black;
    final subText = widget.isDarkMode ? Colors.white54 : Colors.black54;
    final accentColor = Color(0xFF6B7FFF);

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: widget.isDarkMode ? Colors.white12 : Colors.black12)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_stories_outlined,
                    color: accentColor, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Insight',
                      style: TextStyle(
                        color: mainText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Analyzing "${widget.node.text}"',
                      style: TextStyle(
                        color: subText,
                        fontSize: 13,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: subText),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
        ),

        // Body
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: accentColor,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Synthesizing report...',
                        style: TextStyle(color: subText, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Failed to generate report: $_error',
                          style: TextStyle(color: Colors.red.shade300),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: SelectableText(
                        _report!,
                        style: TextStyle(
                          color: mainText.withOpacity(0.9),
                          fontSize: 15,
                          height: 1.6,
                          fontFamily: 'Roboto', 
                        ),
                      ),
                    ),
        ),

        // Footer
        if (!_isLoading && _error == null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color:
                          widget.isDarkMode ? Colors.white12 : Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (_report != null) {
                      Clipboard.setData(ClipboardData(text: _report!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Report copied to clipboard')),
                      );
                    }
                  },
                  icon: Icon(Icons.copy, size: 18, color: subText),
                  label: Text('Copy', style: TextStyle(color: subText)),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          )
      ],
    );
  }
}

class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VyuhaController ctrl;
  final bool isDarkMode;
  final List<Widget> actions;

  const _MobileAppBar({
    Key? key,
    required this.ctrl,
    required this.isDarkMode,
    required this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final panelBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    return AppBar(
      backgroundColor: panelBg,
      foregroundColor: iconColor,
      elevation: 0.5,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: Obx(() {
        final String fullTitle = ctrl.roomTitle.value;
        final String title = fullTitle.length > 20
            ? '${fullTitle.substring(0, 20)}...'
            : fullTitle;
        return Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        );
      }),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class _TopLeftControls extends StatelessWidget {
  final VyuhaController ctrl;
  final bool isLargeScreen;
  final bool isDarkMode;

  const _TopLeftControls({
    Key? key,
    required this.ctrl,
    required this.isLargeScreen,
    required this.isDarkMode,
  }) : super(key: key);

  Widget _statChip(
      IconData icon, String label, Color color, bool isLargeScreen,
      {String? tooltip}) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isLargeScreen ? 15 : 14, color: color),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: isLargeScreen ? 13 : 12,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white70 : Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: chip,
        waitDuration: Duration(milliseconds: 500),
      );
    }
    return chip;
  }

  @override
  Widget build(BuildContext context) {
    final panelBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final panelBorder = isDarkMode ? Color(0xFF333333) : Color(0xFFE0E0E0);
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: 12, vertical: isLargeScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: panelBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isLargeScreen) ...[
              InkWell(
                onTap: () {
                  Get.offAllNamed('/home');
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/icon.png',
                      height: 28,
                      width: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              VerticalDivider(
                color: panelBorder,
                width: 24,
                indent: 4,
                endIndent: 4,
              ),
            ],
            Obx(() {
              final String fullTitle = ctrl.roomTitle.value;
              final String title = isLargeScreen
                  ? fullTitle
                  : (fullTitle.length > 10
                      ? '${fullTitle.substring(0, 10)}...'
                      : fullTitle);
              return Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              );
            }),
            if (isLargeScreen) ...[
              VerticalDivider(
                color: panelBorder,
                width: 24,
                indent: 4,
                endIndent: 4,
              ),
              Obx(() => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _statChip(Icons.circle, '${ctrl.nodes.length}',
                          Color(0xFF6B7FFF), isLargeScreen),
                      SizedBox(width: 16),
                      _statChip(Icons.layers_outlined, '${ctrl.getDepth()}',
                          Color(0xFFF4991A), isLargeScreen),
                      SizedBox(width: 16),
                      _statChip(
                          Icons.people_outline,
                          '${ctrl.collaborators.length}',
                          Color(0xFFFF6B9D),
                          isLargeScreen,
                          tooltip: 'Collaborators'),
                      SizedBox(width: 16),
                      _statChip(Icons.auto_awesome_outlined,
                          '${ctrl.aiUsesRemaining.value}/15',
                          Color(0xFF6B7FFF), isLargeScreen,
                          tooltip: 'AI Expansions Remaining'),
                    ],
                  ))
            ]
          ],
        ),
      ),
    );
  }
}

class _TopRightControls extends StatelessWidget {
  final bool isDarkMode;
  final List<Widget> actions;

  const _TopRightControls({
    Key? key,
    required this.isDarkMode,
    required this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final panelBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final panelBorder = isDarkMode ? Color(0xFF333333) : Color(0xFFE0E0E0);

    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: panelBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: actions,
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  final bool isDarkMode;
  final double currentScale;

  const _ZoomControls({
    Key? key,
    required this.isDarkMode,
    required this.currentScale,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final panelBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final panelBorder = isDarkMode ? Color(0xFF333333) : Color(0xFFE0E0E0);
    final textColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: panelBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '${(currentScale * 100).toInt()}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _SearchOverlay extends StatelessWidget {
  final bool isDarkMode;
  final VyuhaController ctrl;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onQuerySubmitted;

  const _SearchOverlay({
    Key? key,
    required this.isDarkMode,
    required this.ctrl,
    required this.searchController,
    required this.searchFocusNode,
    required this.onCloseSearch,
    required this.onQuerySubmitted,
  }) : super(key: key);

  Widget _buildSearchField(VyuhaController ctrl) {
    return TextField(
      controller: searchController,
      focusNode: searchFocusNode,
      autofocus: true,
      style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Search nodes...',
        hintStyle: TextStyle(
            color: isDarkMode ? Colors.white54 : Colors.black54,
            fontSize: 16),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
      ),
      onSubmitted: onQuerySubmitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final panelBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final panelBorder = isDarkMode ? Color(0xFF333333) : Color(0xFFE0E0E0);
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        padding: EdgeInsets.only(top: 15),
        decoration: BoxDecoration(
          color: panelBg.withOpacity(0.95),
          border: Border(bottom: BorderSide(color: panelBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Row(
              children: [
                SizedBox(width: 16),
                Icon(Icons.search, color: iconColor, size: 22),
                SizedBox(width: 12),
                Expanded(child: _buildSearchField(ctrl)),
                IconButton(
                  icon: Icon(Icons.close, color: iconColor, size: 22),
                  onPressed: onCloseSearch,
                  tooltip: 'Close search',
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationWidget extends StatelessWidget {
  final String? notificationMessage;
  final bool isNotificationError;
  final bool isDarkMode;

  const _NotificationWidget({
    Key? key,
    this.notificationMessage,
    required this.isNotificationError,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.0, 1.0),
              end: Offset(0.0, 0.0),
            ).animate(animation),
            child: child,
          );
        },
        child: notificationMessage == null
            ? SizedBox.shrink()
            : Center(
                key: ValueKey(notificationMessage),
                child: Container(
                  constraints: BoxConstraints(maxWidth: 500),
                  margin: EdgeInsets.symmetric(horizontal: 15),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isNotificationError
                          ? Colors.red.shade300
                          : (isDarkMode
                              ? Color(0xFF333333)
                              : Color(0xFFE0E0E0)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    notificationMessage!,
                    style: TextStyle(
                      color: isNotificationError
                          ? Colors.red.shade300
                          : (isDarkMode ? Colors.white : Colors.black),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDarkMode;
  final bool isLargeScreen;
  final VoidCallback onAddIdea;

  const _EmptyState({
    Key? key,
    required this.isDarkMode,
    required this.isLargeScreen,
    required this.onAddIdea,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mainText = isDarkMode ? Colors.white54 : Colors.black54;
    final subText = isDarkMode ? Colors.white38 : Colors.black38;

    return Container(
      color: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined,
                size: isLargeScreen ? 72 : 64, color: Color(0xFF9ECAD6)),
            SizedBox(height: 20),
            Text(
              'No ideas yet',
              style: TextStyle(
                fontSize: isLargeScreen ? 20 : 18,
                color: mainText,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start your brainstorm',
              style: TextStyle(
                fontSize: 13,
                color: subText,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onAddIdea,
                  icon: Icon(Icons.add, size: 18),
                  label: Text('Add Idea'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF4991A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 24 : 20,
                        vertical: isLargeScreen ? 14 : 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(width: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphWidget extends StatelessWidget {
  final VyuhaController ctrl;
  final bool isLargeScreen;
  final bool isDarkMode;
  final int orientation;
  final GlobalKey graphKey;
  final TransformationController transformationController;
  final Function(TapDownDetails) onNodeTapDown;
  final Function(BuildContext, NodeModel) onNodeTap;
  final Function(BuildContext, NodeModel) onNodeLongPress;

  const _GraphWidget({
    Key? key,
    required this.ctrl,
    required this.isLargeScreen,
    required this.isDarkMode,
    required this.orientation,
    required this.graphKey,
    required this.transformationController,
    required this.onNodeTapDown,
    required this.onNodeTap,
    required this.onNodeLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final graph = Graph()..isTree = false;
    final Map<String, Node> nodeWidgets = {};

    for (var n in ctrl.nodes) {
      final widget = _VyuhaNodeWidget(
        ctrl: ctrl,
        node: n,
        isLargeScreen: isLargeScreen,
        isDarkMode: isDarkMode,
        onTapDown: onNodeTapDown,
        onTap: () => onNodeTap(context, n),
        onLongPress: () => onNodeLongPress(context, n),
      );
      nodeWidgets[n.id] = Node.Id(widget);
    }

    for (var n in ctrl.nodes) {
      if (n.parentId.isNotEmpty && nodeWidgets.containsKey(n.parentId)) {
        graph.addEdge(nodeWidgets[n.parentId]!, nodeWidgets[n.id]!);
      }
    }

    for (var w in nodeWidgets.values) {
      if (!graph.nodes.contains(w)) {
        graph.addNode(w);
      }
    }

    final builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = isLargeScreen ? 90 : 80
      ..levelSeparation = isLargeScreen ? 110 : 100
      ..subtreeSeparation = isLargeScreen ? 90 : 80
      ..orientation = orientation;

    return InteractiveViewer(
      transformationController: transformationController,
      constrained: false,
      boundaryMargin: EdgeInsets.all(500),
      minScale: 0.1,
      maxScale: 4.0,
      panEnabled: true,
      scaleEnabled: true,
      child: RepaintBoundary(
        key: graphKey,
        child: GraphView(
          graph: graph,
          algorithm: BuchheimWalkerAlgorithm(
            builder,
            TreeEdgeRenderer(builder),
          ),
          paint: Paint()
            ..color =
                isDarkMode ? const Color(0xFF9ECAD6) : Color(0xFF007A9B)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
          builder: (Node node) => node.key!.value as Widget,
          animated: false,
        ),
      ),
    );
  }
}

class _VyuhaNodeWidget extends StatelessWidget {
  final VyuhaController ctrl;
  final NodeModel node;
  final bool isLargeScreen;
  final bool isDarkMode;
  final Function(TapDownDetails) onTapDown;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _VyuhaNodeWidget({
    Key? key,
    required this.ctrl,
    required this.node,
    required this.isLargeScreen,
    required this.isDarkMode,
    required this.onTapDown,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMyNode = node.authorId == ctrl.uid;
    final depth = ctrl.getNodeDepth(node.id);
    final childCount = ctrl.getChildrenCount(node.id);

    final colors = [
      Color(0xFF6B7FFF),
      Color(0xFFF4991A),
      Color(0xFFFF6B9D),
      Color(0xFFFFA07A),
      Color(0xFF98D8C8),
    ];
    final accentColor = colors[depth % colors.length];

    final nodeBg = isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFFFFFF);
    final nodeText =
        isDarkMode ? Colors.white.withOpacity(0.95) : Colors.black;
    final nodeBorder = isDarkMode ? Color(0xFF9ECAD6) : Color(0xFF007A9B);
    final childCountBg = isDarkMode ? Color(0xFF9ECAD6) : Color(0xFF007A9B);
    final childCountText = isDarkMode ? Colors.white54 : Colors.white;
    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.grey.withOpacity(0.2);

    return GestureDetector(
      onTapDown: onTapDown,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 240 : 220, minWidth: 140),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: nodeBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMyNode ? accentColor : nodeBorder,
            width: isMyNode ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              node.text,
              style: TextStyle(
                color: nodeText,
                fontWeight: FontWeight.w400,
                fontSize: isLargeScreen ? 14 : 13,
                height: 1.4,
                letterSpacing: 0.2,
              ),
            ),
            if (childCount > 0 || !isMyNode) ...[
              SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (childCount > 0) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: childCountBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.subdirectory_arrow_right,
                              size: 10, color: childCountText),
                          SizedBox(width: 3),
                          Text(
                            '$childCount',
                            style: TextStyle(
                              fontSize: 10,
                              color: childCountText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isMyNode) SizedBox(width: 6),
                  ],
                  if (!isMyNode)
                    Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Icon(Icons.person_outline,
                          size: 10, color: accentColor),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GridBackgroundPainter extends CustomPainter {
  final bool isDarkMode;
  GridBackgroundPainter({this.isDarkMode = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? Color(0xFF1A1A1A).withOpacity(0.5)
          : Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const double gridSpacing = 40.0;

    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridBackgroundPainter oldDelegate) =>
      oldDelegate.isDarkMode != isDarkMode;
}