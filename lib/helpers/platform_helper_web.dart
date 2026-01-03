// lib/helpers/platform_helper_web.dart
// This is the web-only implementation
import 'dart:typed_data';
import 'dart:html' as html;

class PlatformHelper {
  // Get initial fullscreen state
  bool get isFullscreen => html.document.fullscreenElement != null;
  String getCurrentUrl() => html.window.location.href;

  // ADDED: Clear URL query params (web implementation)
  void clearUrlHistory() {
    html.window.history.pushState(null, '', '/');
  }

  // Listen for fullscreen changes
  void listenForFullscreen(void Function(bool) listener) {
    html.document.onFullscreenChange.listen((event) {
      listener(isFullscreen);
    });
  }

  // Toggle fullscreen
  void toggleFullScreen() {
    if (isFullscreen) {
      html.document.exitFullscreen();
    } else {
      html.document.documentElement?.requestFullscreen();
    }
  }

  // Save image
  Future<void> saveImage(Uint8List bytes, String fileName) async {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}