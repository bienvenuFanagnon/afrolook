// services/ad_carousel_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class AdCarouselService {
  static const String _currentIndexKey = 'ad_carousel_current_index';
  static const String _adsListKey = 'ad_carousel_ads_ids';
  static AdCarouselService? _instance;
  static AdCarouselService get instance => _instance ??= AdCarouselService._();

  AdCarouselService._();

  Future<int> getCurrentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentIndexKey) ?? 0;
  }

  Future<void> setCurrentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentIndexKey, index);
  }

  Future<void> saveAdsList(List<String> adIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_adsListKey, adIds);
  }

  Future<List<String>> getAdsList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_adsListKey) ?? [];
  }
}