# ayet_sdk_v2

Flutter plugin for the ayetstudios SDK. Monetize your app and reward users with in-app currency through offers and surveys.

## Getting Started

Before integrating, make sure you have:

1. Created an [ayetstudios account](https://www.ayetstudios.com)
2. Added a Placement (Android or iOS)
3. Added an AdSlot

See [Dashboard Setup](https://docs.ayetstudios.com/v/product-docs/dashboard-setup) for details.

> **Important:** Your placement package name must match your app's package name, or the SDK won't initialize.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  ayet_sdk_v2: ^1.0.3
```

### Android Setup

Add the internet permission to your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application>
        ...
    </application>
</manifest>
```

### iOS Setup

Enable Swift Package Manager:

```bash
flutter config --enable-swift-package-manager
```

Then run `flutter build ios` to fetch dependencies.

## Initialize the SDK

```dart
import 'package:ayet_sdk_v2/ayet_sdk_v2.dart';

final sdk = AyetSdkV2();

// Initialize with your placement ID and user identifier
await sdk.init(
  placementId: YOUR_PLACEMENT_ID,
  externalIdentifier: 'USER_EXTERNAL_IDENTIFIER',
);
```

The `externalIdentifier` is your user's ID, accessible in conversion callbacks via `{external_identifier}`. The `placementId` is found in your dashboard.

## Show the Offerwall

```dart
await sdk.showOfferwall('YOUR_OFFERWALL_ADSLOT_NAME');
```

The adslot name is found by clicking the adslot in your dashboard. Only available for Offerwall adslots.

## Show the Surveywall

```dart
await sdk.showSurveywall('YOUR_SURVEYWALL_ADSLOT_NAME');
```

Only available for Surveywall adslots.

## Show Reward Status

The Reward Status page shows clicked/in-progress offers and allows users to submit support tickets.

```dart
await sdk.showRewardStatus();
```

## Fetch Offers

Get all offers in JSON format (Offerwall API adslots only):

```dart
final offersJson = await sdk.getOffers('YOUR_OFFERWALL_API_ADSLOT_NAME');
```

## Set Custom Parameters

Set up to 5 custom parameters for callbacks:

```dart
await sdk.setTrackingCustom1('custom1');
await sdk.setTrackingCustom2('custom2');
await sdk.setTrackingCustom3('custom3');
await sdk.setTrackingCustom4('custom4');
await sdk.setTrackingCustom5('custom5');
```

Custom parameters must also be added to your callback URL to receive them in S2S callbacks.

## Set Age and Gender

Optionally pass user demographics to improve offer matching:

```dart
await sdk.setAge(25);
await sdk.setGender(AyetGender.male);
await sdk.setGender(AyetGender.female);
```

## Documentation

See [docs.ayetstudios.com](https://docs.ayetstudios.com/v) for full documentation including callback setup and testing.
