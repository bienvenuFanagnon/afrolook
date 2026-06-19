import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';

/// Paramètres de confidentialité de la présence — réservés aux membres Premium.
///
/// Stockés dans `Users/{uid}.privacySettings` (Map Firestore).
/// Lecture/écriture directe sans passer par le modèle UserData.
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  late AppColors _colors;
  late UserAuthProvider _authProvider;

  bool _ghostMode         = false;
  bool _hideLastSeen      = false;
  bool _hideReadReceipts  = false;
  bool _biometricLock     = false;
  bool _saving            = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = _authProvider.loginUserData.id!;
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      final privacy = (doc.data()?['privacySettings'] as Map<String, dynamic>?) ?? {};
      if (!mounted) return;
      setState(() {
        _ghostMode        = privacy['ghostMode']        == true;
        _hideLastSeen     = privacy['hideLastSeen']     == true;
        _hideReadReceipts = privacy['hideReadReceipts'] == true;
        _biometricLock    = privacy['biometricLock']    == true;
      });
    } catch (e) {
      debugPrint('⚠️ PrivacySettingsPage._loadSettings: $e');
    }
  }

  Future<void> _saveField(String field, bool value) async {
    if (_saving) return;
    setState(() => _saving = true);

    final uid = _authProvider.loginUserData.id!;
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'privacySettings.$field': value,
      });
    } catch (e) {
      debugPrint('⚠️ PrivacySettingsPage._saveField ($field): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur lors de la sauvegarde', textAlign: TextAlign.center),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final isPremium = _authProvider.loginUserData.abonnement?.estPremium == true;

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Confidentialité',
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bannière Premium si non Premium
          if (!isPremium) _buildPremiumBanner(),
          const SizedBox(height: 16),

          // Section : Présence
          _buildSectionHeader('Présence en ligne'),
          const SizedBox(height: 8),

          _buildToggleTile(
            icon: Icons.visibility_off_rounded,
            title: 'Mode fantôme',
            subtitle: 'Apparaître hors ligne pour tout le monde',
            value: _ghostMode,
            locked: !isPremium,
            onChanged: (v) {
              setState(() => _ghostMode = v);
              _saveField('ghostMode', v);
            },
          ),
          const SizedBox(height: 8),
          _buildToggleTile(
            icon: Icons.access_time_rounded,
            title: 'Masquer la dernière connexion',
            subtitle: 'Afficher "—" à la place de l\'heure',
            value: _hideLastSeen,
            locked: !isPremium,
            onChanged: (v) {
              setState(() => _hideLastSeen = v);
              _saveField('hideLastSeen', v);
            },
          ),
          const SizedBox(height: 24),

          // Section : Messages (coming soon)
          _buildSectionHeader('Messages'),
          const SizedBox(height: 8),
          _buildToggleTile(
            icon: Icons.done_all_rounded,
            title: 'Masquer les accusés de lecture',
            subtitle: 'Les doubles coches resteront grises',
            value: _hideReadReceipts,
            locked: !isPremium,
            onChanged: (v) {
              setState(() => _hideReadReceipts = v);
              _saveField('hideReadReceipts', v);
            },
          ),
          const SizedBox(height: 24),

          // Section : Sécurité
          _buildSectionHeader('Sécurité'),
          const SizedBox(height: 8),
          _buildToggleTile(
            icon: Icons.fingerprint_rounded,
            title: 'Verrouillage biométrique',
            subtitle: 'Déverrouiller la messagerie par empreinte ou Face ID',
            value: _biometricLock,
            locked: !isPremium,
            onChanged: (v) => _toggleBiometricLock(v),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometricLock(bool enable) async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isAvailable = await _localAuth.isDeviceSupported();
    if (!canCheck || !isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Biométrie non disponible sur cet appareil', textAlign: TextAlign.center),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: enable
            ? 'Confirmez votre identité pour activer le verrouillage'
            : 'Confirmez votre identité pour désactiver le verrouillage',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (!authenticated) return;
      setState(() => _biometricLock = enable);
      await _saveField('biometricLock', enable);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Authentification échouée', textAlign: TextAlign.center),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildPremiumBanner() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/abonnement'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a0a2a), Color(0xFF2a1a3a)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDB813).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Fonctionnalités Premium',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Passez à Premium pour contrôler votre visibilité.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFDB813), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: _colors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool locked,
    required ValueChanged<bool> onChanged,
    bool comingSoon = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _colors.border.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: locked
                ? _colors.surfaceVariant
                : _colors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: locked ? _colors.textSecondary : _colors.primary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: locked ? _colors.textSecondary : _colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (locked && !comingSoon) ...[
              const SizedBox(width: 6),
              const Text('👑', style: TextStyle(fontSize: 13)),
            ],
            if (comingSoon) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Bientôt',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: _colors.textSecondary, fontSize: 12),
        ),
        trailing: locked
            ? Icon(Icons.lock_rounded, color: _colors.textSecondary, size: 18)
            : Switch(
                value: value,
                onChanged: _saving ? null : onChanged,
                activeColor: _colors.primary,
              ),
        onTap: locked && !comingSoon
            ? () => Navigator.pushNamed(context, '/abonnement')
            : null,
      ),
    );
  }
}
