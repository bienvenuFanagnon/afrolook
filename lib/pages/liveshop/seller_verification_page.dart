import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/argent_upload.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';

/// Vérification d'identité du vendeur : les 3 niveaux, le plafond mensuel tant que l'identité n'est pas vérifiée, et le dépôt de la demande
/// (pièce d'identité + selfie). Les photos sont envoyées en privé, vues par l'équipe seulement et effacées dès la décision.
class SellerVerificationPage extends StatefulWidget {
  const SellerVerificationPage({super.key});

  @override
  State<SellerVerificationPage> createState() => _SellerVerificationPageState();
}

class _SellerVerificationPageState extends State<SellerVerificationPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _country = TextEditingController(text: 'TG');
  Map<String, dynamic>? _s;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  String _idType = 'id_card';
  Uint8List? _front;
  Uint8List? _back;
  Uint8List? _selfie;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await LiveShopApi.verification();
      if (mounted) setState(() { _s = r; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = LiveShopApi.message(e); });
    }
  }

  Future<Uint8List?> _pick({required bool selfie}) async {
    ImageSource? src = selfie ? ImageSource.camera : null;
    src ??= await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_rounded), title: Text(tr('Prendre une photo')), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_rounded), title: Text(tr('Choisir dans la galerie')), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return null;
    final f = await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 80, preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear);
    return f == null ? null : await f.readAsBytes();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final country = _country.text.trim().toUpperCase();
    if (name.length < 3 || country.length != 2) {
      setState(() => _error = tr('Écris ton nom complet tel qu\'il apparaît sur ta pièce, et le pays en 2 lettres.'));
      return;
    }
    if (_front == null || _selfie == null || (_idType != 'passport' && _back == null)) {
      setState(() => _error = tr('Ajoute toutes les photos demandées.'));
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      final front = await ArgentUpload.bytes(_front!, contentType: 'image/jpeg', private: true);
      final back = _back == null || _idType == 'passport' ? null : await ArgentUpload.bytes(_back!, contentType: 'image/jpeg', private: true);
      final selfie = await ArgentUpload.bytes(_selfie!, contentType: 'image/jpeg', private: true);
      await LiveShopApi.submitVerification(fullName: name, idType: _idType, country: country, front: front, back: back, selfie: selfie);
      if (!mounted) return;
      setState(() { _front = null; _back = null; _selfie = null; });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = LiveShopApi.message(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _level(AppColors c, int n, String title, String text, bool reached) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(reached ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: reached ? c.success : c.textSecondary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Niveau {n} · {t}', {'n': '$n', 't': title}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
              Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)),
            ]),
          ),
        ]),
      );

  Widget _photo(AppColors c, String label, Uint8List? bytes, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: _sending ? null : onTap,
          child: Container(
            height: 96,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: bytes == null ? c.divider : c.success, width: bytes == null ? 1 : 2)),
            child: bytes != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_rounded, color: c.textSecondary),
                    const SizedBox(height: 4),
                    Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                  ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = _s;
    final level = (s?['level'] as num?)?.toInt() ?? 1;
    final req = s?['request'] is Map ? Map<String, dynamic>.from(s!['request'] as Map) : null;
    final pending = req?['status'] == 'pending';
    final cap = (s?['cap_xof'] as num?)?.toInt();
    final sold = (s?['sold_month_xof'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Vérifier mon identité'))),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _level(c, 1, tr('Inscrit'), tr('Tu peux vendre, dans la limite mensuelle ci-dessous.'), level >= 1),
                  _level(c, 2, tr('Identité vérifiée'), tr('Notre équipe a contrôlé ta pièce d\'identité : plus de limite de ventes, et une coche visible par les acheteurs.'), level >= 2),
                  _level(c, 3, tr('Vendeur fiable'), tr('Identité vérifiée + au moins 5 commandes terminées, 4,5 étoiles et peu d\'annulations : badge « fiable » et commission réduite.'), level >= 3),
                ]),
              ),
              if (cap != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Ventes de ce mois : {a} F sur {b} F autorisés', {'a': _n.format(sold), 'b': _n.format(cap)}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: cap == 0 ? 1 : (sold / cap).clamp(0, 1).toDouble(), minHeight: 8, color: sold >= cap ? c.danger : c.primary, backgroundColor: c.divider)),
                    const SizedBox(height: 6),
                    Text(tr('Au-delà, les acheteurs ne peuvent plus commander chez toi tant que ton identité n\'est pas vérifiée.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              if (level >= 2)
                Text(tr('Ton identité est vérifiée. Merci !'), style: TextStyle(color: c.success, fontWeight: FontWeight.w800))
              else if (pending)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
                  child: Text(tr('Ta demande est en cours d\'examen par notre équipe. Tu seras prévenu dès qu\'elle sera traitée.'), style: TextStyle(color: c.textPrimary, height: 1.4)),
                )
              else ...[
                if (req != null && req['status'] == 'rejected')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(tr('Ta dernière demande a été refusée : {m}. Tu peux en déposer une nouvelle.', {'m': '${req['reason'] ?? ''}'}), style: TextStyle(color: c.danger, fontWeight: FontWeight.w700, height: 1.35)),
                  ),
                Text(tr('Dépose ta demande'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(tr('Tes photos sont privées : seule notre équipe les voit, et elles sont effacées dès la décision.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)),
                const SizedBox(height: 12),
                TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: tr('Nom complet (comme sur ta pièce)'), border: const OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _idType,
                      decoration: InputDecoration(labelText: tr('Pièce'), border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: 'id_card', child: Text(tr('Carte d\'identité'))),
                        DropdownMenuItem(value: 'passport', child: Text(tr('Passeport'))),
                        DropdownMenuItem(value: 'driver_license', child: Text(tr('Permis de conduire'))),
                      ],
                      onChanged: _sending ? null : (v) => setState(() { _idType = v ?? 'id_card'; if (_idType == 'passport') _back = null; }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(width: 90, child: TextField(controller: _country, maxLength: 2, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: tr('Pays'), counterText: '', border: const OutlineInputBorder()))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _photo(c, tr('Recto'), _front, () async { final b = await _pick(selfie: false); if (b != null) setState(() => _front = b); }),
                  if (_idType != 'passport') _photo(c, tr('Verso'), _back, () async { final b = await _pick(selfie: false); if (b != null) setState(() => _back = b); }),
                  _photo(c, tr('Selfie'), _selfie, () async { final b = await _pick(selfie: true); if (b != null) setState(() => _selfie = b); }),
                ]),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w700))),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.verified_user_rounded),
                    label: Text(_sending ? tr('Envoi en cours…') : tr('Envoyer ma demande')),
                  ),
                ),
              ],
              if (_error != null && (level >= 2 || pending)) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: c.danger))),
            ]),
    );
  }
}
