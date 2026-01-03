// lib/helpers/platform_helper_stub.dart
// This is the default implementation for mobile/desktop
import 'dart:typed_data';

class PlatformHelper {
  // Get initial fullscreen state
  bool get isFullscreen => false;
  String getCurrentUrl() => '';

  // ADDED: Clear URL query params (stub)
  void clearUrlHistory() {
    // Not supported
  }

  // Listen for fullscreen changes
  void listenForFullscreen(void Function(bool) listener) {
    // Not supported
  }

  // Toggle fullscreen
  void toggleFullScreen() {
    // Not supported
  }

  // Save image (mobile would need a package like gallery_saver)
  Future<void> saveImage(Uint8List bytes, String fileName) async {
    throw UnimplementedError(
        'Image saving is not supported on this platform.');
  }
}