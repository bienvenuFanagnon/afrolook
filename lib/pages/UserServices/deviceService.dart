import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceInfoService {
  static String? _deviceId;

  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown_device';

      if (Platform.isAndroid) {
        // Utilisation de android_id pour un ID stable sur Android
        const androidId = AndroidId();
        deviceId = (await androidId.getId()) ?? 'unknown_android_id';

        // Fallback avec device_info_plus si nécessaire
        if (deviceId == 'unknown_android_id' || deviceId.isEmpty) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        }

      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // identifierForVendor persiste après réinstallation sur iOS
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_id';
      }

      _deviceId = deviceId;
      print("ID Appareil généré: $deviceId");
      return deviceId;
    } catch (e) {
      print("Erreur récupération ID appareil: $e");
      // Fallback basé sur le timestamp
      return 'error_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static Future<void> initializeDeviceId() async {
    _deviceId = await getDeviceId();
  }

  // Méthode pour vérifier si l'ID est valide (pas un fallback)
  static bool isDeviceIdValid(String deviceId) {
    return deviceId.isNotEmpty &&
        deviceId != 'unknown_device' &&
        deviceId != 'unknown_android_id' &&
        deviceId != 'unknown_ios_id' &&
        !deviceId.startsWith('error_device_');
  }
}