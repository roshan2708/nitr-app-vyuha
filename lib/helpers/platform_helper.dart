// lib/helpers/platform_helper.dart
export 'platform_helper_stub.dart' // Default (mobile)
    if (dart.library.html) 'platform_helper_web.dart'; // Web