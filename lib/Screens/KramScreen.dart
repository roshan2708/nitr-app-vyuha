import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vyuha/controllers/KramController.dart';
import 'package:vyuha/controllers/VyuhaController.dart';
import 'package:vyuha/models/KramModels.dart';
import 'package:vyuha/models/NodeModel.dart';

class KramScreen extends StatefulWidget {
  final String roomId;
  KramScreen({Key? key, String? roomId})
      : roomId = roomId ?? Get.arguments as String? ?? '',
        super(key: key);

  @override
  State<KramScreen> createState() => _KramScreenState();
}

class _KramScreenState extends State<KramScreen> {
  int _selectedIndex = 0;
  bool _isDarkMode = Get.isDarkMode;

  @override
  void initState() {
    super.initState();
    // Initialize KramController if not present
    if (!Get.isRegistered<KramController>(tag: widget.roomId)) {
      Get.put(KramController(widget.roomId), tag: widget.roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely find the controllers
    final kramCtrl = Get.find<KramController>(tag: widget.roomId);
    final vyuhaCtrl = Get.find<VyuhaController>(tag: widget.roomId);
    
    // Layout Logic
    // ignore: unused_local_variable
    final screenWidth = MediaQuery.of(context).size.width;
    
    final bgColor = _isDarkMode ? Color(0xFF0D0D0D) : Color(0xFFF5F5F7);
    final sideBarColor = _isDarkMode ? Color(0xFF161616) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Kram", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: sideBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              setState(() => _isDarkMode = !_isDarkMode);
            },
          )
        ],
      ),
      body: Row(
        children: [
          // --- Sidebar ---
          LayoutBuilder(builder: (context, constraint) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraint.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    backgroundColor: sideBarColor,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.psychology),
                        selectedIcon: Icon(Icons.psychology_outlined),
                        label: Text('AI Explain'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.schema),
                        selectedIcon: Icon(Icons.schema_outlined),
                        label: Text('Flowchart'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.note_alt),
                        selectedIcon: Icon(Icons.note_alt_outlined),
                        label: Text('Notes'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.code),
                        label: Text('Github'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          VerticalDivider(thickness: 1, width: 1, color: Colors.grey.withOpacity(0.2)),
          
          // --- Content Area ---
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _AiExplainView(kramCtrl: kramCtrl, vyuhaCtrl: vyuhaCtrl, isDarkMode: _isDarkMode),
                _FlowchartView(ctrl: kramCtrl, isDarkMode: _isDarkMode),
                _NotesView(ctrl: kramCtrl, isDarkMode: _isDarkMode),
                _GithubPlaceholderView(isDarkMode: _isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// --- 1. AI Explain View ---
// ------------------------------------------------------------------

class _AiExplainView extends StatelessWidget {
  final KramController kramCtrl;
  final VyuhaController vyuhaCtrl;
  final bool isDarkMode;

  const _AiExplainView({
    required this.kramCtrl,
    required this.vyuhaCtrl,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textCol = isDarkMode ? Colors.white : Colors.black;
    final cardBg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("AI Explainer", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textCol)),
          SizedBox(height: 8),
          Text("Select a node from your Vyuha to get a detailed explanation.", style: TextStyle(color: textCol.withOpacity(0.7))),
          SizedBox(height: 24),
          
          // Dropdown to select Node
          Obx(() {
            // Explicitly read the nodes list length to register the listener
            // ignore: unused_local_variable
            final _ = vyuhaCtrl.nodes.length;
            
            final nodes = vyuhaCtrl.nodes;
            if (nodes.isEmpty) return Text("No nodes in Vyuha to explain.", style: TextStyle(color: textCol));
            
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Select a topic", style: TextStyle(color: textCol.withOpacity(0.5))),
                  value: kramCtrl.selectedNodeForExplanation.value.isEmpty ? null : kramCtrl.selectedNodeForExplanation.value,
                  dropdownColor: cardBg,
                  items: nodes.map((n) => DropdownMenuItem(
                    value: n.text,
                    child: Text(n.text.length > 50 ? '${n.text.substring(0,50)}...' : n.text, style: TextStyle(color: textCol)),
                    onTap: () => kramCtrl.selectedNodeForExplanation.value = n.text,
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                       kramCtrl.explainNodeText(val);
                    }
                  },
                ),
              ),
            );
          }),

          SizedBox(height: 30),
          
          // Result Area
          Expanded(
            child: Obx(() {
              if (kramCtrl.isExplaining.value) {
                return Center(child: CircularProgressIndicator(color: Color(0xFF6B7FFF)));
              }
              if (kramCtrl.aiExplanationResult.value.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Explanation will appear here", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              return Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Markdown(
                  data: kramCtrl.aiExplanationResult.value,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: TextStyle(color: textCol, fontSize: 16, height: 1.6),
                    h1: TextStyle(color: textCol, fontWeight: FontWeight.bold),
                    h2: TextStyle(color: textCol, fontWeight: FontWeight.bold),
                    strong: TextStyle(color: Color(0xFF6B7FFF), fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// --- 2. Flowchart View (FIXED) ---
// ------------------------------------------------------------------

class _FlowchartView extends StatefulWidget {
  final KramController ctrl;
  final bool isDarkMode;
  const _FlowchartView({required this.ctrl, required this.isDarkMode});

  @override
  State<_FlowchartView> createState() => _FlowchartViewState();
}

class _FlowchartViewState extends State<_FlowchartView> {
  String? _connectModeId; 

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: widget.isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
          child: Row(
            children: [
              Text("Toolbar:", style: TextStyle(color: Colors.grey, fontSize: 12)),
              SizedBox(width: 12),
              _toolButton(Icons.crop_square, "Rectangle", () => _addShape(FlowShapeType.rectangle)),
              _toolButton(Icons.circle_outlined, "Oval", () => _addShape(FlowShapeType.oval)),
              _toolButton(Icons.change_history, "Decision", () => _addShape(FlowShapeType.diamond)),
              Spacer(),
              if (_connectModeId != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text("Tap target node to connect", style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              return Stack(
                children: [
                  // 1. Background Grid
                  Positioned.fill(
                     child: CustomPaint(painter: _GridPainter(widget.isDarkMode)),
                  ),
                  
                  // 2. Connections Painter (FIXED OBX)
                  Obx(() {
                    // ✅ CRITICAL FIX: Explicitly access .length or .toList() to register GetX listener
                    // simply passing 'widget.ctrl.flowElements' to constructor is NOT enough.
                    final elements = widget.ctrl.flowElements.toList(); 
                    
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _ConnectionPainter(
                        elements, 
                        widget.isDarkMode ? Colors.white54 : Colors.black54
                      ),
                    );
                  }),

                  // 3. Draggable Nodes (FIXED OBX)
                  Obx(() {
                    // ✅ CRITICAL FIX: Explicitly read the list
                    final elements = widget.ctrl.flowElements.toList();
                    
                    return Stack(
                      children: elements.map((e) {
                        return Positioned(
                          left: e.x,
                          top: e.y,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              widget.ctrl.updateFlowElementPosition(
                                e.id, 
                                e.x + details.delta.dx, 
                                e.y + details.delta.dy
                              );
                            },
                            onTap: () {
                              if (_connectModeId != null) {
                                widget.ctrl.toggleConnection(_connectModeId!, e.id);
                                setState(() => _connectModeId = null);
                              }
                            },
                            child: _FlowElementWidget(
                              element: e, 
                              isDarkMode: widget.isDarkMode,
                              onEdit: () => _editElement(e),
                              onLink: () => setState(() => _connectModeId = e.id),
                              onDelete: () => widget.ctrl.deleteFlowElement(e.id),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              );
            }
          ),
        ),
      ],
    );
  }

  void _addShape(FlowShapeType type) {
    widget.ctrl.addFlowElement(type, 100, 100);
  }

  Widget _toolButton(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: widget.isDarkMode ? Colors.white : Colors.black87),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }

  void _editElement(KramFlowElement e) {
    final txt = TextEditingController(text: e.text);
    Get.defaultDialog(
      title: "Edit Text",
      backgroundColor: widget.isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
      titleStyle: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
      content: TextField(
        controller: txt,
        style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
        decoration: InputDecoration(hintText: "Enter text"),
      ),
      textConfirm: "Save",
      confirmTextColor: Colors.white,
      buttonColor: Color(0xFF6B7FFF),
      onConfirm: () {
        widget.ctrl.updateFlowElementText(e.id, txt.text);
        Get.back();
      },
    );
  }
}

class _FlowElementWidget extends StatelessWidget {
  final KramFlowElement element;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onLink;
  final VoidCallback onDelete;

  const _FlowElementWidget({
    required this.element,
    required this.isDarkMode,
    required this.onEdit,
    required this.onLink,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(0xFF6B7FFF);
    final textCol = isDarkMode ? Colors.white : Colors.black;
    final bgCol = isDarkMode ? Color(0xFF2A2A2A) : Colors.white;

    ShapeBorder shape;
    switch (element.type) {
      case FlowShapeType.oval:
        shape = StadiumBorder(side: BorderSide(color: color, width: 2));
        break;
      case FlowShapeType.diamond:
        shape = BeveledRectangleBorder(
            side: BorderSide(color: color, width: 2),
            borderRadius: BorderRadius.circular(20)); // Approx diamond
        break;
      default:
        shape = RoundedRectangleBorder(
            side: BorderSide(color: color, width: 2),
            borderRadius: BorderRadius.circular(8));
    }

    return Container(
      width: 120,
      height: 60,
      decoration: ShapeDecoration(color: bgCol, shape: shape),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                element.text,
                textAlign: TextAlign.center,
                style: TextStyle(color: textCol, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: PopupMenuButton(
              icon: Icon(Icons.more_vert, size: 14, color: Colors.grey),
              itemBuilder: (c) => [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'link', child: Text('Link')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'link') onLink();
                if (v == 'delete') onDelete();
              },
            ),
          )
        ],
      ),
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  final List<KramFlowElement> elements;
  final Color color;

  _ConnectionPainter(this.elements, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()..color = color..style = PaintingStyle.fill;

    // Map for fast lookup
    final map = {for (var e in elements) e.id: e};
    
    // Offset to center of a 120x60 node
    final centerOffset = Offset(60, 30);

    for (var from in elements) {
      final start = Offset(from.x, from.y) + centerOffset;
      for (var toId in from.connections) {
        final to = map[toId];
        if (to != null) {
          final end = Offset(to.x, to.y) + centerOffset;
          
          // Draw Line
          canvas.drawLine(start, end, paint);

          // Draw Arrowhead at 'end'
          _drawArrowHead(canvas, start, end, arrowPaint);
        }
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    var dir = (p2 - p1);
    var dist = dir.distance;
    if (dist == 0) return;
    dir = dir / dist; // normalize

    // Back off slightly from center so arrow isn't hidden by node
    var end = p2 - (dir * 30); 

    final path = Path();
    path.moveTo(end.dx, end.dy);
    // Left wing
    path.lineTo(end.dx - 6 * dir.dx - 4 * dir.dy, end.dy - 6 * dir.dy + 4 * dir.dx);
    // Right wing
    path.lineTo(end.dx - 6 * dir.dx + 4 * dir.dy, end.dy - 6 * dir.dy - 4 * dir.dx);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter old) => true;
}

// ------------------------------------------------------------------
// --- 3. Notes View (Collaborative Sticky Notes) ---
// ------------------------------------------------------------------

class _NotesView extends StatelessWidget {
  final KramController ctrl;
  final bool isDarkMode;

  const _NotesView({required this.ctrl, required this.isDarkMode});

  static const List<Color> noteColors = [
    Color(0xFFFFF9C4), // Yellow
    Color(0xFFE1BEE7), // Purple
    Color(0xFFC8E6C9), // Green
    Color(0xFFBBDEFB), // Blue
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTapDown: (details) {
              // Add note on double tap
              ctrl.addNote(details.localPosition.dx, details.localPosition.dy, 0);
            },
            child: Container(
              color: Colors.transparent, // Capture taps
              child: CustomPaint(painter: _GridPainter(isDarkMode)),
            ),
          ),
        ),
        
        // Notes Layer
        Obx(() {
          // ✅ CRITICAL FIX: Explicitly read the list to register listener
          final notes = ctrl.stickyNotes.toList(); 
          
          return Stack(
            children: notes.map((note) {
              return Positioned(
                left: note.x,
                top: note.y,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    ctrl.updateNotePosition(note.id, note.x + details.delta.dx, note.y + details.delta.dy);
                  },
                  child: _StickyNoteWidget(
                    note: note, 
                    color: noteColors[note.colorIndex % noteColors.length],
                    onDelete: () => ctrl.deleteNote(note.id),
                    onUpdate: (val) => ctrl.updateNoteContent(note.id, val),
                  ),
                ),
              );
            }).toList(),
          );
        }),

        // Hint
        Positioned(
          bottom: 20, 
          left: 20, 
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
            child: Text("Double tap anywhere to add a sticky note", style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        )
      ],
    );
  }
}

class _StickyNoteWidget extends StatefulWidget {
  final KramNote note;
  final Color color;
  final VoidCallback onDelete;
  final Function(String) onUpdate;

  const _StickyNoteWidget({required this.note, required this.color, required this.onDelete, required this.onUpdate});

  @override
  State<_StickyNoteWidget> createState() => _StickyNoteWidgetState();
}

class _StickyNoteWidgetState extends State<_StickyNoteWidget> {
  late TextEditingController _txt;

  @override
  void initState() {
    super.initState();
    _txt = TextEditingController(text: widget.note.content);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: widget.color,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2,2))],
        border: Border(top: BorderSide(color: Colors.black12, width: 20)), // Header bar
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 20,
            padding: EdgeInsets.symmetric(horizontal: 4),
            margin: EdgeInsets.only(top: 0), // Already accounted for by border
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.note.authorName, style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Icon(Icons.close, size: 14, color: Colors.black54),
                )
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _txt,
                maxLines: null,
                style: TextStyle(color: Colors.black87, fontSize: 14),
                decoration: InputDecoration(border: InputBorder.none),
                onChanged: widget.onUpdate,
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// --- 4. Github Placeholder ---
// ------------------------------------------------------------------

class _GithubPlaceholderView extends StatelessWidget {
  final bool isDarkMode;
  const _GithubPlaceholderView({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("Github Integration", style: TextStyle(fontSize: 20, color: isDarkMode ? Colors.white : Colors.black)),
          SizedBox(height: 8),
          Text("Repo linking coming soon.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// --- Common Painter ---
class _GridPainter extends CustomPainter {
  final bool isDarkMode;
  _GridPainter(this.isDarkMode);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}