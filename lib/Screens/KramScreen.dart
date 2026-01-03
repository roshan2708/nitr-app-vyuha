// FILE: lib/screens/KramScreen.dart
// Fully upgraded with Light/Dark Mode, Fullscreen, Bézier curve connections,
// drag-fix, centered node adding, and PNG export.
// MODIFIED: Fixed "Multiple widgets used the same GlobalKey" error.

import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Needed for path metrics, Image, and ImageByteFormat
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Needed for RepaintBoundary
import 'package:flutter/services.dart'; // Needed for Fullscreen and Theme
import 'package:get/get.dart';
import 'package:vyuha/controllers/KramController.dart';
import 'package:vyuha/models/KramModel.dart';
import 'package:vyuha/helpers/platform_helper.dart';
import 'package:vyuha/models/CollaboratorModel.dart';
import 'dart:typed_data'; // Needed for PNG export
import 'package:share_plus/share_plus.dart'; // Needed for PNG export

// --- ENUMS for UI State ---
enum Tool { move, addProcess, addDecision, addStartEnd, connect }

class KramScreen extends StatefulWidget {
  final String roomId;
  KramScreen({Key? key, String? roomId})
      : roomId = roomId ?? Get.arguments as String? ?? '',
        super(key: key);

  @override
  State<KramScreen> createState() => _KramScreenState();
}

class _KramScreenState extends State<KramScreen> {
  // --- STATE VARIABLES ---
  final PlatformHelper _platformHelper = PlatformHelper();
  bool _isDarkMode = Get.isDarkMode;
  bool _isFullscreen = false;
  String? _notificationMessage;
  bool _isNotificationError = false;
  Timer? _notificationTimer;
  late final KramController ctrl;

  // --- UI/CANVAS STATE ---
  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _exportKey = GlobalKey(); 
  Tool _currentTool = Tool.move;

  // --- MARQUEE SELECTION ---
  Rect? _marqueeRect;
  Offset? _marqueeStart;

  // --- NODE CONNECTION ---
  String? _connectFromNodeId;
  AnchorSide? _connectFromAnchor;
  Offset? _connectLiveOffset;

  @override
  void initState() {
    super.initState();
    if (widget.roomId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed('/home');
      });
      return;
    }

    if (!Get.isRegistered<KramController>(tag: widget.roomId)) {
      Get.put(KramController(widget.roomId), tag: widget.roomId);
    }

    ctrl = Get.find<KramController>(tag: widget.roomId);
    ctrl.transformationController.addListener(_onTransformationChanged);

    // Ensure we exit fullscreen if we init the screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
  }

  @override
  void dispose() {
    if (Get.isRegistered<KramController>(tag: widget.roomId)) {
      ctrl.transformationController.removeListener(_onTransformationChanged);
    }
    // Ensure we exit fullscreen when leaving
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    _notificationTimer?.cancel();
    super.dispose();
  }

  // --- MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    if (widget.roomId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Use theme colors for light/dark mode
    final theme = Theme.of(context);
    final scaffoldBg = theme.scaffoldBackgroundColor;
    _isDarkMode = theme.brightness == Brightness.dark; // Sync dark mode state

    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          Get.offAllNamed('/home');
          return false;
        },
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: Obx(() {
            return Stack(
              children: [
                // 1. The Grid Background
                CustomPaint(
                  painter: GridBackgroundPainter(isDarkMode: _isDarkMode),
                  child: Container(),
                ),

                // 2. The Interactive Canvas
                _KramCanvas(
                  key: _canvasKey,
                  exportKey: _exportKey, 
                  ctrl: ctrl,
                  isDarkMode: _isDarkMode,
                  // Callbacks
                  onCanvasTapUp: _onCanvasTapUp,
                  onCanvasPanStart: _onCanvasPanStart,
                  onCanvasPanUpdate: _onCanvasPanUpdate,
                  onCanvasPanEnd: _onCanvasPanEnd,
                  onElementPanStart: _onElementPanStart,
                  onElementPanUpdate: _onElementPanUpdate,
                  onElementPanEnd: _onElementPanEnd,
                  onConnectPanStart: _onConnectPanStart,
                  onConnectPanUpdate: _onConnectPanUpdate,
                  onConnectPanEnd: _onConnectPanEnd,
                  onElementTap: _onElementTap,
                  onElementDoubleTap: _onElementDoubleTap,
                  onElementLongPress: _onElementLongPress,
                  onCanvasPointerMove: _onCanvasPointerMove,
                  // Live State
                  marqueeRect: _marqueeRect,
                  connectFromNodeId: _connectFromNodeId,
                  connectFromAnchor: _connectFromAnchor,
                  connectLiveOffset: _connectLiveOffset,
                ),

                // 3. AI Generation Loading Overlay
                if (ctrl.isGeneratingAI.value)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF8D5F8C)),
                          SizedBox(height: 20),
                          Text('AI is generating Kram...',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),

                // 4. UI Controls
                _TopLeftControls(ctrl: ctrl, isDarkMode: _isDarkMode),
                _KramToolbar(
                  currentTool: _currentTool,
                  onToolSelected: (tool) {
                    setState(() {
                      _currentTool = tool;
                    });
                    ctrl.clearSelection();
                  },
                  isDarkMode: _isDarkMode,
                  ctrl: ctrl,
                  isFullscreen: _isFullscreen,
                  onToggleTheme: _toggleTheme,
                  onToggleFullscreen: _toggleFullscreen,
                  onExport: _exportAsPng,
                ),

                // 5. Notification Widget
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

  void _onTransformationChanged() {
    final newScale = ctrl.transformationController.value.getMaxScaleOnAxis();
    ctrl.currentScale.value = newScale;
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    Get.changeThemeMode(_isDarkMode ? ThemeMode.dark : ThemeMode.light);
    _showCustomNotification(
        _isDarkMode ? "Switched to Dark Mode" : "Switched to Light Mode");
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    }
    _showCustomNotification(
        _isFullscreen ? "Entered Fullscreen" : "Exited Fullscreen");
  }

  // --- MODIFIED: Export Function ---
  Future<void> _exportAsPng() async {
    _showCustomNotification("Preparing export...");
    // Wait a moment for the notification to appear
    await Future.delayed(Duration(milliseconds: 50));

    try {
      // 1. Find the RenderRepaintBoundary
      RenderRepaintBoundary boundary =
          _exportKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // 2. Convert to image
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      // Use at least 2.0x pixel ratio for good quality, even on low-DPI screens
      final image = await boundary.toImage(pixelRatio: max(pixelRatio, 2.0));

      // 3. Convert to ByteData
      ByteData? byteData =
          await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Could not convert image to ByteData");
      }

      // 4. Convert to Uint8List
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 5. Define file details
      final roomName =
          ctrl.roomTitle.value.isNotEmpty ? ctrl.roomTitle.value : "Kram";
      final fileName =
          'vyuha_kram_${DateTime.now().millisecondsSinceEpoch}.png';

      // 6. Share the file using XFile.fromData
      await Share.shareXFiles(
        [
          XFile.fromData(
            pngBytes,
            name: fileName,
            mimeType: 'image/png',
          )
        ],
        text: 'Here is the Kram diagram "$roomName" from Vyuha!',
        subject: 'Vyuha Kram Diagram',
      );

    } catch (e) {
      print("Error exporting image: $e");
      _showCustomNotification("Error exporting image. Please try again.",
          isError: true);
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

  // --- POSITION & HIT TEST HELPERS ---

  Offset _getCanvasPosition(Offset globalPosition) {
    if (_canvasKey.currentContext == null) return Offset.zero;
    final RenderBox canvasBox =
        _canvasKey.currentContext!.findRenderObject() as RenderBox;
    final canvasOffset = canvasBox.localToGlobal(Offset.zero);
    final matrix = ctrl.transformationController.value;
    final invertedMatrix = Matrix4.inverted(matrix);
    return MatrixUtils.transformPoint(
        invertedMatrix, globalPosition - canvasOffset);
  }

  KramElementModel? _findNodeAtPosition(Offset canvasPos) {
    for (final el in ctrl.elements.reversed) {
      final elRect = Rect.fromLTWH(el.x, el.y, el.width, el.height);
      if (elRect.contains(canvasPos)) {
        return el;
      }
    }
    return null;
  }

  // --- GESTURE HANDLERS ---

  void _onCanvasPointerMove(Offset globalPosition) {
    final canvasPos = _getCanvasPosition(globalPosition);
    ctrl.updateCursor(canvasPos);
  }

  void _onCanvasTapUp(Offset globalPosition) {
    final canvasPos = _getCanvasPosition(globalPosition);
    String? type;
    String? text;

    switch (_currentTool) {
      case Tool.addProcess:
        type = 'process';
        text = 'Process';
        break;
      case Tool.addDecision:
        type = 'decision';
        text = 'Decision?';
        break;
      case Tool.addStartEnd:
        type = 'start';
        text = 'Start';
        break;
      case Tool.move:
      case Tool.connect:
      default:
        // Clear selection if tapping canvas in move/connect mode
        ctrl.clearSelection();
        break;
    }

    if (type != null && text != null) {
      // Center the new node on the tap position
      const double defaultWidth = 160.0;
      const double defaultHeight = 70.0;
      final centeredPos = Offset(
        canvasPos.dx - defaultWidth / 2,
        canvasPos.dy - defaultHeight / 2,
      );
      ctrl.addElement(text, type, centeredPos);

      // Revert to move tool after adding
      setState(() {
        _currentTool = Tool.move;
      });
    }
  }

  void _onCanvasPanStart(Offset globalPosition) {
    // This is for Marquee Selection
    if (_currentTool != Tool.move) return;
    setState(() {
      _marqueeStart = _getCanvasPosition(globalPosition);
      _marqueeRect = Rect.fromPoints(_marqueeStart!, _marqueeStart!);
    });
    ctrl.clearSelection();
  }

  void _onCanvasPanUpdate(Offset globalPosition) {
    if (_marqueeStart == null) return;
    setState(() {
      final canvasPos = _getCanvasPosition(globalPosition);
      _marqueeRect = Rect.fromPoints(_marqueeStart!, canvasPos);
    });
  }

  void _onCanvasPanEnd() {
    if (_marqueeRect != null) {
      ctrl.selectElementsInRect(_marqueeRect!);
    }
    setState(() {
      _marqueeStart = null;
      _marqueeRect = null;
    });
  }

  void _onElementTap(String elementId) {
    if (_currentTool == Tool.move) {
      // Handle selection
      if (ctrl.selectedElementIds.contains(elementId) &&
          ctrl.selectedElementIds.length == 1) {
        ctrl.clearSelection();
      } else {
        ctrl.selectElement(elementId);
      }
    }
  }

  void _onElementDoubleTap(String elementId) {
    _showEditDialog(elementId);
  }

  void _onElementLongPress(String elementId, Offset globalPosition) {
    // If not selected, select it
    if (!ctrl.selectedElementIds.contains(elementId)) {
      ctrl.selectElement(elementId);
    }
    _showContextMenu(globalPosition);
  }

  void _onElementPanStart(String elementId) {
    if (_currentTool != Tool.move) return;
    // If we drag an element that is not selected, select it and clear others.
    if (!ctrl.selectedElementIds.contains(elementId)) {
      ctrl.selectElement(elementId);
    }
    // Start multi-move, which works for 1 or N elements
    ctrl.startMultiMove();
  }

  void _onElementPanUpdate(Offset dragDelta) {
    if (_currentTool != Tool.move) return;
    // Update multi-move (applies to 1 or N elements)
    // We scale the delta by the current zoom level
    final scaledDelta = dragDelta / ctrl.currentScale.value;
    ctrl.updateMultiMove(scaledDelta);
  }

  void _onElementPanEnd() {
    if (_currentTool != Tool.move) return;
    // End multi-move
    ctrl.endMultiMove();
  }

  // --- CONNECTION GESTURE HANDLERS ---

  void _onConnectPanStart(
      String nodeId, AnchorSide anchor, Offset globalPosition) {
    if (_currentTool != Tool.connect) {
      // Allow connection by dragging from anchor even if not in connect mode
    }
    setState(() {
      _connectFromNodeId = nodeId;
      _connectFromAnchor = anchor;
      _connectLiveOffset = _getCanvasPosition(globalPosition);
    });
  }

  void _onConnectPanUpdate(Offset globalPosition) {
    if (_connectFromNodeId != null) {
      setState(() {
        _connectLiveOffset = _getCanvasPosition(globalPosition);
      });
    }
  }

  void _onConnectPanEnd(String? targetNodeId, AnchorSide? targetAnchor) {
    if (_connectFromNodeId != null &&
        _connectFromAnchor != null &&
        targetNodeId != null &&
        targetAnchor != null &&
        targetNodeId != _connectFromNodeId) {
      // Success! Create the edge.
      ctrl.addEdge(_connectFromNodeId!, _connectFromAnchor!, targetNodeId,
          targetAnchor);
    } else {
      // Missed, or dropped on self
      if (_connectFromNodeId != null) {
        _showCustomNotification("Connection cancelled", isError: true);
      }
    }

    // Reset connection state
    setState(() {
      _connectFromNodeId = null;
      _connectFromAnchor = null;
      _connectLiveOffset = null;
    });
  }

  // --- DIALOGS & MENUS ---

  void _showEditDialog(String elementId) {
    final el = ctrl.elements.firstWhereOrNull((e) => e.id == elementId);
    if (el == null) return;

    final txt = TextEditingController(text: el.text);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _isDarkMode ? Color(0xFF1A1A1A) : Colors.white,
        title: Text('Edit Element',
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        content: TextField(
          controller: txt,
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
          decoration: InputDecoration(
              hintText: 'Enter text...',
              hintStyle: TextStyle(
                  color: _isDarkMode ? Colors.white38 : Colors.black38)),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel',
                  style: TextStyle(
                      color: _isDarkMode ? Colors.white54 : Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF8D5F8C)),
            onPressed: () {
              final text = txt.text.trim();
              if (text.isNotEmpty && text != el.text) {
                ctrl.updateElementText(el.id, text);
              }
              Get.back();
            },
            child: Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(Offset globalPosition) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      color: _isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 30, 30),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
            value: 'edit',
            child: Text('Edit Text',
                style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black))),
        PopupMenuItem(
            value: 'delete',
            child: Text(
                ctrl.selectedElementIds.length > 1
                    ? 'Delete ${ctrl.selectedElementIds.length} Items'
                    : 'Delete',
                style: TextStyle(color: Colors.red.shade300))),
      ],
    ).then((value) {
      if (value == 'edit') {
        if (ctrl.selectedElementIds.isNotEmpty) {
          _showEditDialog(ctrl.selectedElementIds.first);
        }
      } else if (value == 'delete') {
        ctrl.deleteSelectedElements();
      }
    });
  }
}

// -------------------------------------------------------------------
// --- KRAM CANVAS WIDGET ---
// -------------------------------------------------------------------

class _KramCanvas extends StatelessWidget {
  final GlobalKey exportKey; 
  final KramController ctrl;
  final bool isDarkMode;
  // --- Callbacks ---
  final Function(Offset) onCanvasTapUp;
  final Function(Offset) onCanvasPanStart;
  final Function(Offset) onCanvasPanUpdate;
  final Function() onCanvasPanEnd;
  final Function(String) onElementPanStart;
  final Function(Offset) onElementPanUpdate;
  final Function() onElementPanEnd;
  final Function(String, AnchorSide, Offset) onConnectPanStart;
  final Function(Offset) onConnectPanUpdate;
  final Function(String?, AnchorSide?) onConnectPanEnd;
  final Function(String) onElementTap;
  final Function(String) onElementDoubleTap;
  final Function(String, Offset) onElementLongPress;
  final Function(Offset) onCanvasPointerMove;
  // --- Live State ---
  final Rect? marqueeRect;
  final String? connectFromNodeId;
  final AnchorSide? connectFromAnchor;
  final Offset? connectLiveOffset;

  _KramCanvas({
    Key? key,
    required this.exportKey,
    required this.ctrl,
    required this.isDarkMode,
    required this.onCanvasTapUp,
    required this.onCanvasPanStart,
    required this.onCanvasPanUpdate,
    required this.onCanvasPanEnd,
    required this.onElementPanStart,
    required this.onElementPanUpdate,
    required this.onElementPanEnd,
    required this.onConnectPanStart,
    required this.onConnectPanUpdate,
    required this.onConnectPanEnd,
    required this.onElementTap,
    required this.onElementDoubleTap,
    required this.onElementLongPress,
    required this.onCanvasPointerMove,
    this.marqueeRect,
    this.connectFromNodeId,
    this.connectFromAnchor,
    this.connectLiveOffset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This Listener is for the real-time cursor
    return Listener(
      onPointerMove: (details) => onCanvasPointerMove(details.position),
      onPointerHover: (details) => onCanvasPointerMove(details.position),
      child: InteractiveViewer(
        // REMOVED "key: super.key" HERE TO FIX DUPLICATE GLOBAL KEY ERROR
        transformationController: ctrl.transformationController,
        constrained: false,
        boundaryMargin: EdgeInsets.all(2000), // Infinite canvas
        minScale: 0.1,
        maxScale: 4.0,
        // Disable built-in pan/zoom when we are selecting
        panEnabled: marqueeRect == null,
        scaleEnabled: marqueeRect == null,
        // Use GestureDetector for canvas-level interactions
        child: GestureDetector(
          onTapUp: (details) => onCanvasTapUp(details.globalPosition),
          onPanStart: (details) => onCanvasPanStart(details.globalPosition),
          onPanUpdate: (details) => onCanvasPanUpdate(details.globalPosition),
          onPanEnd: (details) => onCanvasPanEnd(),
          child: Obx(() {
            final elements = ctrl.elements;
            final edges = ctrl.edges;
            final cursors = ctrl.activeCursors;

            // Calculate bounds for Stack
            double minX = 0, minY = 0, maxX = 2000, maxY = 1500;
            if (elements.isNotEmpty) {
              minX = elements.map((e) => e.x).reduce(min);
              minY = elements.map((e) => e.y).reduce(min);
              maxX = elements.map((e) => e.x + (e.width)).reduce(max) + 400;
              maxY = elements.map((e) => e.y + (e.height)).reduce(max) + 400;
            }

            // --- RepaintBoundary for PNG Export ---
            return RepaintBoundary(
              key: exportKey,
              child: Container(
                width: max(2000, maxX),
                height: max(1500, maxY),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Custom Painter for Edges
                    CustomPaint(
                      painter: _EdgePainter(
                        elements: elements,
                        edges: edges,
                        isDarkMode: isDarkMode,
                        connectFromNodeId: connectFromNodeId,
                        connectFromAnchor: connectFromAnchor,
                        connectLiveOffset: connectLiveOffset,
                      ),
                      child: Container(),
                    ),

                    // 2. Positioned Elements (Nodes)
                    ...elements.map((el) {
                      return Positioned(
                        left: el.x,
                        top: el.y,
                        child: _KramElementWidget(
                          ctrl: ctrl,
                          element: el,
                          isDarkMode: isDarkMode,
                          onElementPanStart: onElementPanStart,
                          onElementPanUpdate: onElementPanUpdate,
                          onElementPanEnd: onElementPanEnd,
                          onConnectPanStart: onConnectPanStart,
                          onConnectPanUpdate: onConnectPanUpdate,
                          onConnectPanEnd: onConnectPanEnd,
                          onElementTap: onElementTap,
                          onElementDoubleTap: onElementDoubleTap,
                          onElementLongPress: onElementLongPress,
                        ),
                      );
                    }).toList(),

                    // 3. Marquee Selection
                    if (marqueeRect != null)
                      Positioned(
                        left: marqueeRect!.left,
                        top: marqueeRect!.top,
                        width: marqueeRect!.width,
                        height: marqueeRect!.height,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF8D5F8C).withOpacity(0.1),
                            border: Border.all(
                                color: Color(0xFF8D5F8C), width: 1.5),
                          ),
                        ),
                      ),

                    // 4. Real-time Cursors
                    ...cursors.entries.map((entry) {
                      final data = entry.value;
                      return Positioned(
                        left: (data['x'] ?? 0.0).toDouble(),
                        top: (data['y'] ?? 0.0).toDouble(),
                        child: _CursorWidget(
                          name: data['name'] ?? 'Guest',
                          email: data['email'] ?? '',
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// --- KRAM ELEMENT WIDGET (The Node) ---
// -------------------------------------------------------------------

class _KramElementWidget extends StatelessWidget {
  final KramController ctrl;
  final KramElementModel element;
  final bool isDarkMode;
  // --- Callbacks ---
  final Function(String) onElementPanStart;
  final Function(Offset) onElementPanUpdate;
  final Function() onElementPanEnd;
  final Function(String, AnchorSide, Offset) onConnectPanStart;
  final Function(Offset) onConnectPanUpdate;
  final Function(String?, AnchorSide?) onConnectPanEnd;
  final Function(String) onElementTap;
  final Function(String) onElementDoubleTap;
  final Function(String, Offset) onElementLongPress;

  const _KramElementWidget({
    Key? key,
    required this.ctrl,
    required this.element,
    required this.isDarkMode,
    required this.onElementPanStart,
    required this.onElementPanUpdate,
    required this.onElementPanEnd,
    required this.onConnectPanStart,
    required this.onConnectPanUpdate,
    required this.onConnectPanEnd,
    required this.onElementTap,
    required this.onElementDoubleTap,
    required this.onElementLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = _getColor(element.type);
    final shape = _getShape(element.type, color);
    final double elWidth = element.width;
    final double elHeight = element.height;

    return Obx(() {
      final isSelected = ctrl.selectedElementIds.contains(element.id);

      final node = Container(
        width: elWidth,
        height: elHeight,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: ShapeDecoration(
          color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
          shape: shape,
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: Text(
            element.text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black, fontSize: 13),
          ),
        ),
      );

      return GestureDetector(
        onTap: () => onElementTap(element.id),
        onDoubleTap: () => onElementDoubleTap(element.id),
        onLongPressStart: (details) =>
            onElementLongPress(element.id, details.globalPosition),
        onPanStart: (details) => onElementPanStart(element.id),
        onPanUpdate: (details) => onElementPanUpdate(details.delta),
        onPanEnd: (details) => onElementPanEnd(), 
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            node,
            // --- SELECTION BORDER ---
            if (isSelected)
              Positioned(
                left: -3,
                top: -3,
                child: Container(
                  width: elWidth + 6,
                  height: elHeight + 6,
                  decoration: ShapeDecoration(
                    shape: _getShape(
                      element.type,
                      color, 
                      overrideSide:
                          BorderSide(color: Color(0xFF8D5F8C), width: 3),
                    ),
                  ),
                ),
              ),
            // --- CONNECTION ANCHORS ---
            _ConnectionAnchor(
              side: AnchorSide.top,
              elementWidth: elWidth,
              elementHeight: elHeight,
              onConnectPanStart: (pos) =>
                  onConnectPanStart(element.id, AnchorSide.top, pos),
              onConnectPanUpdate: onConnectPanUpdate,
              onConnectPanEnd: onConnectPanEnd,
              element: element,
              ctrl: ctrl,
            ),
            _ConnectionAnchor(
              side: AnchorSide.right,
              elementWidth: elWidth,
              elementHeight: elHeight,
              onConnectPanStart: (pos) =>
                  onConnectPanStart(element.id, AnchorSide.right, pos),
              onConnectPanUpdate: onConnectPanUpdate,
              onConnectPanEnd: onConnectPanEnd,
              element: element,
              ctrl: ctrl,
            ),
            _ConnectionAnchor(
              side: AnchorSide.bottom,
              elementWidth: elWidth,
              elementHeight: elHeight,
              onConnectPanStart: (pos) =>
                  onConnectPanStart(element.id, AnchorSide.bottom, pos),
              onConnectPanUpdate: onConnectPanUpdate,
              onConnectPanEnd: onConnectPanEnd,
              element: element,
              ctrl: ctrl,
            ),
            _ConnectionAnchor(
              side: AnchorSide.left,
              elementWidth: elWidth,
              elementHeight: elHeight,
              onConnectPanStart: (pos) =>
                  onConnectPanStart(element.id, AnchorSide.left, pos),
              onConnectPanUpdate: onConnectPanUpdate,
              onConnectPanEnd: onConnectPanEnd,
              element: element,
              ctrl: ctrl,
            ),
          ],
        ),
      );
    });
  }

  ShapeBorder _getShape(String type, Color borderColor,
      {BorderSide? overrideSide}) {
    final border = overrideSide ?? BorderSide(color: borderColor, width: 2);
    switch (type) {
      case 'start':
      case 'end':
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
          side: border,
        );
      case 'decision':
        return BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(10), 
          side: border,
        );
      case 'process':
      default:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: border,
        );
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'start':
        return Colors.green.shade400;
      case 'end':
        return Colors.red.shade400;
      case 'decision':
        return Color(0xFFF4991A);
      case 'process':
      default:
        return Color(0xFF8D5F8C);
    }
  }
}

// -------------------------------------------------------------------
// --- KRAM CONNECTION ANCHOR WIDGET ---
// -------------------------------------------------------------------
class _ConnectionAnchor extends StatelessWidget {
  final AnchorSide side;
  final double elementWidth;
  final double elementHeight;
  final Function(Offset) onConnectPanStart;
  final Function(Offset) onConnectPanUpdate;
  final Function(String?, AnchorSide?) onConnectPanEnd;
  final KramElementModel element;
  final KramController ctrl;

  const _ConnectionAnchor({
    Key? key,
    required this.side,
    required this.elementWidth,
    required this.elementHeight,
    required this.onConnectPanStart,
    required this.onConnectPanUpdate,
    required this.onConnectPanEnd,
    required this.element,
    required this.ctrl,
  }) : super(key: key);

  Offset _getPosition() {
    switch (side) {
      case AnchorSide.top:
        return Offset(elementWidth / 2, 0);
      case AnchorSide.right:
        return Offset(elementWidth, elementHeight / 2);
      case AnchorSide.bottom:
        return Offset(elementWidth / 2, elementHeight);
      case AnchorSide.left:
        return Offset(0, elementHeight / 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = _getPosition();
    const double anchorSize = 10.0;
    const double hitBoxSize = 24.0;

    return Positioned(
      left: pos.dx - hitBoxSize / 2,
      top: pos.dy - hitBoxSize / 2,
      width: hitBoxSize,
      height: hitBoxSize,
      child: GestureDetector(
        onPanStart: (details) => onConnectPanStart(details.globalPosition),
        onPanUpdate: (details) => onConnectPanUpdate(details.globalPosition),
        onPanEnd: (details) {
          // Find what's under the drop point
          final state = context.findAncestorStateOfType<_KramScreenState>()!;
          final dropPos = state._getCanvasPosition(details.globalPosition);
          final targetNode = state._findNodeAtPosition(dropPos);

          if (targetNode != null) {
            // Find the *closest* anchor on the target node
            final targetAnchor = _findClosestAnchor(targetNode, dropPos);
            onConnectPanEnd(targetNode.id, targetAnchor);
          } else {
            onConnectPanEnd(null, null);
          }
        },
        child: Center(
          child: Container(
            width: anchorSize,
            height: anchorSize,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFF8D5F8C), width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  AnchorSide _findClosestAnchor(KramElementModel target, Offset globalDropPos) {
    final double w = target.width;
    final double h = target.height;
    final Offset center = Offset(target.x + w / 2, target.y + h / 2);
    final Offset relativeDrop = globalDropPos - center;

    double angle = atan2(relativeDrop.dy, relativeDrop.dx);

    if (angle > -pi / 4 && angle <= pi / 4) return AnchorSide.right;
    if (angle > pi / 4 && angle <= 3 * pi / 4) return AnchorSide.bottom;
    if (angle > 3 * pi / 4 || angle <= -3 * pi / 4) return AnchorSide.left;
    return AnchorSide.top; 
  }
}

// -------------------------------------------------------------------
// --- KRAM EDGE PAINTER (Upgraded with Bézier Curves) ---
// -------------------------------------------------------------------
class _EdgePainter extends CustomPainter {
  final List<KramElementModel> elements;
  final List<KramEdgeModel> edges;
  final bool isDarkMode;
  // --- Live edge properties ---
  final String? connectFromNodeId;
  final AnchorSide? connectFromAnchor;
  final Offset? connectLiveOffset;

  _EdgePainter({
    required this.elements,
    required this.edges,
    required this.isDarkMode,
    this.connectFromNodeId,
    this.connectFromAnchor,
    this.connectLiveOffset,
  });

  // Helper to get the absolute canvas position of an anchor
  Offset _getAnchorOffset(KramElementModel el, AnchorSide anchor) {
    final double w = el.width;
    final double h = el.height;
    switch (anchor) {
      case AnchorSide.top:
        return Offset(el.x + w / 2, el.y);
      case AnchorSide.right:
        return Offset(el.x + w, el.y + h / 2);
      case AnchorSide.bottom:
        return Offset(el.x + w / 2, el.y + h);
      case AnchorSide.left:
        return Offset(el.x, el.y + h / 2);
    }
  }

  // --- Get control points for a Bézier curve ---
  Path _getBezierPath(
      Offset from, Offset to, AnchorSide fromAnchor, AnchorSide toAnchor) {
    final Path path = Path();
    path.moveTo(from.dx, from.dy);

    double dx = to.dx - from.dx;
    double dy = to.dy - from.dy;

    // Control point distance
    double cpDist = max(dx.abs(), dy.abs()) * 0.5;
    cpDist = max(cpDist, 50.0); // Minimum curve

    Offset cp1 = from;
    Offset cp2 = to;

    // Calculate control points based on anchor side
    switch (fromAnchor) {
      case AnchorSide.top:
        cp1 = from.translate(0, -cpDist);
        break;
      case AnchorSide.bottom:
        cp1 = from.translate(0, cpDist);
        break;
      case AnchorSide.left:
        cp1 = from.translate(-cpDist, 0);
        break;
      case AnchorSide.right:
        cp1 = from.translate(cpDist, 0);
        break;
    }

    switch (toAnchor) {
      case AnchorSide.top:
        cp2 = to.translate(0, -cpDist);
        break;
      case AnchorSide.bottom:
        cp2 = to.translate(0, cpDist);
        break;
      case AnchorSide.left:
        cp2 = to.translate(-cpDist, 0);
        break;
      case AnchorSide.right:
        cp2 = to.translate(cpDist, 0);
        break;
    }

    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.white38 : Colors.black38
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = isDarkMode ? Colors.white38 : Colors.black38
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    // Create a map for quick element lookup
    final elementMap = {for (var el in elements) el.id: el};

    // 1. Draw all saved edges
    for (final edge in edges) {
      final from = elementMap[edge.fromId];
      final to = elementMap[edge.toId];

      if (from != null && to != null) {
        final fromPoint = _getAnchorOffset(from, edge.fromAnchor);
        final toPoint = _getAnchorOffset(to, edge.toAnchor);

        final path =
            _getBezierPath(fromPoint, toPoint, edge.fromAnchor, edge.toAnchor);
        canvas.drawPath(path, paint);

        _drawArrowForPath(canvas, path, arrowPaint);
      }
    }

    // 2. Draw the live edge
    if (connectFromNodeId != null &&
        connectFromAnchor != null &&
        connectLiveOffset != null) {
      final from = elementMap[connectFromNodeId];
      if (from != null) {
        final fromPoint = _getAnchorOffset(from, connectFromAnchor!);

        final livePaint = Paint()
          ..color = Color(0xFF8D5F8C)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

        // For 'toAnchor', guess based on relative position
        final dx = connectLiveOffset!.dx - fromPoint.dx;
        final dy = connectLiveOffset!.dy - fromPoint.dy;
        AnchorSide pseudoToAnchor = AnchorSide.top;
        if (dx.abs() > dy.abs()) {
          pseudoToAnchor = dx > 0 ? AnchorSide.left : AnchorSide.right;
        } else {
          pseudoToAnchor = dy > 0 ? AnchorSide.top : AnchorSide.bottom;
        }

        final path = _getBezierPath(
            fromPoint, connectLiveOffset!, connectFromAnchor!, pseudoToAnchor);
        canvas.drawPath(path, livePaint);
      }
    }
  }

  void _drawArrowForPath(Canvas canvas, Path path, Paint paint) {
    // Use path metrics to find the tangent at the end
    final pathMetrics = path.computeMetrics().last;
    final pathLength = pathMetrics.length;
    if (pathLength < 10) return; // Path too short

    // Get position 5 units *before* the end so tip lands on anchor
    const arrowLength = 10.0;
    final tangent =
        pathMetrics.getTangentForOffset(pathLength - (arrowLength * 0.5));
    if (tangent == null) return;

    final to = tangent.position;
    final angle = tangent.angle;

    const double arrowAngle = 0.5; // Radians, ~28 degrees
    final arrowPath = Path();
    arrowPath.moveTo(to.dx, to.dy);
    arrowPath.lineTo(
      to.dx - arrowLength * cos(angle - arrowAngle),
      to.dy - arrowLength * sin(angle - arrowAngle),
    );
    arrowPath.lineTo(
      to.dx - arrowLength * cos(angle + arrowAngle),
      to.dy - arrowLength * sin(angle + arrowAngle),
    );
    arrowPath.close();
    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.edges != edges ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.connectFromNodeId != connectFromNodeId ||
        oldDelegate.connectFromAnchor != connectFromAnchor ||
        oldDelegate.connectLiveOffset != connectLiveOffset;
  }
}

// -------------------------------------------------------------------
// --- REAL-TIME CURSOR WIDGET ---
// -------------------------------------------------------------------
class _CursorWidget extends StatelessWidget {
  final String name;
  final String email;
  const _CursorWidget({Key? key, required this.name, required this.email})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Simple hash for color
    final color = Colors.primaries[email.hashCode % Colors.primaries.length];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mouse, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// --- UI Components (Toolbar, etc.) ---
// -------------------------------------------------------------------

class _TopLeftControls extends StatelessWidget {
  final KramController ctrl;
  final bool isDarkMode;

  const _TopLeftControls({required this.ctrl, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final panelBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final panelBorder = isDarkMode ? Color(0xFF333333) : Color(0xFFE0E0E0);
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: panelBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => Get.offAllNamed('/home'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/images/icon.png',
                      height: 28, width: 28, fit: BoxFit.cover),
                ),
              ),
            ),
            VerticalDivider(
                color: panelBorder, width: 24, indent: 4, endIndent: 4),
            Obx(() => Text(
                  ctrl.roomTitle.value,
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                )),
          ],
        ),
      ),
    );
  }
}

class _KramToolbar extends StatelessWidget {
  final Tool currentTool;
  final Function(Tool) onToolSelected;
  final bool isDarkMode;
  final KramController ctrl;
  final bool isFullscreen;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onExport; 

  const _KramToolbar({
    required this.currentTool,
    required this.onToolSelected,
    required this.isDarkMode,
    required this.ctrl,
    required this.isFullscreen,
    required this.onToggleTheme,
    required this.onToggleFullscreen,
    required this.onExport, 
  });

  @override
  Widget build(BuildContext context) {
    final panelBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final panelBorder = isDarkMode ? Color(0xFF333333) : Color(0xFFE0E0E0);
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: panelBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolButton(
                icon: Icons.mouse,
                label: 'Move',
                isSelected: currentTool == Tool.move,
                onTap: () => onToolSelected(Tool.move),
                isDarkMode: isDarkMode,
              ),
              _ToolButton(
                icon: Icons.rectangle_outlined,
                label: 'Process',
                isSelected: currentTool == Tool.addProcess,
                onTap: () => onToolSelected(Tool.addProcess),
                isDarkMode: isDarkMode,
              ),
              _ToolButton(
                icon: Icons.diamond_outlined,
                label: 'Decision',
                isSelected: currentTool == Tool.addDecision,
                onTap: () => onToolSelected(Tool.addDecision),
                isDarkMode: isDarkMode,
              ),
              _ToolButton(
                icon: Icons.circle_outlined,
                label: 'Start/End',
                isSelected: currentTool == Tool.addStartEnd,
                onTap: () => onToolSelected(Tool.addStartEnd),
                isDarkMode: isDarkMode,
              ),
              _ToolButton(
                  icon: Icons.share_outlined,
                  label: 'Connect',
                  isSelected: currentTool == Tool.connect,
                  onTap: () => onToolSelected(Tool.connect),
                  isDarkMode: isDarkMode),
              VerticalDivider(
                  color: panelBorder, width: 24, indent: 8, endIndent: 8),
              Obx(() => _ToolButton(
                    icon: Icons.undo,
                    label: 'Undo',
                    isSelected: false,
                    onTap: ctrl.canUndo.value ? () => ctrl.undo() : null,
                    isDarkMode: isDarkMode,
                  )),
              Obx(() => _ToolButton(
                    icon: Icons.redo,
                    label: 'Redo',
                    isSelected: false,
                    onTap: ctrl.canRedo.value ? () => ctrl.redo() : null,
                    isDarkMode: isDarkMode,
                  )),
              VerticalDivider(
                  color: panelBorder, width: 24, indent: 8, endIndent: 8),
              _ToolButton(
                icon: isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: isDarkMode ? 'Light Mode' : 'Dark Mode',
                isSelected: false,
                onTap: onToggleTheme,
                isDarkMode: isDarkMode,
              ),
              _ToolButton(
                icon: isFullscreen
                    ? Icons.fullscreen_exit_outlined
                    : Icons.fullscreen_outlined,
                label: isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                isSelected: false,
                onTap: onToggleFullscreen,
                isDarkMode: isDarkMode,
              ),
              _ToolButton(
                icon: Icons.download_outlined, 
                label: 'Export Image',
                isSelected: false,
                onTap: onExport,
                isDarkMode: isDarkMode,
              ),
              VerticalDivider(
                  color: panelBorder, width: 24, indent: 8, endIndent: 8),
              Obx(() => Text(
                    '${(ctrl.currentScale.value * 100).toInt()}%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: iconColor,
                        letterSpacing: 0.5),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDarkMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = isDarkMode
        ? Color(0xFF8D5F8C).withOpacity(0.3)
        : Color(0xFF8D5F8C).withOpacity(0.1);
    final selectedIcon = isDarkMode ? Colors.white : Color(0xFF8D5F8C);
    final unselectedIcon = isDarkMode ? Colors.white70 : Colors.black54;
    final disabledIcon = isDarkMode ? Colors.white24 : Colors.black12;

    return Tooltip(
      message: label,
      child: Material(
        color: isSelected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? disabledIcon
                  : (isSelected ? selectedIcon : unselectedIcon),
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

  const _NotificationWidget(
      {this.notificationMessage,
      required this.isNotificationError,
      required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100, // Above the toolbar
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position:
                Tween<Offset>(begin: Offset(0.0, 1.0), end: Offset(0.0, 0.0))
                    .animate(animation),
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
                          offset: Offset(0, 4))
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

class GridBackgroundPainter extends CustomPainter {
  final bool isDarkMode;
  GridBackgroundPainter({required this.isDarkMode});

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
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridBackgroundPainter oldDelegate) =>
      oldDelegate.isDarkMode != isDarkMode;
}