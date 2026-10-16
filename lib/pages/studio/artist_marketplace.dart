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

import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import 'artist_sound_common.dart';

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
  final Object? processed; // true | 'error' | null (analyse du serveur)
  final List<Map<String, dynamic>> duplicates;
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
    this.processed,
    this.duplicates = const [],
    required this.createdAt,
    this.validatedAt,
  });

  bool get isFree => pricing == 'free';

  factory ArtistSound.fromMap(Map<String, dynamic> map, String id) {
    return ArtistSound(
      id: id,
      userId: map['userId'] ?? '',
      userPseudo: map['userPseudo'] ?? '',
      userImageUrl: map['userImageUrl'] ?? '',
      title: map['title'] ?? '',
      genre: map['genre'],
      description: map['description'],
      audioPath: map['audioPath'],
      // anciens sons : pas d'extrait, on garde le lien d'origine pour l'écoute
      previewUrl: map['previewUrl'] ?? map['audioUrl'],
      pricing: map['pricing'] == 'free' ? 'free' : 'paid',
      coverImageUrl: map['coverImageUrl'],
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      fileSizeMb: (map['fileSizeMb'] as num?)?.toDouble(),
      status: map['status'] ?? 'pending_review',
      refusalReason: map['refusalReason'],
      usageCount: (map['usageCount'] as num?)?.toInt() ?? 0,
      totalEarningsCoins: (map['totalEarningsCoins'] as num?)?.toInt() ?? 0,
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
      processed: map['processed'],
      duplicates: [for (final d in (map['duplicates'] as List? ?? const [])) Map<String, dynamic>.from(d as Map)],
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
    child: Text(free ? 'Gratuit' : '🪙 ${ArtistSoundPricing.price}', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
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
  double _progress = 0;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
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
                    'La personne qui utilise ton son paie ${ArtistSoundPricing.price} pièces. Tu gagnes ${ArtistSoundPricing.share} pièces à chaque utilisation '
                        '(≈ ${ArtistSoundPricing.fcfaOf(ArtistSoundPricing.share)}), convertibles en argent.'),
                const SizedBox(height: 8),
                _pricingOption(c, 'free', '🎁 Gratuit', 'Tout le monde peut l’utiliser sans payer. Tu ne gagnes pas de pièces, mais ton nom circule et ton son se fait connaître.'),
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
                  'Ton fichier original reste privé : les autres n’entendent qu’un extrait de 30 secondes. '
                  'Notre système repère les doublons et l’équipe écoute ton son avant de le valider (48 h maximum).',
                  style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
                ),
              ]),
            ),
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
          .limit(20)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
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
              TextButton(onPressed: openMine, child: Text('🎤 Proposer le mien', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 12.5))),
            ]),
          ),
          SizedBox(
            height: 124,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SoundCard(sound: ArtistSound.fromMap(docs[i].data() as Map<String, dynamic>, docs[i].id), colors: c),
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

// ─── Page détail d'un son (extrait gratuit) ──────────────────────────────────

class ArtistSoundDetailPage extends StatefulWidget {
  final ArtistSound sound;
  const ArtistSoundDetailPage({Key? key, required this.sound}) : super(key: key);

  @override
  State<ArtistSoundDetailPage> createState() => _ArtistSoundDetailPageState();
}

class _ArtistSoundDetailPageState extends State<ArtistSoundDetailPage> {
  Duration _pos = Duration.zero;
  Duration _dur = const Duration(seconds: 30);
  late final key = 'detail_${widget.sound.id}';

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    SoundPreview.position.listen((p) {
      if (mounted && SoundPreview.playing.value == key) setState(() => _pos = p);
    });
    SoundPreview.duration.listen((d) {
      if (mounted && d.inMilliseconds > 0) setState(() => _dur = d);
    });
  }

  @override
  void dispose() {
    if (SoundPreview.playing.value == key) SoundPreview.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = widget.sound;
    final me = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
    final total = _fmtDuration(s.durationMs);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          if (s.userId != me)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: c.textPrimary),
              color: c.surface,
              onSelected: (_) => reportArtistSound(context, s.id, s.title),
              itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('🚩 Signaler ce son'))],
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
        Center(child: _cover(s, 220, c, radius: 20)),
        const SizedBox(height: 18),
        Text(s.title, textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('par @${s.userPseudo}${s.genre != null && s.genre!.isNotEmpty ? ' · ${s.genre}' : ''}', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Center(child: _pricingBadge(s, c)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          child: Column(children: [
            Row(children: [
              SoundPlayButton(soundKey: key, url: s.previewUrl, size: 46),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Extrait gratuit de 30 secondes', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  Slider(
                    value: _pos.inMilliseconds.clamp(0, _dur.inMilliseconds).toDouble(),
                    max: _dur.inMilliseconds.toDouble(),
                    activeColor: c.primary,
                    onChanged: (v) {
                      if (SoundPreview.playing.value == key) SoundPreview.seek(Duration(milliseconds: v.round()));
                    },
                  ),
                ]),
              ),
            ]),
            if (total.isNotEmpty)
              Align(alignment: Alignment.centerRight, child: Text('Morceau complet : $total', style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
          ]),
        ),
        const SizedBox(height: 16),
        if (s.description != null && s.description!.isNotEmpty) ...[
          Text(s.description!, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(child: _Stat(label: 'Utilisations', value: '${s.usageCount}', c: c)),
          const SizedBox(width: 10),
          Expanded(child: _Stat(label: 'Dans le Studio', value: s.isFree ? 'Gratuit' : '${ArtistSoundPricing.price} pièces', c: c)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
          child: Text(
            'Pour utiliser ce son : Studio → modèles prêts à poster → choisis un modèle → Musique → Artistes. '
            'Le morceau complet n’est jamais téléchargeable ici : il reste protégé.',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
          ),
        ),
      ]),
    );
  }
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
        stream: FirebaseFirestore.instance.collection('artist_sounds').where('userId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('Impossible de charger tes sons.', style: TextStyle(color: c.textSecondary)));
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: c.primary));
          final sounds = [for (final d in snap.data!.docs) ArtistSound.fromMap(d.data() as Map<String, dynamic>, d.id)];
          final earned = sounds.fold<int>(0, (a, s) => a + s.totalEarningsCoins);
          final uses = sounds.fold<int>(0, (a, s) => a + s.usageCount);
          return ListView(padding: const EdgeInsets.all(16), children: [
            _earningsCard(c, earned, uses),
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

  Widget _earningsCard(AppColors c, int earned, int uses) {
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
          const Text('Utilisations', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('$uses', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
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
        line('• Son payant : à chaque utilisation dans le Studio, tu gagnes ${ArtistSoundPricing.share} pièces (la personne en paie ${ArtistSoundPricing.price}).'),
        line('• Les pièces arrivent tout de suite dans ton solde de pièces (Monétisation → Mes pièces). Ce sont des pièces gagnées : tu peux les convertir en argent '
            '(25 pièces = 10 FCFA) et les retirer, ou les dépenser dans l’app.'),
        line('• Son gratuit : pas de gain. Et si tu utilises ton propre son, c’est gratuit pour toi mais il ne te rapporte rien non plus.'),
        line('• Ton fichier original reste privé : les autres n’entendent qu’un extrait de 30 secondes.'),
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
                  child: Text('${sound.usageCount} util. · 🪙 ${sound.totalEarningsCoins} gagnées', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
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
      stream: q.snapshots(),
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
          Text('Extrait 30 s', style: TextStyle(color: c.textSecondary, fontSize: 12)),
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
      stream: FirebaseFirestore.instance.collection('ArtistSoundReports').where('soundId', isEqualTo: soundId).snapshots(),
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
