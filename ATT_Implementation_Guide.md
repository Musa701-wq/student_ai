# App Tracking Transparency (ATT) Implementation Guide

Follow these 3 simple steps to integrate iOS App Tracking Transparency (ATT) into your new Flutter project.

### 1. Add the Dependency (pubspec.yaml)
Add the following package to your `pubspec.yaml` file under `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  app_tracking_transparency: ^2.0.6+1
```

*Run `flutter pub get` after adding this to update your dependencies.*

### 2. Update Info.plist (iOS Permission Description)
To show the permission dialog on iOS, you must add the usage description key. 
Open `ios/Runner/Info.plist` and add the following lines just inside the main `<dict>` tag:

```xml
    <!-- App Tracking Transparency (iOS 14+) -->
    <key>NSUserTrackingUsageDescription</key>
    <string>This identifier will be used to deliver personalized ads to you.</string>
```

### 3. Add Logic in main.dart
In your `lib/main.dart` file, you need to request the permission before initializing your ads or analytics SDKs.

**Step 3.1:** Add the necessary imports at the top of the file:
```dart
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
```

**Step 3.2:** Add this helper function outside your main function (or inside a suitable service class):
```dart
Future<void> requestATTIfNeeded() async {
  // Only request on iOS
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      // Show the dialog if the user hasn't been asked yet
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ATT request failed: $e');
    }
  }
}
```

**Step 3.3:** Update your `main()` method to call the helper function before ads initialization:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Call the ATT request BEFORE Firebase/Ads initialization
  await requestATTIfNeeded();
  
  // Initialize other services here...
  // await Firebase.initializeApp();
  // await AdService.init();

  runApp(const MyApp());
}
```
