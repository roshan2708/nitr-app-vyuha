import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Node;
import 'package:graphview/GraphView.dart';
import 'package:vyuha/Screens/KramScreen.dart'; 
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
  // --- STATE VARIABLES ---
  final TransformationController _transformationController = TransformationController();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final VyuhaController ctrl = Get.find<VyuhaController>(tag: widget.roomId);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final scaffoldBg = _isDarkMode ? Color(0xFF0D0D0D) : Color(0xFFF4F4F4);
    final iconColor = _isDarkMode ? Colors.white70 : Colors.black54;

    // Use helper to build actions
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
              : _MobileAppBar(ctrl: ctrl, isDarkMode: _isDarkMode, actions: actions),
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
                    onNodeTapDown: (details) => _tapPosition = details.globalPosition,
                    onNodeTap: (ctx, node) {
                      if (_tapPosition != null) _showNodeOptions(ctx, ctrl, node, _tapPosition!);
                    },
                    onNodeLongPress: (ctx, node) => _showEditDialog(ctx, ctrl, node),
                  ),
                if (nodes.isEmpty && !_isSearching)
                  _EmptyState(
                    isDarkMode: _isDarkMode,
                    isLargeScreen: isLargeScreen,
                    onAddIdea: () => _showAddDialog(context, ctrl, null),
                  ),
                if (isLargeScreen && !_isSearching)
                  _TopLeftControls(ctrl: ctrl, isLargeScreen: isLargeScreen, isDarkMode: _isDarkMode),
                if (isLargeScreen && !_isSearching)
                  _TopRightControls(isDarkMode: _isDarkMode, actions: actions),
                if (!_isSearching)
                  _ZoomControls(isDarkMode: _isDarkMode, currentScale: _currentScale),
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

  // --- UI EVENT HANDLERS ---

  void _toggleFullScreen() {
    if (!kIsWeb) return;
    _platformHelper.toggleFullScreen();
  }

  void _onTransformationChanged() {
    final newScale = _transformationController.value.getMaxScaleOnAxis();
    if ((_currentScale - newScale).abs() > 0.01) {
      setState(() => _currentScale = newScale);
    }
  }

  void _showCustomNotification(String message, {bool isError = false}) {
    setState(() {
      _notificationMessage = message;
      _isNotificationError = isError;
      _notificationTimer?.cancel();
      _notificationTimer = Timer(Duration(seconds: 3), () {
        setState(() => _notificationMessage = null);
      });
    });
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    _searchFocusNode.requestFocus();
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  // --- ACTION BUILDER (FIXED) ---
  List<Widget> _buildActions(VyuhaController ctrl, Color iconColor) {
    return [
      _buildToolbarButton(
        _isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        _isDarkMode ? 'Light Mode' : 'Dark Mode',
        iconColor,
        () => setState(() => _isDarkMode = !_isDarkMode),
      ),
      _buildToolbarButton(
        _orientation == BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
            ? Icons.account_tree_outlined : Icons.device_hub_outlined,
        'Toggle Layout',
        iconColor,
        () => setState(() {
          _orientation = _orientation == BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM
              ? BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
              : BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
        }),
      ),
      if (kIsWeb)
        _buildToolbarButton(
          _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          _isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
          iconColor,
          _toggleFullScreen,
        ),
      _buildToolbarButton(Icons.search, 'Search', iconColor, _startSearch),
      
      Obx(() => ctrl.isOwner.value 
        ? _buildToolbarButton(Icons.share_outlined, 'Share', iconColor, () => _showShareDialog(context, ctrl)) 
        : SizedBox.shrink()),
        
      Obx(() => ctrl.isOwner.value 
        ? _buildToolbarButton(Icons.group_outlined, 'Collaborators', iconColor, () => _showCollaboratorDialog(context, ctrl)) 
        : SizedBox.shrink()),
      
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: iconColor, size: 22),
        color: _isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFFDFDFD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'export_image',
            child: Row(
              children: [
                Icon(Icons.image_outlined, size: 18, color: iconColor),
                SizedBox(width: 12),
                Text('Export as Image', style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'export',
            child: Row(
              children: [
                Icon(Icons.download_outlined, size: 18, color: iconColor),
                SizedBox(width: 12),
                Text('Export as Text', style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
          // REMOVED GLOBAL "OPEN KRAM" HERE
          PopupMenuItem(
            value: 'clear',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                SizedBox(width: 12),
                Text('Clear All', style: TextStyle(color: Colors.red.shade300)),
              ],
            ),
          ),
        ],
        onSelected: (value) async {
          if (value == 'export') _exportVyuha(context, ctrl);
          else if (value == 'export_image') _exportVyuhaAsImage(context);
          else if (value == 'clear') {
            if (await _confirmAction(context, 'Clear all nodes?')) await ctrl.clearAllNodes();
          }
        },
      ),
    ];
  }

  Widget _buildToolbarButton(IconData icon, String tooltip, Color iconColor, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: iconColor, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 20,
      padding: EdgeInsets.all(10),
    );
  }

  // --- DIALOGS & OVERLAYS ---

  Future<void> _showShareDialog(BuildContext ctx, VyuhaController ctrl) async {
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;

    await showDialog(
      context: ctx,
      builder: (c) => Obx(() => AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.share, color: Color(0xFF6B7FFF)),
                SizedBox(width: 12),
                Text('Share Vyuha', style: TextStyle(color: mainText, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share this passkey with others to collaborate:', style: TextStyle(color: subText, fontSize: 14)),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF6B7FFF), width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ctrl.passkey.value,
                        style: TextStyle(color: mainText, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, color: Color(0xFF6B7FFF)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: ctrl.passkey.value));
                          _showCustomNotification('Passkey copied to clipboard');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text('Close', style: TextStyle(color: subText))),
            ],
          )),
    );
  }

  Future<void> _showCollaboratorDialog(BuildContext ctx, VyuhaController ctrl) async {
    final dialogBg = _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD);
    final mainText = _isDarkMode ? Colors.white : Colors.black;
    final subText = _isDarkMode ? Colors.white54 : Colors.black54;

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Collaborators', style: TextStyle(color: mainText)),
        content: Container(
          width: kIsWeb ? 450 : double.maxFinite,
          constraints: BoxConstraints(maxHeight: 400),
          child: Obx(() {
            if (ctrl.collaborators.isEmpty) return Center(child: Text("No collaborators yet.", style: TextStyle(color: subText)));
            return ListView.builder(
              itemCount: ctrl.collaborators.length,
              itemBuilder: (context, index) {
                final collaborator = ctrl.collaborators[index];
                return ListTile(
                  title: Text(collaborator.name, style: TextStyle(color: mainText)),
                  subtitle: Text("@${collaborator.username}", style: TextStyle(color: subText)),
                  trailing: collaborator.isOwner 
                    ? Text("Owner", style: TextStyle(color: Color(0xFFF4991A), fontSize: 12))
                    : IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade300),
                        onPressed: () async {
                           if(await _confirmAction(ctx, "Remove ${collaborator.name}?")) {
                             await ctrl.removeCollaborator(collaborator.id);
                             _showCustomNotification("Removed ${collaborator.name}");
                           }
                        },
                      ),
                );
              },
            );
          }),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Close', style: TextStyle(color: subText))),
        ],
      ),
    );
  }

  // --- NODE OPTIONS (Includes KRAM Entry) ---
  Future<void> _showNodeOptions(BuildContext ctx, VyuhaController ctrl, NodeModel node, Offset tapPosition) async {
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
        _buildContextMenuItem(Icons.add_circle_outline, 'Add Child', Color(0xFFF4991A), 'add_child'),
        _buildContextMenuItem(Icons.auto_awesome, 'AI Expand', Color(0xFF6B7FFF), 'ai_expand'),
        
        // --- KRAM ENTRY POINT (FIXED) ---
        PopupMenuItem<String>(
          value: 'open_kram',
          child: Row(
            children: [
              Icon(Icons.hub_outlined, color: Color(0xFFF4991A), size: 20),
              SizedBox(width: 12),
              Text('Deep Dive (Kram)', style: TextStyle(
                color: _isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              )),
            ],
          ),
        ),
        // -------------------------------

        if (isMyNode) _buildContextMenuItem(Icons.edit_outlined, 'Edit', mainText.withOpacity(0.8), 'edit'),
        if (isMyNode) _buildContextMenuItem(Icons.delete_outline, 'Delete', Colors.red.shade300, 'delete'),
      ],
      elevation: 8.0,
    );

    if (selectedAction == null) return;

    switch (selectedAction) {
      case 'add_child': _showAddDialog(ctx, ctrl, node.id); break;
      case 'ai_expand': _showAIExpandDialog(ctx, ctrl, parentId: node.id, topic: node.text); break;
      case 'edit': _showEditDialog(ctx, ctrl, node); break;
      case 'delete':
        if (await _confirmAction(ctx, 'Delete this node?')) await ctrl.deleteNode(node.id);
        break;
      case 'open_kram':
        // FIX: CALL WITH NAMED PARAMETERS
        Get.to(
          () => KramScreen(
            roomId: ctrl.roomId,
            nodeId: node.id,
            nodeText: node.text,
          ),
        );
        break;
    }
  }

  PopupMenuItem<String> _buildContextMenuItem(IconData icon, String label, Color color, String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Text(label, style: TextStyle(
            color: _isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
            fontSize: 14,
          )),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext ctx, VyuhaController ctrl, String? parentId) async {
    final txt = TextEditingController();
    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD),
        title: Text(parentId == null ? 'Add Root Idea' : 'Add Child Idea', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        content: Container(
          width: kIsWeb ? 450 : null,
          child: TextField(
            controller: txt,
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
            decoration: InputDecoration(hintText: 'Enter idea...', hintStyle: TextStyle(color: Colors.grey)),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFF4991A)),
            onPressed: () async {
              if (txt.text.isNotEmpty) await ctrl.addNode(txt.text.trim(), parentId: parentId ?? 'root');
              Get.back();
            },
            child: Text('Add', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext ctx, VyuhaController ctrl, NodeModel node) async {
    final txt = TextEditingController(text: node.text);
    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD),
        title: Text('Edit Idea', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        content: Container(
          width: kIsWeb ? 450 : null,
          child: TextField(
            controller: txt,
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFF4991A)),
            onPressed: () async {
              if (txt.text.isNotEmpty && txt.text != node.text) await ctrl.updateNode(node.id, txt.text.trim());
              Get.back();
            },
            child: Text('Update', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _showAIExpandDialog(BuildContext ctx, VyuhaController ctrl, {String? parentId, String? topic}) async {
    final topicCtrl = TextEditingController(text: topic ?? '');
    final countCtrl = TextEditingController(text: '5');
    
    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD),
        title: Row(children: [Icon(Icons.auto_awesome, color: Color(0xFF6B7FFF)), SizedBox(width: 8), Text('AI Brainstorm', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black))]),
        content: Container(
          width: kIsWeb ? 450 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Obx(() {
                 final uses = ctrl.aiUsesRemaining.value;
                 return Text("Uses Remaining: $uses", style: TextStyle(color: Colors.grey, fontSize: 12));
               }),
               SizedBox(height: 8),
               TextField(controller: topicCtrl, decoration: InputDecoration(labelText: "Topic"), style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
               TextField(controller: countCtrl, decoration: InputDecoration(labelText: "Count (1-9)"), keyboardType: TextInputType.number, style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          Obx(() => ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6B7FFF)),
            onPressed: ctrl.aiUsesRemaining.value > 0 ? () async {
               if(topicCtrl.text.isNotEmpty) {
                 Get.back();
                 _showCustomNotification("AI Generating...");
                 try {
                   await ctrl.expandWithAI(topic: topicCtrl.text, count: int.tryParse(countCtrl.text) ?? 5, parentId: parentId);
                   _showCustomNotification("Done!");
                 } catch(e) {
                   _showCustomNotification("Failed: $e", isError: true);
                 }
               }
            } : null,
            child: Text('Generate', style: TextStyle(color: Colors.white)),
          ))
        ],
      ),
    );
  }

  void _showSearchResults(BuildContext ctx, VyuhaController ctrl, List<NodeModel> results, String query) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD),
        title: Text('Results for "$query"', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        content: Container(
          width: double.maxFinite,
          child: results.isEmpty ? Text("No results") : ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(results[i].text, style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
              onTap: () => Get.back(),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('Close'))],
      ),
    );
  }

  void _exportVyuha(BuildContext ctx, VyuhaController ctrl) {
    final export = ctrl.exportAsText();
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD),
        title: Text('Export Text', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        content: SingleChildScrollView(child: SelectableText(export, style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black))),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('Close'))],
      ),
    );
  }

  Future<void> _exportVyuhaAsImage(BuildContext context) async {
    _showCustomNotification('Generating image...');
    try {
      final boundary = _graphKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      if (kIsWeb) {
        await _platformHelper.saveImage(pngBytes, 'Vyuha-Export.png');
        _showCustomNotification('Image saved');
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/Vyuha-Export.png').create();
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Check out this Vyuha!');
        _showCustomNotification('Share dialog opened');
      }
    } catch (e) {
      _showCustomNotification('Failed to export image', isError: true);
    }
  }

  Future<bool> _confirmAction(BuildContext ctx, String message) async {
    return await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: _isDarkMode ? Color(0xFF1A1A1A) : Color(0xFFFDFDFD),
        title: Text('Confirm', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        content: Text(message, style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Get.back(result: true), 
            child: Text('Confirm', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    ) ?? false;
  }
}

// -------------------------------------------------------------------
// --- UI Components ---
// -------------------------------------------------------------------

class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VyuhaController ctrl;
  final bool isDarkMode;
  final List<Widget> actions;

  const _MobileAppBar({required this.ctrl, required this.isDarkMode, required this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
      foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
      automaticallyImplyLeading: false,
      title: Obx(() => Text(ctrl.roomTitle.value, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18), overflow: TextOverflow.ellipsis)),
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

  const _TopLeftControls({required this.ctrl, required this.isLargeScreen, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final panelBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    return Positioned(
      top: 20, left: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            if(isLargeScreen) InkWell(
              onTap: () => Get.offAllNamed('/home'),
              child: Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.arrow_back, size: 20, color: isDarkMode ? Colors.white70 : Colors.black54)),
            ),
            Obx(() => Text(ctrl.roomTitle.value, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black))),
            SizedBox(width: 16),
            Obx(() => Row(children: [
               Icon(Icons.circle, size: 12, color: Color(0xFF6B7FFF)), SizedBox(width: 4), Text('${ctrl.nodes.length}', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
               SizedBox(width: 12),
               Icon(Icons.people_outline, size: 14, color: Color(0xFFFF6B9D)), SizedBox(width: 4), Text('${ctrl.collaborators.length}', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
            ])),
          ],
        ),
      ),
    );
  }
}

class _TopRightControls extends StatelessWidget {
  final bool isDarkMode;
  final List<Widget> actions;
  const _TopRightControls({required this.isDarkMode, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20, right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(children: actions),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  final bool isDarkMode;
  final double currentScale;
  const _ZoomControls({required this.isDarkMode, required this.currentScale});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20, right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text('${(currentScale * 100).toInt()}%', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)),
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

  const _SearchOverlay({required this.isDarkMode, required this.ctrl, required this.searchController, required this.searchFocusNode, required this.onCloseSearch, required this.onQuerySubmitted});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 80,
        color: (isDarkMode ? Color(0xFF1E1E1E) : Colors.white).withOpacity(0.95),
        padding: EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 10),
            Expanded(child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              autofocus: true,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(border: InputBorder.none, hintText: "Search..."),
              onSubmitted: onQuerySubmitted,
            )),
            IconButton(icon: Icon(Icons.close, color: Colors.grey), onPressed: onCloseSearch),
          ],
        ),
      ),
    );
  }
}

class _NotificationWidget extends StatelessWidget {
  final String? notificationMessage;
  final bool isNotificationError;
  final bool isDarkMode;

  const _NotificationWidget({this.notificationMessage, required this.isNotificationError, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    if (notificationMessage == null) return SizedBox.shrink();
    return Positioned(
      bottom: 30, left: 0, right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isNotificationError ? Colors.red.shade100 : (isDarkMode ? Color(0xFF333333) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isNotificationError ? Colors.red : Colors.grey.withOpacity(0.3)),
          ),
          child: Text(notificationMessage!, style: TextStyle(color: isNotificationError ? Colors.red.shade900 : (isDarkMode ? Colors.white : Colors.black))),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDarkMode;
  final bool isLargeScreen;
  final VoidCallback onAddIdea;

  const _EmptyState({required this.isDarkMode, required this.isLargeScreen, required this.onAddIdea});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
          SizedBox(height: 16),
          Text("No ideas yet", style: TextStyle(fontSize: 20, color: Colors.grey)),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddIdea,
            icon: Icon(Icons.add),
            label: Text("Add Idea"),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFF4991A), foregroundColor: Colors.white),
          )
        ],
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
    required this.ctrl,
    required this.isLargeScreen,
    required this.isDarkMode,
    required this.orientation,
    required this.graphKey,
    required this.transformationController,
    required this.onNodeTapDown,
    required this.onNodeTap,
    required this.onNodeLongPress,
  });

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
      if (!graph.nodes.contains(w)) graph.addNode(w);
    }

    final builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = isLargeScreen ? 90 : 80
      ..levelSeparation = isLargeScreen ? 110 : 100
      ..subtreeSeparation = isLargeScreen ? 90 : 80
      ..orientation = orientation;

    return InteractiveViewer(
      transformationController: transformationController,
      constrained: false,
      boundaryMargin: EdgeInsets.all(1000),
      minScale: 0.1,
      maxScale: 4.0,
      child: RepaintBoundary(
        key: graphKey,
        child: GraphView(
          graph: graph,
          algorithm: BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
          paint: Paint()
            ..color = isDarkMode ? const Color(0xFF9ECAD6) : Color(0xFF007A9B)
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

  const _VyuhaNodeWidget({required this.ctrl, required this.node, required this.isLargeScreen, required this.isDarkMode, required this.onTapDown, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isMyNode = node.authorId == ctrl.uid;
    final depth = ctrl.getNodeDepth(node.id);
    final childCount = ctrl.getChildrenCount(node.id);
    final colors = [Color(0xFF6B7FFF), Color(0xFFF4991A), Color(0xFFFF6B9D), Color(0xFFFFA07A), Color(0xFF98D8C8)];
    final accentColor = colors[depth % colors.length];

    return GestureDetector(
      onTapDown: onTapDown,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: isLargeScreen ? 240 : 220, minWidth: 140),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isMyNode ? accentColor : (isDarkMode ? Color(0xFF9ECAD6) : Color(0xFF007A9B)), width: isMyNode ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.text, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 13)),
            if (childCount > 0) ...[
              SizedBox(height: 8),
              Row(children: [Icon(Icons.subdirectory_arrow_right, size: 10, color: Colors.grey), SizedBox(width: 4), Text("$childCount", style: TextStyle(fontSize: 10, color: Colors.grey))])
            ]
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
    final paint = Paint()..color = (isDarkMode ? Colors.white : Colors.black).withOpacity(0.05)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(covariant GridBackgroundPainter old) => old.isDarkMode != isDarkMode;
}