import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vyuha/controllers/KramController.dart';
import 'package:vyuha/models/KramModels.dart';

class KramScreen extends StatefulWidget {
  final String roomId;
  final String nodeId;
  final String nodeText;

  // FIX: Constructor now accepts named parameters OR falls back to Get.arguments
  KramScreen({
    Key? key,
    String? roomId,
    String? nodeId,
    String? nodeText,
  })  : roomId = roomId ?? (Get.arguments as Map?)?['roomId'] ?? '',
        nodeId = nodeId ?? (Get.arguments as Map?)?['nodeId'] ?? '',
        nodeText = nodeText ?? (Get.arguments as Map?)?['nodeText'] ?? 'Unknown Topic',
        super(key: key);

  @override
  State<KramScreen> createState() => _KramScreenState();
}

class _KramScreenState extends State<KramScreen> {
  bool _isDarkMode = Get.isDarkMode;
  final TransformationController _transformCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    // Unique Tag per Node to allow multiple Kram sessions
    final tag = '${widget.roomId}_${widget.nodeId}';
    
    // Safety check: Don't initialize if IDs are missing
    if (widget.roomId.isEmpty || widget.nodeId.isEmpty) return;

    if (!Get.isRegistered<KramController>(tag: tag)) {
      Get.put(
        KramController(
            roomId: widget.roomId,
            nodeId: widget.nodeId,
            initialTopic: widget.nodeText),
        tag: tag,
      );
    }
    
    // Center the canvas initially
    _transformCtrl.value = Matrix4.identity()
      ..translate(-100.0, -50.0)
      ..scale(0.8);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomId.isEmpty || widget.nodeId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Error")),
        body: Center(child: Text("Invalid Room or Node ID")),
      );
    }

    final tag = '${widget.roomId}_${widget.nodeId}';
    final kramCtrl = Get.find<KramController>(tag: tag);

    final bgColor = _isDarkMode ? Color(0xFF121212) : Color(0xFFF8F9FA);
    final dotColor = _isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Infinite Canvas
          GestureDetector(
             onDoubleTapDown: (d) => kramCtrl.addNote(
               _transformCtrl.toScene(d.globalPosition).dx, 
               _transformCtrl.toScene(d.globalPosition).dy, 
               0
             ),
             child: InteractiveViewer(
              transformationController: _transformCtrl,
              boundaryMargin: EdgeInsets.all(2000), // Infinite feel
              minScale: 0.1,
              maxScale: 3.0,
              constrained: false, 
              child: SizedBox(
                width: 3000,
                height: 3000,
                child: Stack(
                  children: [
                    // Grid Background
                    Positioned.fill(
                      child: CustomPaint(painter: _DotGridPainter(dotColor)),
                    ),

                    // Connections
                    Obx(() => CustomPaint(
                      size: Size(3000, 3000),
                      painter: _ConnectionPainter(
                          kramCtrl.flowElements.toList(),
                          _isDarkMode ? Colors.white54 : Colors.black54),
                    )),

                    // Nodes
                    Obx(() => Stack(
                      children: kramCtrl.flowElements.map((e) {
                        return Positioned(
                          left: e.x,
                          top: e.y,
                          child: _DraggableFlowElement(
                            element: e,
                            ctrl: kramCtrl,
                            isDarkMode: _isDarkMode,
                          ),
                        );
                      }).toList(),
                    )),

                    // Notes
                    Obx(() => Stack(
                      children: kramCtrl.stickyNotes.map((n) {
                        return Positioned(
                          left: n.x,
                          top: n.y,
                          child: _DraggableNote(
                            note: n,
                            ctrl: kramCtrl,
                          ),
                        );
                      }).toList(),
                    )),
                  ],
                ),
              ),
            ),
          ),

          // 2. Header / Toolbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _KramToolbar(
              title: widget.nodeText,
              isDarkMode: _isDarkMode,
              onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
              ctrl: kramCtrl,
            ),
          ),

          // 3. Loading Indicator
          Obx(() {
            if (kramCtrl.isGenerating.value) {
              return Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF6B7FFF)),
                      SizedBox(height: 16),
                      Text("AI is brainstorming...", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
            }
            return SizedBox.shrink();
          }),
          
          // 4. Status Toast
          Obx(() {
            if (kramCtrl.statusMessage.isNotEmpty) {
               return Positioned(
                 bottom: 30,
                 left: 0, 
                 right: 0,
                 child: Center(
                   child: Container(
                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     decoration: BoxDecoration(
                       color: Colors.black87,
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Text(kramCtrl.statusMessage.value, style: TextStyle(color: Colors.white)),
                   ),
                 ),
               );
            }
            return SizedBox.shrink();
          })
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// --- Subcomponents ---
// ------------------------------------------------------------------

class _KramToolbar extends StatelessWidget {
  final String title;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final KramController ctrl;

  const _KramToolbar({
    required this.title,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final fg = isDarkMode ? Colors.white : Colors.black;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            BackButton(color: fg, onPressed: () => Get.back()),
            SizedBox(width: 8),
            Icon(Icons.hub_outlined, color: Color(0xFFF4991A)),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Kram Board", style: TextStyle(color: fg.withOpacity(0.5), fontSize: 10)),
                  Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            
            // Tools
            _ToolBtn(icon: Icons.auto_awesome, label: "AI Generate", color: Color(0xFF6B7FFF), onTap: ctrl.generateFlowchart),
            SizedBox(width: 8),
            _ToolBtn(icon: Icons.delete_outline, label: "Clear", color: Colors.redAccent, onTap: ctrl.clearCanvas),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode, color: fg),
              onPressed: onToggleTheme,
            )
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  
  const _ToolBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _DraggableFlowElement extends StatefulWidget {
  final KramFlowElement element;
  final KramController ctrl;
  final bool isDarkMode;

  const _DraggableFlowElement({required this.element, required this.ctrl, required this.isDarkMode});

  @override
  State<_DraggableFlowElement> createState() => _DraggableFlowElementState();
}

class _DraggableFlowElementState extends State<_DraggableFlowElement> {
  @override
  Widget build(BuildContext context) {
    final fg = widget.isDarkMode ? Colors.white : Colors.black;
    final bg = widget.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final border = Color(0xFF6B7FFF);

    ShapeBorder shape;
    switch (widget.element.type) {
      case FlowShapeType.oval:
        shape = StadiumBorder(side: BorderSide(color: border, width: 2));
        break;
      case FlowShapeType.diamond:
        shape = BeveledRectangleBorder(side: BorderSide(color: border, width: 2), borderRadius: BorderRadius.circular(15));
        break;
      default:
        shape = RoundedRectangleBorder(side: BorderSide(color: border, width: 2), borderRadius: BorderRadius.circular(8));
    }

    return GestureDetector(
      onPanUpdate: (details) {
         widget.ctrl.updateFlowElementPosition(
           widget.element.id, 
           widget.element.x + details.delta.dx, 
           widget.element.y + details.delta.dy
         );
      },
      child: Container(
        width: 140,
        height: 70,
        decoration: ShapeDecoration(color: bg, shape: shape, shadows: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))]),
        alignment: Alignment.center,
        padding: EdgeInsets.all(8),
        child: Text(
          widget.element.text,
          textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DraggableNote extends StatelessWidget {
  final KramNote note;
  final KramController ctrl;

  const _DraggableNote({required this.note, required this.ctrl});
  
  static const colors = [Color(0xFFFFF9C4), Color(0xFFE1BEE7), Color(0xFFC8E6C9), Color(0xFFBBDEFB)];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => ctrl.updateNotePosition(note.id, note.x + d.delta.dx, note.y + d.delta.dy),
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: colors[note.colorIndex % colors.length],
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2,2))],
        ),
        child: Column(
          children: [
             Container(
               height: 20, 
               color: Colors.black12,
               alignment: Alignment.centerRight,
               child: GestureDetector(
                 onTap: () => ctrl.deleteNote(note.id),
                 child: Icon(Icons.close, size: 16, color: Colors.black54),
               ),
             ),
             Expanded(
               child: Padding(
                 padding: EdgeInsets.all(8),
                 child: TextFormField(
                   initialValue: note.content,
                   maxLines: null,
                   decoration: InputDecoration(border: InputBorder.none),
                   style: TextStyle(fontSize: 14, color: Colors.black87),
                   onChanged: (v) => ctrl.updateNoteContent(note.id, v),
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ConnectionPainter extends CustomPainter {
  final List<KramFlowElement> elements;
  final Color color;
  _ConnectionPainter(this.elements, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    final map = {for (var e in elements) e.id: e};
    final centerOffset = Offset(70, 35); // Half of 140x70

    for (var from in elements) {
      final start = Offset(from.x, from.y) + centerOffset;
      for (var toId in from.connections) {
        final to = map[toId];
        if (to != null) {
          final end = Offset(to.x, to.y) + centerOffset;
          
          final path = Path();
          path.moveTo(start.dx, start.dy);
          final dx = (end.dx - start.dx).abs();
          path.cubicTo(
            start.dx + dx / 2, start.dy, 
            end.dx - dx / 2, end.dy, 
            end.dx, end.dy
          );
          canvas.drawPath(path, paint);
        }
      }
    }
  }
  @override
  bool shouldRepaint(covariant _ConnectionPainter old) => true;
}