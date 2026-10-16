// lib/pages/studio/artist_marketplace.dart
//
// Marketplace artiste : un artiste soumet un son, l'admin valide,
// le son apparaît dans le feed.
//
// Commission : l'artiste voit "3 pièces par utilisation".
// Les 2 pièces app ne sont JAMAIS affichées ici.
//
// Structure Firestore :
//   artist_sounds/{soundId}
//     - userId, userPseudo, userImageUrl
//     - title, genre, description
//     - audioUrl, coverImageUrl
//     - durationMs, fileSizeMb
//     - status: 'pending_review' | 'validated' | 'refused'
//     - refusalReason (optionnel)
//     - usageCount, totalEarningsCoins
//     - createdAt, validatedAt

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';

// ─── Modèle ──────────────────────────────────────────────────────────────────

class ArtistSound {
  final String id;
  final String userId;
  final String userPseudo;
  final String userImageUrl;
  final String title;
  final String? genre;
  final String? description;
  final String audioUrl;
  final String? coverImageUrl;
  final int durationMs;
  final double? fileSizeMb;
  final String status; // 'pending_review' | 'validated' | 'refused'
  final String? refusalReason;
  final int usageCount;
  final int totalEarningsCoins;
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
    required this.audioUrl,
    this.coverImageUrl,
    required this.durationMs,
    this.fileSizeMb,
    required this.status,
    this.refusalReason,
    required this.usageCount,
    required this.totalEarningsCoins,
    required this.createdAt,
    this.validatedAt,
  });

  factory ArtistSound.fromMap(Map<String, dynamic> map, String id) {
    return ArtistSound(
      id: id,
      userId: map['userId'] ?? '',
      userPseudo: map['userPseudo'] ?? '',
      userImageUrl: map['userImageUrl'] ?? '',
      title: map['title'] ?? '',
      genre: map['genre'],
      description: map['description'],
      audioUrl: map['audioUrl'] ?? '',
      coverImageUrl: map['coverImageUrl'],
      durationMs: map['durationMs'] ?? 0,
      fileSizeMb: (map['fileSizeMb'] as num?)?.toDouble(),
      status: map['status'] ?? 'pending_review',
      refusalReason: map['refusalReason'],
      usageCount: map['usageCount'] ?? 0,
      totalEarningsCoins: map['totalEarningsCoins'] ?? 0,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      validatedAt: map['validatedAt'],
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userPseudo': userPseudo,
    'userImageUrl': userImageUrl,
    'title': title,
    'genre': genre,
    'description': description,
    'audioUrl': audioUrl,
    'coverImageUrl': coverImageUrl,
    'durationMs': durationMs,
    'fileSizeMb': fileSizeMb,
    'status': status,
    'refusalReason': refusalReason,
    'usageCount': usageCount,
    'totalEarningsCoins': totalEarningsCoins,
    'createdAt': createdAt,
    'validatedAt': validatedAt,
  };
}

// ─── Page de soumission ───────────────────────────────────────────────────────

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
  double _progress = 0;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _genreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;
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

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() { _isSubmitting = true; _progress = 0; });

    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final storage = FirebaseStorage.instance;
    final firestore = FirebaseFirestore.instance;

    try {
      // Upload audio
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ext = _audioFile!.path.split('.').last;
      final uid = auth.loginUserData.id!;
      final audioRef = storage.ref('artist_sounds/$uid/$ts.$ext');
      final uploadAudio = audioRef.putFile(_audioFile!);
      uploadAudio.snapshotEvents.listen((s) => setState(() => _progress = s.bytesTransferred / s.totalBytes * 0.8));
      final audioSnap = await uploadAudio;
      final audioUrl = await audioSnap.ref.getDownloadURL();

      // Upload cover si fournie
      String? coverUrl;
      if (_coverFile != null) {
        final coverRef = storage.ref('artist_sound_covers/$uid/$ts.jpg');
        final uploadCover = coverRef.putFile(_coverFile!);
        uploadCover.snapshotEvents.listen((s) => setState(() => _progress = 0.8 + s.bytesTransferred / s.totalBytes * 0.2));
        final coverSnap = await uploadCover;
        coverUrl = await coverSnap.ref.getDownloadURL();
      }

      final sizeMb = (await _audioFile!.stat()).size / (1024 * 1024);

      final sound = ArtistSound(
        id: '',
        userId: auth.loginUserData.id!,
        userPseudo: auth.loginUserData.pseudo ?? '',
        userImageUrl: auth.loginUserData.imageUrl ?? '',
        title: _titleCtrl.text.trim(),
        genre: _genreCtrl.text.trim().isEmpty ? null : _genreCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        audioUrl: audioUrl,
        coverImageUrl: coverUrl,
        durationMs: 0,
        fileSizeMb: sizeMb,
        status: 'pending_review',
        usageCount: 0,
        totalEarningsCoins: 0,
        createdAt: Timestamp.now(),
      );

      await firestore.collection('artist_sounds').add({...sound.toMap(), 'rightsCertified': true});

      if (mounted) {
        _snack('Son soumis avec succès ! En attente de validation.');
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _isValid => _audioFile != null && _titleCtrl.text.trim().isNotEmpty && _rights;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text('Soumettre un son', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          if (!_isSubmitting)
            TextButton(
              onPressed: _isValid ? _submit : null,
              child: Text('Soumettre', style: TextStyle(color: _isValid ? c.primary : c.textSecondary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _isSubmitting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(value: _progress, color: c.primary),
                  const SizedBox(height: 12),
                  Text('${(_progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: c.textSecondary)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info rémunération
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.monetization_on, color: c.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu gagnes 3 pièces à chaque fois qu\'une personne utilise ton son dans le Studio (templates prêts à poster). Les pièces gagnées sont convertibles et retirables.',
                            style: TextStyle(color: c.textPrimary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bouton audio
                  GestureDetector(
                    onTap: _pickAudio,
                    child: _buildPickButton(
                      icon: _audioFile != null ? Icons.check_circle : Icons.audio_file,
                      label: _audioFile != null ? _audioFile!.path.split('/').last : 'Choisir le fichier audio (MP3 · max 50 Mo)',
                      active: _audioFile != null,
                      c: c,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Pochette
                  GestureDetector(
                    onTap: _pickCover,
                    child: _buildPickButton(
                      icon: _coverFile != null ? Icons.check_circle : Icons.add_photo_alternate,
                      label: _coverFile != null ? 'Pochette sélectionnée ✓' : 'Ajouter une pochette (optionnel)',
                      active: _coverFile != null,
                      c: c,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Titre
                  _buildField(c, _titleCtrl, 'Titre du son *', maxLength: 60),
                  const SizedBox(height: 12),
                  _buildField(c, _genreCtrl, 'Genre (Afrobeat, Coupé-décalé, Amapiano…)', maxLength: 30),
                  const SizedBox(height: 12),
                  _buildField(c, _descCtrl, 'Description (optionnel)', maxLines: 3, maxLength: 200),

                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _rights,
                    onChanged: (v) => setState(() => _rights = v == true),
                    activeColor: c.primary,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Je certifie être l\'auteur de ce son ou en détenir tous les droits, et j\'autorise Afrolook à le proposer dans le Studio.',
                      style: TextStyle(color: c.textPrimary, fontSize: 12.5),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Ton son sera examiné par notre équipe avant d\'apparaître dans le marketplace (48h max).',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPickButton({required IconData icon, required String label, required bool active, required AppColors c}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? c.primary : c.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? c.primary : c.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: active ? c.primary : c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildField(AppColors c, TextEditingController ctrl, String hint, {int? maxLines, int? maxLength}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines ?? 1,
        maxLength: maxLength,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: c.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textSecondary),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }
}

// ─── Widget feed (liste des sons validés) ─────────────────────────────────────

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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)]),
                ),
                child: const Row(children: [
                  Text('🎤', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Tu es artiste ? Dépose ton son : tu gagnes 3 pièces à chaque utilisation dans le Studio.',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white),
                ]),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(children: [
                Expanded(child: Text('🎵 Sons des artistes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary))),
                TextButton(onPressed: openMine, child: Text('🎤 Proposer le mien', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 12.5))),
              ]),
            ),
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final sound = ArtistSound.fromMap(docs[i].data() as Map<String, dynamic>, docs[i].id);
                  return _SoundCard(sound: sound, colors: c);
                },
              ),
            ),
          ],
        );
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
        width: 100,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: sound.coverImageUrl != null
                  ? CachedNetworkImage(imageUrl: sound.coverImageUrl!, width: 100, height: 68, fit: BoxFit.cover)
                  : Container(
                      width: 100,
                      height: 68,
                      color: colors.border,
                      child: Icon(Icons.music_note, color: colors.textSecondary, size: 28),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sound.title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('🎤 @${sound.userPseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: colors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page détail d'un son ─────────────────────────────────────────────────────

class ArtistSoundDetailPage extends StatelessWidget {
  final ArtistSound sound;
  const ArtistSoundDetailPage({Key? key, required this.sound}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(sound.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (sound.coverImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(imageUrl: sound.coverImageUrl!, width: double.infinity, height: 200, fit: BoxFit.cover),
              )
            else
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.music_note, size: 56, color: c.textSecondary),
              ),

            const SizedBox(height: 20),

            if (sound.genre != null)
              Chip(
                label: Text(sound.genre!, style: const TextStyle(fontSize: 11)),
                backgroundColor: c.primary.withOpacity(0.15),
                side: BorderSide(color: c.primary.withOpacity(0.4)),
              ),

            const SizedBox(height: 12),

            if (sound.description != null)
              Text(sound.description!, style: TextStyle(color: c.textSecondary, fontSize: 13), textAlign: TextAlign.center),

            const SizedBox(height: 20),

            // Rémunération visible
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: 'Utilisations', value: '${sound.usageCount}', c: c),
                  _Stat(label: 'Pièces gagnées', value: '${sound.totalEarningsCoins}', c: c),
                  _Stat(label: 'Par utilisation', value: '3 pièces', c: c),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Par @pseudo
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: sound.userImageUrl.isNotEmpty ? NetworkImage(sound.userImageUrl) : null,
                  child: sound.userImageUrl.isEmpty ? Icon(Icons.person, color: c.textSecondary) : null,
                ),
                const SizedBox(width: 10),
                Text('@${sound.userPseudo}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
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
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.primary)),
        Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary)),
      ],
    );
  }
}

// ─── Page "Mes sons" (artiste) ────────────────────────────────────────────────

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
        title: Text('Mes sons', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: c.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArtistSoundSubmitPage())),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('artist_sounds')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: c.primary));
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_off, size: 56, color: c.textSecondary),
                  const SizedBox(height: 12),
                  Text('Aucun son soumis.', style: TextStyle(color: c.textSecondary)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArtistSoundSubmitPage())),
                    icon: const Icon(Icons.add),
                    label: const Text('Soumettre un son'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final sound = ArtistSound.fromMap(docs[i].data() as Map<String, dynamic>, docs[i].id);
              return _MySoundTile(sound: sound, colors: c);
            },
          );
        },
      ),
    );
  }
}

class _MySoundTile extends StatelessWidget {
  final ArtistSound sound;
  final AppColors colors;
  const _MySoundTile({required this.sound, required this.colors});

  Color get _statusColor {
    switch (sound.status) {
      case 'validated': return Colors.green;
      case 'refused': return Colors.red;
      default: return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (sound.status) {
      case 'validated': return 'Validé ✓';
      case 'refused': return 'Refusé';
      default: return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          if (sound.coverImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: sound.coverImageUrl!, width: 52, height: 52, fit: BoxFit.cover),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.music_note, color: colors.textSecondary),
            ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sound.title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${sound.usageCount} utilisations · ${sound.totalEarningsCoins} pièces gagnées',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                if (sound.status == 'refused' && sound.refusalReason != null)
                  Text('Motif : ${sound.refusalReason}', style: const TextStyle(color: Colors.red, fontSize: 10)),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_statusLabel, style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Page Admin : validation des sons ────────────────────────────────────────

class AdminArtistSoundsPage extends StatelessWidget {
  const AdminArtistSoundsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text('Sons en attente', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('artist_sounds')
            .where('status', isEqualTo: 'pending_review')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: c.primary));
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                  const SizedBox(height: 12),
                  Text('Aucun son en attente.', style: TextStyle(color: c.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final sound = ArtistSound.fromMap(docs[i].data() as Map<String, dynamic>, docs[i].id);
              return _AdminSoundReviewTile(sound: sound, colors: c);
            },
          );
        },
      ),
    );
  }
}

class _AdminSoundReviewTile extends StatefulWidget {
  final ArtistSound sound;
  final AppColors colors;
  const _AdminSoundReviewTile({required this.sound, required this.colors});

  @override
  State<_AdminSoundReviewTile> createState() => _AdminSoundReviewTileState();
}

class _AdminSoundReviewTileState extends State<_AdminSoundReviewTile> {
  bool _loading = false;
  final _refusalController = TextEditingController();

  @override
  void dispose() {
    _refusalController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('artist_sounds').doc(widget.sound.id).update({
      'status': 'validated',
      'validatedAt': FieldValue.serverTimestamp(),
    });
    setState(() => _loading = false);
  }

  Future<void> _refuse() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.colors.surface,
        title: Text('Motif de refus', style: TextStyle(color: widget.colors.textPrimary)),
        content: TextField(
          controller: _refusalController,
          style: TextStyle(color: widget.colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Ex : contenu inapproprié…',
            hintStyle: TextStyle(color: widget.colors.textSecondary),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: widget.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _refusalController.text.trim()),
            child: const Text('Refuser', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('artist_sounds').doc(widget.sound.id).update({
      'status': 'refused',
      'refusalReason': reason.isEmpty ? 'Non conforme' : reason,
    });
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : cover + titre + artiste
          Row(
            children: [
              if (widget.sound.coverImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: widget.sound.coverImageUrl!, width: 56, height: 56, fit: BoxFit.cover),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.music_note, color: c.textSecondary),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.sound.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('@${widget.sound.userPseudo}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    if (widget.sound.genre != null)
                      Text(widget.sound.genre!, style: TextStyle(color: c.primary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),

          if (widget.sound.description != null && widget.sound.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(widget.sound.description!, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ],

          const SizedBox(height: 14),

          // Boutons Valider / Refuser
          if (_loading)
            Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _refuse,
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text('Refuser', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _validate,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
