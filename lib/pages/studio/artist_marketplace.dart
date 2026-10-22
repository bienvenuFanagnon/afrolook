// lib/pages/studio/artist_marketplace.dart
//
// Sons d'artistes : un artiste dépose un son (gratuit ou payant), l'administrateur l'écoute et le valide,
// puis il est proposé dans le Studio (montages « prêts à poster ») et dans le fil.
//
// Sécurité :
//  - l'original est déposé dans Storage `artist_sound_uploads/{uid}/…`, illisible depuis un téléphone ;
//  - tout le monde n'entend qu'un extrait public de 30 s (`previewUrl`), fabriqué par le serveur ;
//  - le serveur compare chaque dépôt aux sons déjà en ligne (même fichier, même morceau ré-encodé ou recadré) ;
//  - les paiements (utilisation dans le Studio) sont faits par la Cloud Function renderStudioMontage, jamais par le téléphone.
//
// Structure Firestore :
//   artist_sounds/{soundId}
//     userId, userPseudo, userImageUrl, title, genre, description, coverImageUrl, audioPath (original, privé)
//     pricing: 'free' | 'paid' ; rightsCertified
//     status: 'pending_review' | 'validated' | 'refused' | 'suspended'
//     (serveur) previewUrl, durationMs, audioSha256, duplicates[], processed, reportCount
//     usageCount, totalEarningsCoins, createdAt, validatedAt

import 'package:afrotok/services/read_meter.dart';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../postDetails.dart';
import '../post_video_format_tel_details.dart';
import '../userPosts/userPostForm.dart';
import '../../services/offline_music_service.dart';
import 'artist_sound_common.dart';
import 'montage/montage_catalog.dart';
import 'montage/montage_editor_page.dart';
import 'montage/montage_gallery_page.dart';
import 'montage/montage_music.dart';
import '../../ads/music_ads.dart';
import '../../utils/media_cdn.dart';
import 'sound_countries.dart';
import 'studio_models.dart';
import '../music/music_page.dart';
import '../../services/music_queue.dart';
import '../../widgets/music/music_overlay.dart';
import '../../widgets/music/streams_text.dart';
import '../../widgets/music/music_like.dart';
import '../../widgets/music/vinyl.dart';
import '../../services/stream_counts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../coins/coin_recharge_screen.dart';

export 'artist_sound_common.dart' show ArtistSoundPricing;

// ─── Modèle ──────────────────────────────────────────────────────────────────

class ArtistSound {
  final String id;
  final String userId;
  final String userPseudo;
  final String userImageUrl;
  final String title;
  final String? genre;
  final String? description;
  final String? audioPath;
  final String? previewUrl;
  final String pricing; // 'free' | 'paid'
  final String? coverImageUrl;
  final int durationMs;
  final double? fileSizeMb;
  final String status; // 'pending_review' | 'validated' | 'refused' | 'suspended'
  final String? refusalReason;
  final int usageCount;
  final int totalEarningsCoins;
  final int reportCount;
  final int postCount;
  final int useCoins; // prix d'utilisation dans le Studio (2 à 20), 0 = prix par défaut
  final int saleCoins; // prix de vente du titre complet (50 à 500), 0 = pas en vente
  final int saleCount;
  final int previewSec; // durée de l'extrait gratuit (selon la durée du titre ; 30 pour les anciens sons)
  final int streamCount; // écoutes comptées (30 s), comme les « streams » d'une plateforme de musique
  final int likeCount; // j'aime (un par personne, compté par le serveur)
  final int saleEarnings; // pièces gagnées sur les ventes du titre
  final int useEarnings; // pièces gagnées quand le son est utilisé dans un post
  final Object? processed; // true | 'error' | null (analyse du serveur)
  final List<Map<String, dynamic>> duplicates;
  final List<String> availableCountries; // pays où le titre est proposé ('ALL' = tous ; vide = ancien titre, pour tous)
  final Timestamp createdAt;
  final Timestamp? validatedAt;

  const ArtistSound({
    required this.id,
    required this.userId,
    required this.userPseudo,
    required this.userImageUrl,
    required this.title,
    this.genre,
    this.description,
    this.audioPath,
    this.previewUrl,
    this.pricing = 'paid',
    this.coverImageUrl,
    required this.durationMs,
    this.fileSizeMb,
    required this.status,
    this.refusalReason,
    required this.usageCount,
    required this.totalEarningsCoins,
    this.reportCount = 0,
    this.postCount = 0,
    this.useCoins = 0,
    this.saleCoins = 0,
    this.saleCount = 0,
    this.previewSec = 30,
    this.streamCount = 0,
    this.likeCount = 0,
    this.saleEarnings = 0,
    this.useEarnings = 0,
    this.processed,
    this.duplicates = const [],
    this.availableCountries = const [],
    required this.createdAt,
    this.validatedAt,
  });

  bool get isFree => pricing == 'free';

  /// Prix d'utilisation dans le Studio (ce que paie la personne).
  int get unitPrice => useCoins >= 2 && useCoins <= 20 ? useCoins : ArtistSoundPricing.price;

  /// Ce que touche l'artiste à chaque utilisation : 60 %.
  int get unitShare => (unitPrice * 60) ~/ 100;

  bool get forSale => !isFree && saleCoins >= 50;

  /// Ce que touche l'artiste sur une vente : 60 %.
  int get saleShare => (saleCoins * 60) ~/ 100;

  factory ArtistSound.fromMap(Map<String, dynamic> map, String id) {
    return ArtistSound(
      id: id,
      userId: map['userId'] ?? '',
      userPseudo: map['userPseudo'] ?? '',
      userImageUrl: MediaCdn.url(map['userImageUrl'] as String?),
      title: map['title'] ?? '',
      genre: map['genre'],
      description: map['description'],
      audioPath: map['audioPath'],
      // anciens sons : pas d'extrait, on garde le lien d'origine pour l'écoute
      previewUrl: (map['previewUrl'] ?? map['audioUrl']) == null ? null : MediaCdn.url((map['previewUrl'] ?? map['audioUrl']) as String),
      pricing: map['pricing'] == 'free' ? 'free' : 'paid',
      coverImageUrl: map['coverImageUrl'] == null ? null : MediaCdn.url(map['coverImageUrl'] as String),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      fileSizeMb: (map['fileSizeMb'] as num?)?.toDouble(),
      status: map['status'] ?? 'pending_review',
      refusalReason: map['refusalReason'],
      usageCount: (map['usageCount'] as num?)?.toInt() ?? 0,
      totalEarningsCoins: (map['totalEarningsCoins'] as num?)?.toInt() ?? 0,
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
      postCount: (map['postCount'] as num?)?.toInt() ?? 0,
      useCoins: (map['useCoins'] as num?)?.toInt() ?? 0,
      saleCoins: (map['saleCoins'] as num?)?.toInt() ?? 0,
      saleCount: (map['saleCount'] as num?)?.toInt() ?? 0,
      previewSec: ((map['previewSec'] as num?)?.toInt() ?? 30).clamp(5, 60),
      streamCount: (map['streamCount'] as num?)?.toInt() ?? 0,
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
      saleEarnings: (map['saleEarnings'] as num?)?.toInt() ?? 0,
      useEarnings: (map['useEarnings'] as num?)?.toInt() ?? 0,
      processed: map['processed'],
      duplicates: [for (final d in (map['duplicates'] as List? ?? const [])) Map<String, dynamic>.from(d as Map)],
      availableCountries: [for (final x in (map['availableCountries'] as List? ?? const [])) '$x'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      validatedAt: map['validatedAt'],
    );
  }
}

String _fmtDuration(int ms) {
  if (ms <= 0) return '';
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

Widget _pricingBadge(ArtistSound s, AppColors c) {
  final free = s.isFree;
  final color = free ? const Color(0xFF2ECC71) : const Color(0xFFFFB400);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
    child: Text(free ? 'Gratuit' : '🪙 ${s.unitPrice}', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
  );
}

Widget _cover(ArtistSound s, double size, AppColors c, {double radius = 10}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: s.coverImageUrl != null
        ? CachedNetworkImage(imageUrl: s.coverImageUrl!, width: size, height: size, fit: BoxFit.cover)
        : Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Icon(Icons.music_note_rounded, color: Colors.white, size: size * .5),
          ),
  );
}

// ─── Page de dépôt ───────────────────────────────────────────────────────────

class ArtistSoundSubmitPage extends StatefulWidget {
  const ArtistSoundSubmitPage({Key? key}) : super(key: key);

  @override
  State<ArtistSoundSubmitPage> createState() => _ArtistSoundSubmitPageState();
}

class _ArtistSoundSubmitPageState extends State<ArtistSoundSubmitPage> {
  File? _audioFile;
  File? _coverFile;
  final _titleCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _rights = false;
  String _pricing = 'paid';
  int _useCoins = 5;
  bool _sell = false;
  int _saleCoins = 100;
  double _progress = 0;
  List<String> _countries = [];

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    final home = SoundCountries.homeOf(Provider.of<UserAuthProvider>(context, listen: false).loginUserData);
    _countries = home != null ? [home] : ['ALL'];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _genreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final f = File(result.files.first.path!);
    final sizeMb = (await f.stat()).size / (1024 * 1024);
    if (sizeMb > 50) {
      _snack('Le fichier ne doit pas dépasser 50 Mo.');
      return;
    }
    setState(() => _audioFile = f);
  }

  Future<void> _pickCover() async {
    final xf = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (xf != null) setState(() => _coverFile = File(xf.path));
  }

  bool get _isValid => _audioFile != null && _titleCtrl.text.trim().isNotEmpty && _rights;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() {
      _isSubmitting = true;
      _progress = 0;
    });

    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final storage = FirebaseStorage.instance;

    try {
      final uid = auth.loginUserData.id!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ext = _audioFile!.path.contains('.') ? _audioFile!.path.split('.').last.toLowerCase() : 'mp3';
      // Original : dossier privé (illisible depuis un téléphone) ; le serveur fabrique l'extrait public
      final audioPath = 'artist_sound_uploads/$uid/$ts.$ext';
      final audioTask = storage.ref(audioPath).putFile(_audioFile!, SettableMetadata(contentType: 'audio/${ext == 'mp3' ? 'mpeg' : ext}'));
      audioTask.snapshotEvents.listen((s) {
        if (mounted && s.totalBytes > 0) setState(() => _progress = s.bytesTransferred / s.totalBytes * 0.85);
      });
      await audioTask;

      String? coverUrl;
      if (_coverFile != null) {
        final coverTask = storage.ref('artist_sound_covers/$uid/$ts.jpg').putFile(_coverFile!);
        await coverTask;
        coverUrl = await coverTask.snapshot.ref.getDownloadURL();
        if (mounted) setState(() => _progress = 0.95);
      }

      final sizeMb = (await _audioFile!.stat()).size / (1024 * 1024);
      await FirebaseFirestore.instance.collection('artist_sounds').add({
        'userId': uid,
        'userPseudo': auth.loginUserData.pseudo ?? '',
        'userImageUrl': auth.loginUserData.imageUrl ?? '',
        'title': _titleCtrl.text.trim(),
        if (_genreCtrl.text.trim().isNotEmpty) 'genre': _genreCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'audioPath': audioPath,
        if (coverUrl != null) 'coverImageUrl': coverUrl,
        'pricing': _pricing,
        if (_pricing == 'paid') 'useCoins': _useCoins,
        'saleCoins': _pricing == 'paid' && _sell ? _saleCoins : 0,
        'availableCountries': _countries,
        'fileSizeMb': sizeMb,
        'status': 'pending_review',
        'usageCount': 0,
        'totalEarningsCoins': 0,
        'rightsCertified': true,
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            final c = AppColors.of(ctx);
            return AlertDialog(
              backgroundColor: c.surface,
              title: Text('Son envoyé ✅', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
              content: Text(
                'Notre système vérifie ton fichier (qualité, doublons) puis l’équipe écoute ton son avant de le valider (48 h maximum). '
                'Tu suis son état dans « Mes sons ».',
                style: TextStyle(color: c.textSecondary, height: 1.4),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            );
          },
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _snack('Envoi impossible : $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text('Proposer un son', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          if (!_isSubmitting)
            TextButton(
              onPressed: _isValid ? _submit : null,
              child: Text('Envoyer', style: TextStyle(color: _isValid ? c.primary : c.textSecondary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _isSubmitting
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(value: _progress == 0 ? null : _progress, color: c.primary),
                const SizedBox(height: 12),
                Text('${(_progress * 100).toStringAsFixed(0)} %', style: TextStyle(color: c.textSecondary)),
              ]),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: _pickAudio,
                  child: _buildPickButton(
                    icon: _audioFile != null ? Icons.check_circle : Icons.audio_file,
                    label: _audioFile != null ? _audioFile!.path.split('/').last : 'Choisir le fichier audio (MP3, M4A, WAV · max 50 Mo)',
                    active: _audioFile != null,
                    c: c,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickCover,
                  child: _buildPickButton(
                    icon: _coverFile != null ? Icons.check_circle : Icons.add_photo_alternate,
                    label: _coverFile != null ? 'Pochette sélectionnée ✓' : 'Ajouter une pochette (facultatif)',
                    active: _coverFile != null,
                    c: c,
                  ),
                ),
                const SizedBox(height: 20),
                _buildField(c, _titleCtrl, 'Titre du son *', maxLength: 60),
                const SizedBox(height: 12),
                _buildField(c, _genreCtrl, 'Genre (Afrobeat, Coupé-décalé, Amapiano…)', maxLength: 30),
                const SizedBox(height: 12),
                _buildField(c, _descCtrl, 'Description (facultatif)', maxLines: 3, maxLength: 200),
                const SizedBox(height: 18),
                Text('UTILISATION DANS LE STUDIO', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                _pricingOption(c, 'paid', '🪙 Payant',
                    'Tu fixes tes prix. Tu touches 60 % de chaque utilisation et de chaque vente, en pièces gagnées convertibles en argent.'),
                if (_pricing == 'paid') ...[
                  const SizedBox(height: 10),
                  _priceBox(
                    c,
                    title: 'Prix d’utilisation dans le Studio',
                    value: _useCoins,
                    min: 2,
                    max: 20,
                    step: 1,
                    onChanged: (v) => setState(() => _useCoins = v),
                    hint: 'Tu gagnes ${(_useCoins * 60) ~/ 100} pièces (≈ ${ArtistSoundPricing.fcfaOf((_useCoins * 60) ~/ 100)}) à chaque utilisation.',
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sell,
                    onChanged: (v) => setState(() => _sell = v),
                    activeThumbColor: c.primary,
                    title: Text('Vendre aussi le titre complet', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text('Les gens l’achètent pour l’écouter en entier dans leur bibliothèque, sans pouvoir l’exporter.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  ),
                  if (_sell)
                    _priceBox(
                      c,
                      title: 'Prix de vente du titre',
                      value: _saleCoins,
                      min: 50,
                      max: 500,
                      step: 10,
                      onChanged: (v) => setState(() => _saleCoins = v),
                      hint: 'Tu gagnes ${(_saleCoins * 60) ~/ 100} pièces (≈ ${ArtistSoundPricing.fcfaOf((_saleCoins * 60) ~/ 100)}) à chaque vente.',
                    ),
                ],
                const SizedBox(height: 8),
                _pricingOption(c, 'free', '🎁 Gratuit', 'Tout le monde peut l’écouter en entier et l’utiliser sans payer. Tu ne gagnes pas de pièces, mais ton nom circule et ton son se fait connaître.'),
                const SizedBox(height: 14),
                _countryCard(c),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: _rights,
                  onChanged: (v) => setState(() => _rights = v == true),
                  activeColor: c.primary,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Je certifie être l\'auteur de ce son ou en détenir tous les droits, et j\'autorise Afrolook à le proposer dans le Studio. '
                    'Je sais qu\'un son copié sera supprimé et mon compte peut être sanctionné.',
                    style: TextStyle(color: c.textPrimary, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ton fichier original reste privé : les autres n’entendent qu’un court extrait (jusqu’à 30 secondes, selon la durée du titre). '
                  'Notre système repère les doublons et l’équipe écoute ton son avant de le valider (48 h maximum).',
                  style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
                ),
              ]),
            ),
    );
  }

  Widget _countryCard(AppColors c) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final r = await SoundCountries.pick(context, initial: _countries);
        if (r != null && mounted) setState(() => _countries = r);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Row(children: [
          Icon(Icons.public_rounded, color: c.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pays où ton titre est proposé', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 3),
              Text(SoundCountries.summary(_countries), style: TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Gratuit : 1 pays · Premium : 20 · Gold : tous. Aucune pièce en plus.', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textSecondary),
        ]),
      ),
    );
  }

  /// Réglage d'un prix : − / + autour de la valeur (bornes imposées aussi par les règles du serveur).
  Widget _priceBox(AppColors c, {required String title, required int value, required int min, required int max, required int step, required ValueChanged<int> onChanged, required String hint}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
        Row(children: [
          IconButton(onPressed: value > min ? () => onChanged((value - step).clamp(min, max)) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
          Expanded(child: Center(child: Text('🪙 $value', style: TextStyle(color: c.primary, fontSize: 24, fontWeight: FontWeight.w900)))),
          IconButton(onPressed: value < max ? () => onChanged((value + step).clamp(min, max)) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
        ]),
        Text('$min à $max pièces · $hint', style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
      ]),
    );
  }

  Widget _pricingOption(AppColors c, String value, String title, String text) {
    final on = _pricing == value;
    return InkWell(
      onTap: () => setState(() => _pricing = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? c.primary.withValues(alpha: .1) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? c.primary : c.border, width: on ? 1.6 : 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? c.primary : c.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 3),
              Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildPickButton({required IconData icon, required String label, required bool active, required AppColors c}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? c.primary : c.border)),
      child: Row(children: [
        Icon(icon, color: active ? c.primary : c.textSecondary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: active ? c.primary : c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _buildField(AppColors c, TextEditingController ctrl, String hint, {int? maxLines, int? maxLength}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines ?? 1,
        maxLength: maxLength,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: c.textPrimary, fontSize: 13),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: c.textSecondary), border: InputBorder.none, counterText: ''),
      ),
    );
  }
}

// ─── Widget du fil : sons des artistes (sans pseudo, avec lecteur) ───────────

class ArtistSoundsFeedWidget extends StatelessWidget {
  const ArtistSoundsFeedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artist_sounds')
          .where('status', isEqualTo: 'validated')
          .orderBy('validatedAt', descending: true)
          .limit(40)
          .snapshotsM('artist_marketplace.dart:588'),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = SoundCountries.forViewer<ArtistSound>(
          [for (final d in snap.data!.docs) ArtistSound.fromMap(d.data() as Map<String, dynamic>, d.id)],
          countries: (s) => s.availableCountries,
          owner: (s) => s.userId,
          viewerCountry: SoundCountries.viewerCountry(context),
        );
        void openMine() => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyArtistSoundsPage()));
        if (docs.isEmpty) {
          // Aucun son encore validé : on invite les artistes à déposer le leur
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: InkWell(
              onTap: openMine,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)])),
                child: const Row(children: [
                  Text('🎤', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Expanded(child: Text('Tu es artiste ? Propose ton son : il peut être utilisé dans le Studio.', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700))),
                  Icon(Icons.chevron_right_rounded, color: Colors.white),
                ]),
              ),
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(children: [
              Expanded(child: Text('🎵 Musiques', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary))),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPage())),
                child: Text('Tout voir', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ]),
          ),
          SizedBox(
            height: 124,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SoundCard(sound: docs[i], colors: c),
            ),
          ),
        ]);
      },
    );
  }
}

class _SoundCard extends StatelessWidget {
  final ArtistSound sound;
  final AppColors colors;
  const _SoundCard({required this.sound, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: sound))),
      child: Container(
        width: 104,
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.border)),
        child: Column(children: [
          SizedBox(
            height: 70,
            width: 104,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(fit: StackFit.expand, children: [
                FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: _cover(sound, 104, colors, radius: 0)),
                const ColoredBox(color: Colors.black26),
                // Lecteur : joue l'extrait sans quitter le fil
                Center(child: SoundPlayButton(soundKey: 'feed_${sound.id}', url: sound.previewUrl, size: 34, color: Colors.white)),
                Positioned(top: 5, right: 5, child: _pricingBadge(sound, colors)),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(sound.title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// « Créer un post avec ce son » : modèles du Studio avec le son déjà choisi (payant : prix et solde annoncés), puis page de publication.
Future<void> startPostWithSound(BuildContext context, ArtistSound s) => startPostWithMusic(context, MontageMusic.artist(s));

/// Même chemin pour une musique gratuite d'Afrolook ou un son d'artiste.
///
/// [ownVideo] : « Ma vidéo avec ce son » — directement la vidéo de la personne et la musique, sans modèle ni habillage ;
/// le son d'origine de la vidéo est coupé (seule la musique est jouée), la personne peut le garder dans l'éditeur.
Future<void> startPostWithMusic(BuildContext context, MontageMusic music, {bool ownVideo = false}) async {
  // Le Studio joue sa propre musique : le lecteur flottant se met en pause et se masque, puis reprend au retour
  final token = Object();
  MusicQueue.suspend(token);
  MusicOverlay.add(1);
  try {
    if (!context.mounted) return;
    final r = await Navigator.push<StudioResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ownVideo ? MontageEditorPage(template: kPlainTemplate, presetMusic: music) : MontageGalleryPage(presetMusic: music),
      ),
    );
    if (r == null || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => UserPostForm(initialStudio: r)));
  } finally {
    MusicOverlay.add(-1);
    MusicQueue.release(token);
  }
}

/// Ouvre la page d'un son à partir de son identifiant (puce « Musique : titre » sous un post).
Future<void> openArtistSoundById(BuildContext context, String soundId) async {
  try {
    final d = await FirebaseFirestore.instance.collection('artist_sounds').doc(soundId).getM('artist_marketplace.dart:718');
    if (!context.mounted) return;
    if (!d.exists || d.data()!['status'] != 'validated') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce son n’est plus disponible.')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: ArtistSound.fromMap(d.data()!, d.id))));
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chargement impossible. Vérifie ta connexion.')));
  }
}

/// Crédit automatique sous un post fait avec le son d'un artiste : « ♪ titre » (mène à la page du titre) et le bouton
/// « Utiliser · 🪙 5 » pour créer son propre post avec ce son.
class PostSoundCredit extends StatefulWidget {
  const PostSoundCredit({super.key, required this.soundId, required this.title, this.dark = false});
  final String soundId;
  final String title;

  /// Sur une vidéo plein écran : fond sombre translucide et texte blanc.
  final bool dark;

  static final Map<String, Future<ArtistSound?>> _cache = {};

  static Future<ArtistSound?> _load(String id) => _cache[id] ??= FirebaseFirestore.instance.collection('artist_sounds').doc(id).getM('artist_marketplace.dart:742').then((d) {
        if (!d.exists || d.data()!['status'] != 'validated') return null;
        return ArtistSound.fromMap(d.data()!, d.id);
      }).catchError((_) {
        _cache.remove(id);
        return null as ArtistSound?;
      });

  @override
  State<PostSoundCredit> createState() => _PostSoundCreditState();
}

class _PostSoundCreditState extends State<PostSoundCredit> {
  ArtistSound? _sound;

  @override
  void initState() {
    super.initState();
    PostSoundCredit._load(widget.soundId).then((s) {
      if (mounted && s != null) setState(() => _sound = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = _sound;
    final t = s == null ? null : MusicTrack.fromSound(s);
    final title = widget.title.isEmpty ? 'voir le titre' : widget.title;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(children: [
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => s != null ? Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: s))) : openArtistSoundById(context, widget.soundId),
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 4, 9, 4),
              decoration: BoxDecoration(color: widget.dark ? const Color(0x73000000) : c.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(99), border: Border.all(color: c.primary.withValues(alpha: .35))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (t != null) TrackDisc(track: t, size: 20, glow: false) else Icon(Icons.music_note_rounded, size: 18, color: c.primary),
                const SizedBox(width: 5),
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.dark ? Colors.white : c.primary, fontSize: 12, fontWeight: FontWeight.w800))),
                if (t != null) ...[
                  const SizedBox(width: 6),
                  StreamsText(track: t, color: widget.dark ? Colors.white70 : c.primary, fontSize: 10.5),
                  const SizedBox(width: 4),
                  MusicLikeButton(track: t, color: widget.dark ? Colors.white70 : c.primary, fontSize: 10.5),
                ],
                Icon(Icons.chevron_right_rounded, size: 15, color: widget.dark ? Colors.white : c.primary),
              ]),
            ),
          ),
        ),
        if (s != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => startPostWithSound(context, s),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.videocam_rounded, size: 14, color: c.onAccent),
                const SizedBox(width: 4),
                Text(s.isFree ? 'Utiliser' : 'Utiliser · 🪙 ${s.unitPrice}', style: TextStyle(color: c.onAccent, fontSize: 10.5, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Page détail d'un son (extrait gratuit) ──────────────────────────────────

class ArtistSoundDetailPage extends StatefulWidget {
  final ArtistSound sound;

  /// Aperçu sans Firebase (captures d'écran et tests).
  @visibleForTesting
  final bool preview;
  const ArtistSoundDetailPage({Key? key, required this.sound, this.preview = false}) : super(key: key);

  @override
  State<ArtistSoundDetailPage> createState() => _ArtistSoundDetailPageState();
}

class _ArtistSoundDetailPageState extends State<ArtistSoundDetailPage> {
  bool _owned = false;
  bool _buying = false;
  bool _loadingAd = false;
  bool _adGranted = false; // écoute complète ouverte une fois par une pub récompensée

  bool get _own => !widget.preview && widget.sound.userId == FirebaseAuth.instance.currentUser?.uid;

  /// Écoute en entier : titre gratuit, acheté, ou à soi. Sinon, extrait de 30 s.
  bool get _full => widget.sound.isFree || _own || _owned || _adGranted;

  MusicTrack get _track => MusicTrack.fromSound(widget.sound, owned: _owned);

  @override
  void initState() {
    super.initState();
    MusicQueue.start();
    if (widget.preview) return;
    OfflineMusic.refresh();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && !_own) {
      FirebaseFirestore.instance.collection('MusicLibrary').doc('${uid}_${widget.sound.id}').getM('artist_marketplace.dart:853').then((d) {
        if (mounted && d.exists) setState(() => _owned = true);
      }).catchError((_) {});
    }
  }

  // La musique continue quand on quitte la page (lecteur flottant) : rien n'est coupé ici.

  double? _dl; // avancement du téléchargement (null = pas en cours)

  Future<void> _download() async {
    setState(() => _dl = 0);
    final r = await OfflineMusic.download(widget.sound.id, onProgress: (v) {
      if (mounted) setState(() => _dl = v);
    });
    if (!mounted) return;
    setState(() => _dl = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.ok ? 'Titre disponible hors ligne dans Afrolook ✅' : (r.message ?? 'Téléchargement impossible.'))));
  }

  Future<void> _listenWithAd() async {
    setState(() => _loadingAd = true);
    final r = await MusicAds.listenWithAd(widget.sound.id, userId: FirebaseAuth.instance.currentUser?.uid ?? '');
    if (!mounted) return;
    setState(() => _loadingAd = false);
    if (r.outcome != MusicAdOutcome.ok || r.url == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(MusicAds.message(r.outcome))));
      return;
    }
    setState(() => _adGranted = true);
    await MusicQueue.playGranted(_track, r.url!);
  }

  Future<void> _buy() async {
    setState(() => _buying = true);
    final ok = await buyTrack(context, widget.sound);
    if (!mounted) return;
    setState(() {
      _buying = false;
      if (ok) _owned = true;
    });
    if (ok) await MusicQueue.playTrack(_track, interstitial: false); // le titre complet démarre tout de suite
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = widget.sound;
    final canBuy = s.forSale && !_own && !_owned;
    return HideMusicOverlay(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          actions: [
            if (!_own)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: c.textPrimary),
                color: c.surface,
                onSelected: (_) => reportArtistSound(context, s.id, s.title),
                itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('🚩 Signaler ce son'))],
              ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
          // Disque + anneau de progression + bras de lecture
          Center(
            child: SizedBox(
              width: 260,
              height: 222,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Align(alignment: const Alignment(0, .35), child: ProgressRing(size: 196, color: c.primary, endedColor: c.warning, stroke: 3.5, child: TrackDisc(track: _track, size: 172))),
                Positioned(
                  right: 6,
                  top: 0,
                  child: ValueListenableBuilder<String?>(valueListenable: SoundPreview.playing, builder: (_, now, __) => Tonearm(height: 112, playing: now == _track.key)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(s.title, textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('par @${s.userPseudo}${s.genre != null && s.genre!.isNotEmpty ? ' · ${s.genre}' : ''}', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [StreamsText(track: _track, color: c.textSecondary, fontSize: 12.5, weight: FontWeight.w700), const SizedBox(width: 14), MusicLikeButton(track: _track, color: c.textSecondary, fontSize: 12.5, weight: FontWeight.w700)])),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            _pricingBadge(s, c),
            if (_owned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: c.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
                child: Text('✓ Dans ta bibliothèque', style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: 16),
          _playerCard(c, s),
          const SizedBox(height: 6),
          MusicControls(size: 1.15, track: _track),
          const SizedBox(height: 8),
          // Les deux actions : utiliser dans un post, acheter pour écouter en entier
          Row(children: [
            Expanded(child: _actionBtn(c, grad: true, icon: Icons.videocam_rounded, title: 'Créer un post', sub: s.isFree ? 'Gratuit' : '${s.unitPrice} 🪙', onTap: () => startPostWithSound(context, s))),
            if (canBuy) ...[
              const SizedBox(width: 10),
              Expanded(child: _actionBtn(c, icon: Icons.library_add_rounded, title: 'Acheter', sub: '${s.saleCoins} 🪙', onTap: _buying ? null : _buy, busy: _buying)),
            ],
          ]),
          if (canBuy) ...[
            const SizedBox(height: 10),
            Text('L’artiste touche ${s.saleShare} pièces sur ton achat. Le titre reste dans ta bibliothèque, lisible dans Afrolook.', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
          ],
          if (!widget.preview && !s.isFree && !_own && !_owned && !_adGranted && MusicAds.canOfferRewarded(Provider.of<UserAuthProvider>(context, listen: false).loginUserData))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: _loadingAd ? null : _listenWithAd,
                icon: _loadingAd ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)) : Icon(Icons.ondemand_video_rounded, color: c.primary, size: 19),
                label: Text('Écouter en entier avec une pub (une fois)', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ),
          if (!widget.preview && _full && OfflineMusic.supported)
            ValueListenableBuilder<Set<String>>(
              valueListenable: OfflineMusic.ids,
              builder: (_, ids, __) {
                final has = ids.contains(s.id);
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _dl != null ? null : (has ? () async => await OfflineMusic.remove(s.id) : _download),
                      icon: _dl != null
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, value: _dl! > 0 ? _dl : null, color: c.primary))
                          : Icon(has ? Icons.download_done_rounded : Icons.download_rounded, color: c.primary),
                      label: Text(has ? 'Disponible hors ligne · Retirer du téléphone' : 'Télécharger pour écouter sans internet', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: c.primary.withValues(alpha: .5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          if (s.description != null && s.description!.isNotEmpty) ...[
            Text(s.description!, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
          ],
          Row(children: [
            Expanded(child: ValueListenableBuilder<Map<String, int>>(valueListenable: StreamCounts.counts, builder: (_, __, ___) => _Stat(label: 'Écoutes', value: StreamCounts.fmt(StreamCounts.of(_track)), c: c))),
            const SizedBox(width: 10),
            Expanded(child: ValueListenableBuilder<Map<String, int>>(valueListenable: StreamCounts.likes, builder: (_, __, ___) => _Stat(label: 'J’aime', value: StreamCounts.fmt(StreamCounts.likesOf(_track)), c: c))),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: 'Posts créés', value: '${s.postCount}', c: c)),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: 'Dans le Studio', value: s.isFree ? 'Gratuit' : '🪙 ${s.unitPrice}', c: c)),
          ]),
          if (MusicTrack.fromSound(s).isMine) ...[
            const SizedBox(height: 10),
            _earningsBox(c, s),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => startPostWithMusic(context, MontageMusic.artist(s), ownVideo: true),
              icon: Icon(Icons.videocam_rounded, color: c.primary),
              label: Text('Ma vidéo avec ce son (sans habillage)', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: c.primary.withValues(alpha: .5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.isFree
                ? 'Tu choisis un modèle, ta photo ou ta vidéo : le son est ajouté. Avec « Ma vidéo », le son d’origine de ta vidéo est coupé : seule la musique est jouée.'
                : 'Tu choisis un modèle : le prix (${s.unitPrice} pièces, dont ${s.unitShare} pour l’artiste) et ton solde te sont annoncés avant. Rien n’est débité si la vidéo échoue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 22),
          if (!widget.preview) SoundPostsSection(soundId: s.id, colors: c),
        ]),
      ),
    );
  }

  Widget _actionBtn(AppColors c, {required IconData icon, required String title, required String sub, required VoidCallback? onTap, bool grad = false, bool busy = false}) {
    final fg = grad ? c.onAccent : c.onPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: grad ? LinearGradient(colors: [c.primary, c.accent]) : null,
          color: grad ? null : c.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: busy
            ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg)))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 13.5)),
                ]),
                Text(sub, style: TextStyle(color: fg.withValues(alpha: .9), fontWeight: FontWeight.w800, fontSize: 11.5)),
              ]),
      ),
    );
  }

  /// Carte du lecteur : message (extrait gratuit / fin), barre avec la zone verrouillée du titre complet, temps.
  /// Pour l'artiste : d'où viennent ses pièces sur ce titre (ventes du titre, utilisation dans des posts).
  Widget _earningsBox(AppColors c, ArtistSound s) {
    Widget line(String label, String detail, int coins) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(detail, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              ]),
            ),
            Text('🪙 $coins', style: TextStyle(color: c.primary, fontSize: 15, fontWeight: FontWeight.w900)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PIÈCES GAGNÉES SUR CE TITRE', style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        line('Ventes du titre', '${s.saleCount} vente${s.saleCount > 1 ? 's' : ''} · 60 % du prix', s.saleEarnings),
        line('Utilisations dans des posts', '${s.usageCount} utilisation${s.usageCount > 1 ? 's' : ''} · 60 % du prix', s.useEarnings),
        Divider(color: c.border, height: 12),
        line('Total', '${compactCount(s.streamCount)} écoute${s.streamCount > 1 ? 's' : ''} (10 s d’écoute) — les écoutes ne rapportent pas de pièces', s.totalEarningsCoins),
      ]),
    );
  }

  Widget _playerCard(AppColors c, ArtistSound s) {
    final total = s.durationMs > 0 ? s.durationMs : 204000;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: ValueListenableBuilder<MusicTrack?>(
        valueListenable: MusicQueue.current,
        builder: (_, cur, __) => ValueListenableBuilder<bool>(
          valueListenable: MusicQueue.previewEnded,
          builder: (_, ended, __) {
            final mine = cur?.key == _track.key;
            final preview = !_full;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (preview) Icon(Icons.lock_rounded, size: 15, color: mine && ended ? c.warning : c.primary),
                if (preview) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    !preview ? 'Titre complet' : (mine && ended ? 'Extrait terminé' : 'Extrait gratuit de ${s.previewSec} secondes'),
                    style: TextStyle(color: preview && mine && ended ? c.warning : c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              StreamBuilder<Duration>(
                stream: SoundPreview.position,
                builder: (_, p) => StreamBuilder<Duration>(
                  stream: SoundPreview.duration,
                  builder: (_, d) {
                    final pos = mine ? (p.data?.inMilliseconds ?? 0) : 0;
                    final fileMs = d.data?.inMilliseconds ?? (preview ? 30000 : total);
                    final shown = (mine && ended) ? (preview ? 30000 : pos) : pos;
                    final frac = (shown / total).clamp(0.0, 1.0);
                    final lock = preview ? (30000 / total).clamp(0.0, 1.0) : 1.0;
                    return Column(children: [
                      _SeekBar(
                        c: c,
                        progress: frac,
                        lockFrom: preview ? lock : null,
                        onSeek: mine && !ended
                            ? (f) => SoundPreview.seek(Duration(milliseconds: (f * total).round().clamp(0, fileMs)))
                            : null,
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(_fmtMs(shown), style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                        Text(preview ? '0:30 · titre complet ${_fmtMs(total)}' : _fmtMs(total), style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ]);
                  },
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

String _fmtMs(int ms) {
  final s = (ms / 1000).floor();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Barre de lecture : la partie gratuite en couleur, la suite du titre (verrouillée) hachurée avec un cadenas.
class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.c, required this.progress, this.lockFrom, this.onSeek});
  final AppColors c;
  final double progress;
  final double? lockFrom;
  final void Function(double fraction)? onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      final w = box.maxWidth;
      void seek(double dx) {
        if (onSeek == null) return;
        final f = (dx / w).clamp(0.0, lockFrom ?? 1.0);
        onSeek!(f);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => seek(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
        child: SizedBox(
          height: 28,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 11,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: Stack(children: [
                    Container(color: c.border),
                    if (lockFrom != null) Positioned(left: w * lockFrom!, right: 0, top: 0, bottom: 0, child: CustomPaint(painter: _HatchPainter(c.textSecondary.withValues(alpha: .45)))),
                    FractionallySizedBox(widthFactor: progress.clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent])))),
                  ]),
                ),
              ),
            ),
            Positioned(left: (w * progress.clamp(0.0, 1.0)) - 8, top: 6, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.primary.withValues(alpha: .3), spreadRadius: 4)]))),
            if (lockFrom != null)
              Positioned(
                left: w * lockFrom! - 10,
                top: 4,
                child: Container(width: 20, height: 20, decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.warning)), child: Icon(Icons.lock_rounded, size: 11, color: c.warning)),
              ),
          ]),
        ),
      );
    });
  }
}

class _HatchPainter extends CustomPainter {
  _HatchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1.5;
    for (double x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter old) => old.color != color;
}

/// Achat d'un titre : annonce le prix, la part de l'artiste et le solde ; recharge proposée si le solde est insuffisant.
/// Renvoie true si le titre est maintenant dans la bibliothèque.
final Set<String> _buyingTracks = <String>{};

Future<bool> buyTrack(BuildContext context, ArtistSound s) async {
  final c = AppColors.of(context);
  // déjà dans la bibliothèque (ou achat en cours) : jamais de deuxième paiement ni de nouvelle confirmation
  if (MusicQueue.ownedIds.value.contains(s.id)) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce titre est déjà dans ta bibliothèque.')));
    return true;
  }
  if (!_buyingTracks.add(s.id)) return false;
  try {
    return await _buyTrackConfirmed(context, s, c);
  } finally {
    _buyingTracks.remove(s.id);
  }
}

Future<bool> _buyTrackConfirmed(BuildContext context, ArtistSound s, AppColors c) async {
  final me = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
  final balance = me.giftCoinsBalance ?? 0;
  final price = s.saleCoins;
  if (balance < price) {
    final recharge = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Solde insuffisant', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('« ${s.title} » coûte $price pièces et tu en as $balance. Recharge tes pièces pour l’acheter.', style: TextStyle(color: c.textSecondary, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Plus tard', style: TextStyle(color: c.textSecondary))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Recharger mes pièces')),
        ],
      ),
    );
    if (recharge == true && context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      title: Text('Acheter ce titre ?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('« ${s.title} »', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('Prix : $price pièces', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        Text('${s.saleShare} pièces vont directement à l’artiste.', style: TextStyle(color: c.textSecondary, height: 1.35)),
        const SizedBox(height: 8),
        Text('Ton solde : $balance pièces → ${balance - price} après.', style: TextStyle(color: c.textSecondary)),
        const SizedBox(height: 8),
        Text('Le titre reste dans ta bibliothèque et se lit dans Afrolook. Achat définitif.', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Acheter ($price 🪙)')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  String msg;
  var done = false;
  try {
    final r = await FirebaseFunctions.instance.httpsCallable('musicBuy').call({'soundId': s.id});
    final d = Map<String, dynamic>.from(r.data as Map);
    done = true;
    msg = d['already'] == true ? 'Ce titre est déjà dans ta bibliothèque.' : '✅ Ajouté à ta bibliothèque. Merci de soutenir l’artiste !';
  } on FirebaseFunctionsException catch (e) {
    msg = e.code == 'resource-exhausted' ? 'Solde insuffisant.' : (e.message ?? 'Achat impossible.');
  } catch (_) {
    msg = 'Achat impossible. Vérifie ta connexion.';
  }
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  return done;
}

/// 1 234 → « 1,2 k » ; 1 500 000 → « 1,5 M ».
String compactCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1).replaceAll('.', ',')} M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1).replaceAll('.', ',')} k';
  return '$n';
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;
  const _Stat({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(children: [
        Text(value, style: TextStyle(color: c.primary, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ]),
    );
  }
}

// ─── Page "Mes sons" (artiste) ───────────────────────────────────────────────

class MyArtistSoundsPage extends StatelessWidget {
  const MyArtistSoundsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final uid = auth.loginUserData.id ?? '';

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text('Espace artiste', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Proposer un son',
            icon: Icon(Icons.add, color: c.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArtistSoundSubmitPage())),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('artist_sounds').where('userId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshotsM('artist_marketplace.dart:1343'),
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('Impossible de charger tes sons.', style: TextStyle(color: c.textSecondary)));
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: c.primary));
          final sounds = [for (final d in snap.data!.docs) ArtistSound.fromMap(d.data() as Map<String, dynamic>, d.id)];
          final earned = sounds.fold<int>(0, (a, s) => a + s.totalEarningsCoins);
          final uses = sounds.fold<int>(0, (a, s) => a + s.usageCount);
          final streams = sounds.fold<int>(0, (a, s) => a + s.streamCount);
          return ListView(padding: const EdgeInsets.all(16), children: [
            _earningsCard(c, earned, uses, streams),
            const SizedBox(height: 14),
            _howItWorks(c),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('MES SONS (${sounds.length})', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArtistSoundSubmitPage())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Proposer un son'),
              ),
            ]),
            if (sounds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(children: [
                  Icon(Icons.music_off, size: 52, color: c.textSecondary),
                  const SizedBox(height: 10),
                  Text('Tu n’as pas encore proposé de son.', style: TextStyle(color: c.textSecondary)),
                ]),
              ),
            for (final s in sounds) Padding(padding: const EdgeInsets.only(bottom: 10), child: _MySoundTile(sound: s, colors: c)),
          ]);
        },
      ),
    );
  }

  Widget _earningsCard(AppColors c, int earned, int uses, int streams) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)]), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pièces gagnées avec mes sons', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('🪙 $earned', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            Text('≈ ${ArtistSoundPricing.fcfaOf(earned)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Écoutes', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(compactCount(streams), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Utilisations', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('$uses', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }

  Widget _howItWorks(AppColors c) {
    Widget line(String t) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(t, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Comment tu es payé', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),
        line('• Tu touches 60 % : à chaque utilisation dans le Studio (tu fixes le prix, 2 à 20 pièces) et à chaque vente du titre complet (50 à 500 pièces).'),
        line('• Les pièces arrivent tout de suite dans ton solde de pièces (Monétisation → Mes pièces). Ce sont des pièces gagnées : tu peux les convertir en argent '
            '(25 pièces = 10 FCFA) et les retirer, ou les dépenser dans l’app.'),
        line('• Son gratuit : pas de gain. Et si tu utilises ton propre son, c’est gratuit pour toi mais il ne te rapporte rien non plus.'),
        line('• Ton fichier original reste privé : les autres n’entendent qu’un court extrait (jusqu’à 30 secondes, selon la durée du titre).'),
      ]),
    );
  }
}

class _MySoundTile extends StatelessWidget {
  final ArtistSound sound;
  final AppColors colors;
  const _MySoundTile({required this.sound, required this.colors});

  Color get _statusColor {
    switch (sound.status) {
      case 'validated':
        return Colors.green;
      case 'refused':
        return Colors.red;
      case 'suspended':
        return Colors.deepOrange;
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (sound.status) {
      case 'validated':
        return 'En ligne ✓';
      case 'refused':
        return 'Refusé';
      case 'suspended':
        return 'Suspendu';
      default:
        return sound.processed == null ? 'Analyse…' : 'À l’écoute';
    }
  }

  Future<void> _delete(BuildContext context) async {
    final c = colors;
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final match = ctl.text == sound.title;
          return AlertDialog(
            backgroundColor: c.surface,
            title: const Text('Supprimer définitivement ?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 17)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('« ${sound.title} »', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  'Le son disparaît du Studio et du fil, son fichier est effacé de nos serveurs et tu ne pourras pas le récupérer. '
                  'Les montages déjà publiés avec ce son restent en ligne. Tes ${sound.totalEarningsCoins} pièces déjà gagnées restent dans ton solde.',
                  style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Text('Pour confirmer, retape exactement le titre :', style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: ctl,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setS(() {}),
                  style: TextStyle(color: c.textPrimary),
                  decoration: InputDecoration(hintText: sound.title, hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: .5)), isDense: true, border: const OutlineInputBorder()),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
              TextButton(onPressed: match ? () => Navigator.pop(ctx, true) : null, child: const Text('Supprimer pour toujours', style: TextStyle(color: Colors.red))),
            ],
          );
        },
      ),
    );
    final typed = ctl.text;
    ctl.dispose();
    if (ok != true || !context.mounted) return;
    String msg;
    try {
      await FirebaseFunctions.instance.httpsCallable('artistSoundDelete').call({'soundId': sound.id, 'confirm': typed});
      msg = 'Son supprimé.';
    } on FirebaseFunctionsException catch (e) {
      msg = e.message == 'CONFIRMATION_INVALIDE' ? 'Le titre ne correspond pas.' : (e.message ?? 'Suppression impossible.');
    } catch (_) {
      msg = 'Suppression impossible. Vérifie ta connexion.';
    }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dup = sound.duplicates.where((d) => d['kind'] != 'similar').toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _cover(sound, 52, colors, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sound.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 4),
              Row(children: [
                _pricingBadge(sound, colors),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${compactCount(sound.streamCount)} écoutes · ${sound.saleCount} ventes · ${sound.usageCount} util. · 🪙 ${sound.totalEarningsCoins}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                ),
              ]),
            ]),
          ),
          SoundPlayButton(soundKey: 'mine_${sound.id}', url: sound.previewUrl, size: 30),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: .15), borderRadius: BorderRadius.circular(8)),
            child: Text(_statusLabel, style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (sound.status == 'refused' && sound.refusalReason != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Motif : ${sound.refusalReason}', style: const TextStyle(color: Colors.red, fontSize: 11.5))),
        if (sound.status == 'suspended')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Des personnes ont signalé ce son : il est retiré du Studio le temps que l’équipe vérifie.', style: TextStyle(color: Colors.deepOrange, fontSize: 11.5)),
          ),
        if (sound.status == 'pending_review' && dup.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Un morceau très proche existe déjà : l’équipe va vérifier que tu en es bien l’auteur.', style: TextStyle(color: Colors.orange, fontSize: 11.5)),
          ),
        const SizedBox(height: 6),
        if (sound.status != 'refused')
          Row(children: [
            Expanded(child: Text(SoundCountries.summary(sound.availableCountries), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 11.5))),
            TextButton.icon(
              onPressed: () async {
                final r = await SoundCountries.pick(context, initial: sound.availableCountries);
                if (r == null || !context.mounted) return;
                final msg = await SoundCountries.save(sound.id, r);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              },
              icon: Icon(Icons.public_rounded, size: 17, color: colors.primary),
              label: Text('Pays', style: TextStyle(color: colors.primary, fontSize: 12)),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline, size: 17, color: Colors.red),
            label: const Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: 12)),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
      ]),
    );
  }
}

// ─── Page Admin : écoute, doublons, validation, signalements ─────────────────

class AdminArtistSoundsPage extends StatelessWidget {
  const AdminArtistSoundsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: Text('Sons artistes', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          bottom: TabBar(
            labelColor: c.primary,
            unselectedLabelColor: c.textSecondary,
            indicatorColor: c.primary,
            tabs: const [Tab(text: 'À valider'), Tab(text: 'Signalés / suspendus')],
          ),
        ),
        body: TabBarView(children: [
          _list(c, FirebaseFirestore.instance.collection('artist_sounds').where('status', isEqualTo: 'pending_review').orderBy('createdAt', descending: true), 'Aucun son en attente.', false),
          _list(c, FirebaseFirestore.instance.collection('artist_sounds').where('reportCount', isGreaterThan: 0).orderBy('reportCount', descending: true), 'Aucun son signalé.', true),
        ]),
      ),
    );
  }

  Widget _list(AppColors c, Query q, String empty, bool reports) {
    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshotsM('artist_marketplace.dart:1615'),
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Text('Chargement impossible (index en cours de création ?).', style: TextStyle(color: c.textSecondary)));
        if (!snap.hasData) return Center(child: CircularProgressIndicator(color: c.primary));
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
              const SizedBox(height: 12),
              Text(empty, style: TextStyle(color: c.textSecondary)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _AdminSoundReviewTile(key: ValueKey(docs[i].id), sound: ArtistSound.fromMap(docs[i].data() as Map<String, dynamic>, docs[i].id), colors: c, reports: reports),
        );
      },
    );
  }
}

class _AdminSoundReviewTile extends StatefulWidget {
  final ArtistSound sound;
  final AppColors colors;
  final bool reports;
  const _AdminSoundReviewTile({super.key, required this.sound, required this.colors, required this.reports});

  @override
  State<_AdminSoundReviewTile> createState() => _AdminSoundReviewTileState();
}

class _AdminSoundReviewTileState extends State<_AdminSoundReviewTile> {
  bool _loading = false;
  bool _fullPlaying = false;
  final AudioPlayer _full = AudioPlayer();

  @override
  void dispose() {
    _full.dispose();
    super.dispose();
  }

  Future<void> _toggleFull() async {
    if (_fullPlaying) {
      await _full.stop();
      if (mounted) setState(() => _fullPlaying = false);
      return;
    }
    await SoundPreview.stop();
    setState(() => _loading = true);
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('artistSoundAdminUrl').call({'soundId': widget.sound.id});
      final url = (r.data as Map)['url'] as String;
      await _full.play(UrlSource(url));
      _full.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _fullPlaying = false);
      });
      if (mounted) setState(() => _fullPlaying = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lecture de l’original impossible : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _set(Map<String, dynamic> data) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('artist_sounds').doc(widget.sound.id).update(data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _validate() async {
    final s = widget.sound;
    final serious = s.duplicates.any((d) => d['kind'] != null);
    if (serious) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.colors.surface,
          title: Text('Un son proche existe déjà', style: TextStyle(color: widget.colors.textPrimary, fontSize: 16)),
          content: Text('L’analyse a trouvé un morceau très ressemblant. Tu as écouté les deux et tu es sûr qu’il est libre de droits ?', style: TextStyle(color: widget.colors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, valider')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _set({'status': 'validated', 'validatedAt': FieldValue.serverTimestamp(), 'suspendedAt': FieldValue.delete()});
  }

  Future<void> _refuse() async {
    final ctl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.colors.surface,
        title: Text('Motif de refus', style: TextStyle(color: widget.colors.textPrimary)),
        content: TextField(
          controller: ctl,
          style: TextStyle(color: widget.colors.textPrimary),
          decoration: InputDecoration(hintText: 'Ex : morceau copié, mauvaise qualité…', hintStyle: TextStyle(color: widget.colors.textSecondary)),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: widget.colors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Refuser', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    ctl.dispose();
    if (reason == null) return;
    await _set({'status': 'refused', 'refusalReason': reason.isEmpty ? 'Non conforme' : reason});
  }

  Future<void> _deleteAsAdmin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.colors.surface,
        title: const Text('Supprimer ce son ?', style: TextStyle(color: Colors.red)),
        content: Text('Le son et ses fichiers seront effacés pour toujours.', style: TextStyle(color: widget.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('artistSoundDelete').call({'soundId': widget.sound.id});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression impossible : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _kindLabel(String? k) => switch (k) {
        'same_file' => 'MÊME FICHIER',
        'same_track' => 'MÊME MORCEAU (ré-encodé / recadré)',
        _ => 'Morceau très proche',
      };

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final s = widget.sound;
    final analysed = s.processed == true;
    final failed = s.processed == 'error';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: s.duplicates.isNotEmpty ? Colors.orange : c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _cover(s, 56, c, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text('@${s.userPseudo}${s.genre != null ? ' · ${s.genre}' : ''}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _pricingBadge(s, c),
                if (s.durationMs > 0) Text('⏱ ${_fmtDuration(s.durationMs)}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                Text('statut : ${s.status}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ]),
            ]),
          ),
        ]),
        if (s.description != null && s.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(s.description!, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        // Écoute : extrait de 30 s et original en entier
        Row(children: [
          SoundPlayButton(soundKey: 'admin_${s.id}', url: s.previewUrl, size: 32),
          Text('Extrait ${s.previewSec} s', style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _loading ? null : _toggleFull,
            icon: Icon(_fullPlaying ? Icons.stop_circle_outlined : Icons.headphones_rounded, size: 18),
            label: Text(_fullPlaying ? 'Arrêter' : 'Écouter en entier'),
          ),
        ]),
        const SizedBox(height: 6),
        // Résultat de l'analyse automatique
        if (!analysed && !failed)
          _note('⏳ Analyse en cours (qualité, doublons)…', Colors.blueGrey)
        else if (failed)
          _note('⚠️ Analyse automatique impossible : écoute le son en entier avant de valider.', Colors.orange)
        else if (s.duplicates.isEmpty)
          _note('✅ Aucun doublon trouvé parmi les sons déjà en ligne.', Colors.green),
        for (final d in s.duplicates)
          _note('⚠️ ${_kindLabel(d['kind'] as String?)} : « ${d['title']} » de @${d['artist']}${d['ber'] != null ? ' (écart ${((d['ber'] as num) * 100).toStringAsFixed(0)} %)' : ''}', Colors.orange),
        if (widget.reports) _ReportsList(soundId: s.id, count: s.reportCount, colors: c),
        const SizedBox(height: 12),
        if (_loading)
          Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)))
        else
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _refuse,
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                label: const Text('Refuser', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            ),
            if (widget.reports) ...[
              const SizedBox(width: 8),
              IconButton(tooltip: 'Supprimer', onPressed: _deleteAsAdmin, icon: const Icon(Icons.delete_outline, color: Colors.red)),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (analysed || failed || widget.reports) ? _validate : null,
                icon: const Icon(Icons.check, size: 16),
                label: Text(widget.reports && s.status != 'pending_review' ? 'Rétablir' : 'Valider'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _note(String t, Color color) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)));
}

class _ReportsList extends StatelessWidget {
  final String soundId;
  final int count;
  final AppColors colors;
  const _ReportsList({required this.soundId, required this.count, required this.colors});

  @override
  Widget build(BuildContext context) {
    final label = {for (final r in kReportReasons) r.$1: r.$2};
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ArtistSoundReports').where('soundId', isEqualTo: soundId).snapshotsM('artist_marketplace.dart:1866'),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? const [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('🚩 $count signalement(s)', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w800, fontSize: 12.5)),
          for (final d in docs)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '• ${label[(d.data() as Map)['reason']] ?? (d.data() as Map)['reason']}${((d.data() as Map)['note'] ?? '').toString().isNotEmpty ? ' — « ${(d.data() as Map)['note']} »' : ''}',
                style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
              ),
            ),
        ]);
      },
    );
  }
}


// ─── Posts faits avec un son (5 par 5) ───────────────────────────────────────

class SoundPostsSection extends StatefulWidget {
  const SoundPostsSection({super.key, required this.soundId, required this.colors});
  final String soundId;
  final AppColors colors;

  @override
  State<SoundPostsSection> createState() => _SoundPostsSectionState();
}

class _SoundPostsSectionState extends State<SoundPostsSection> {
  static const _page = 5;
  final List<Post> _posts = [];
  DocumentSnapshot? _last;
  bool _loading = false;
  bool _more = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      var q = FirebaseFirestore.instance.collection('Posts').where('artistSoundId', isEqualTo: widget.soundId).orderBy('created_at', descending: true).limit(_page);
      if (_last != null) q = q.startAfterDocument(_last!);
      final snap = await q.getM('artist_marketplace.dart:1921');
      for (final d in snap.docs) {
        final p = Post.fromJson(d.data());
        p.id = d.id;
        _posts.add(p);
      }
      if (snap.docs.isNotEmpty) _last = snap.docs.last;
      _more = snap.docs.length == _page;
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('POSTS FAITS AVEC CE SON', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
      const SizedBox(height: 10),
      if (_posts.isEmpty && !_loading && !_failed)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Text('Aucun post pour l’instant. Sois le premier à utiliser ce son !', style: TextStyle(color: c.textSecondary, fontSize: 13)),
        ),
      if (_failed) Text('Chargement impossible. Réessaie dans un instant.', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
      for (final p in _posts) _tile(p, c),
      if (_loading) Padding(padding: const EdgeInsets.all(16), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)))),
      if (_more && !_loading && _posts.isNotEmpty)
        Center(child: TextButton(onPressed: _load, child: Text('Voir $_page de plus', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)))),
    ]);
  }

  Widget _tile(Post p, AppColors c) {
    final thumb = (p.images != null && p.images!.isNotEmpty) ? p.images!.first : (p.thumbnail ?? (p.dataType == PostDataType.IMAGE.name ? p.url_media : null));
    final isVideo = p.dataType == PostDataType.VIDEO.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await SoundPreview.stop();
          if (!context.mounted) return;
          // une vidéo s'ouvre dans la page des vidéos, une image / un texte dans la page des posts (comme partout dans l'application)
          Navigator.push(context, MaterialPageRoute(builder: (_) => isVideo ? PostDetailsVideoFormatTel(initialPost: p, isIn: false) : DetailsPost(post: p)));
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Stack(fit: StackFit.expand, children: [
                  thumb != null && thumb.isNotEmpty
                      ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: c.border))
                      : Container(color: c.border, child: Icon(Icons.music_note_rounded, color: c.textSecondary)),
                  if (isVideo) const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((p.description ?? '').trim().isEmpty ? 'Sans texte' : p.description!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('❤️ ${p.loves ?? 0}  ·  💬 ${p.comments ?? 0}  ·  👁 ${p.vues ?? 0}', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          ]),
        ),
      ),
    );
  }
}
