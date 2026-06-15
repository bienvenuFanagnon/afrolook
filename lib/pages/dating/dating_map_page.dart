// lib/pages/dating/dating_map_page.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dating_data.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/authProvider.dart';
import 'dating_profile_detail_page.dart';

/// Page carte affichant les profils de rencontre géolocalisés.
/// Permet de parcourir une carte stylée et de toucher un profil pour voir son détail.
class DatingMapPage extends StatefulWidget {
  final List<DatingProfile> profiles;
  final double? myLatitude;
  final double? myLongitude;
  final String? subscriptionPlan;

  const DatingMapPage({
    Key? key,
    required this.profiles,
    this.myLatitude,
    this.myLongitude,
    this.subscriptionPlan,
  }) : super(key: key);

  @override
  State<DatingMapPage> createState() => _DatingMapPageState();
}

class _DatingMapPageState extends State<DatingMapPage> {
  final MapController _mapController = MapController();
  DatingProfile? _selectedProfile;

  int get _maxVisibleProfiles {
    switch (widget.subscriptionPlan) {
      case 'plus':
        return 200;
      case 'gold':
        return -1;
      default:
        return 10;
    }
  }

  List<DatingProfile> get _allLocatedProfiles => widget.profiles
      .where((p) => p.latitude != null && p.longitude != null)
      .toList();

  List<DatingProfile> get _locatedProfiles {
    final all = _allLocatedProfiles;
    if (_maxVisibleProfiles == -1 || all.length <= _maxVisibleProfiles) return all;
    return all.take(_maxVisibleProfiles).toList();
  }

  bool get _isLimitReached =>
      _maxVisibleProfiles != -1 && _allLocatedProfiles.length > _maxVisibleProfiles;

  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPrivacyNotice());
  }

  /// Affiche un message expliquant que la position des autres profils est
  /// volontairement floutée pour leur sécurité, dès la première visite de la
  /// carte puis au maximum une fois par mois.
  Future<void> _maybeShowPrivacyNotice() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('dating_map_privacy_notice_last_shown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const oneMonthMs = 30 * 24 * 60 * 60 * 1000;
    if (now - last < oneMonthMs) return;
    await prefs.setInt('dating_map_privacy_notice_last_shown', now);
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.datingMapPrivacyTitle),
        content: Text(t.datingMapPrivacyDesc),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: Text(t.datingMapPrivacyGotIt, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final located = _locatedProfiles;

    final LatLng center = (widget.myLatitude != null && widget.myLongitude != null)
        ? LatLng(widget.myLatitude!, widget.myLongitude!)
        : (located.isNotEmpty
            ? () {
                final fuzzed = located.first.fuzzedLocation!;
                return LatLng(fuzzed.lat, fuzzed.lng);
              }()
            : const LatLng(6.1319, 1.2228)); // Lomé, Togo par défaut

    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        title: Text(t.datingMapPageTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
              minZoom: 2,
              maxZoom: 18,
              onTap: (_, __) => setState(() => _selectedProfile = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.afrolook.app',
              ),
              if (widget.myLatitude != null && widget.myLongitude != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.myLatitude!, widget.myLongitude!),
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: located.map((profile) {
                  final isSelected = _selectedProfile?.id == profile.id;
                  final fuzzed = profile.fuzzedLocation!;
                  return Marker(
                    point: LatLng(fuzzed.lat, fuzzed.lng),
                    width: isSelected ? 76 : 60,
                    height: isSelected ? 96 : 76,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedProfile = profile),
                      child: _buildMarkerAvatar(profile, isSelected),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Boutons de zoom
          Positioned(
            right: 16,
            bottom: _selectedProfile != null ? 220 : 24,
            child: Column(
              children: [
                _zoomButton(Icons.add, () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                }),
                const SizedBox(height: 8),
                _zoomButton(Icons.remove, () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                }),
              ],
            ),
          ),
          // Carte de profil sélectionné
          if (_selectedProfile != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildSelectedProfileCard(_selectedProfile!),
            ),
          if (located.isEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  t.datingNoLocatedProfiles,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_isLimitReached && _selectedProfile == null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.datingMoreProfilesWithPlan,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.red.shade600, size: 20),
        ),
      ),
    );
  }

  Widget _buildMarkerAvatar(DatingProfile profile, bool isSelected) {
    final size = isSelected ? 56.0 : 44.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? Colors.red : Colors.white, width: isSelected ? 3 : 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            image: DecorationImage(
              image: NetworkImage(_cdnUrl(profile.imageUrl)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: isSelected ? Colors.red : Colors.white),
        ),
      ],
    );
  }

  Widget _buildSelectedProfileCard(DatingProfile profile) {
    final distance = profile.distanceFrom(widget.myLatitude, widget.myLongitude);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _cdnUrl(profile.imageUrl),
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.pseudo}, ${profile.age}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.of(context).textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          distance != null
                              ? '${profile.ville} • ${formatDistanceKm(distance)}'
                              : '${profile.ville}, ${profile.pays}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DatingProfileDetailPage(profile: profile)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(AppLocalizations.of(context).datingViewProfileButton, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit triangle sous l'avatar pour faire un marqueur en forme d'épingle.
class _PinTailPainter extends CustomPainter {
  final Color color;
  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
