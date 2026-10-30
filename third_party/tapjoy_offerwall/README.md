Tapjoy Flutter SDK
======================
Flutter plugin for Tapjoy Offerwall SDK which supports Android & iOS platforms.

You can find the end user integration document [here](https://dev.tapjoy.com/en/flutter-plugin/Quickstart/).

## Module Development
### Setup Environment
- Please check first [this Flutter setup document](https://docs.flutter.dev/get-started/install).

- Install IntelliJ IDE.
- From the macOS menu bar, go to IntelliJ > Settings.
- After The Preferences dialog opens, at the left, select Plugins.
- From the top of this panel, select Marketplace.
- Type flutter in the plugins search field.
- Select the Flutter plugin & Click Install.
- Click Restart when prompted.

### Dart shared code
`./lib/src/*.dart` is the shared code.

### iOS
The native iOS code responsible for bridging with Tapjoy SDK is located in: `./ios/Classes/*.swift`

### Android
The native Android code responsible for bridging with Tapjoy SDK is located in: `./android/src/main/kotlin/com/tapjoy/flutter/tapjoy/tapjoy_offerwall/*.kt`

## Integration Document
[Tapjoy Flutter SDK Integration Document](https://dev.tapjoy.com/en/flutter-plugin/Quickstart/).

## Resources
### Flutter Environment setup
https://docs.flutter.dev/get-started/install
