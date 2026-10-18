// Musique des templates : pistes gratuites d'Afrolook (Storage studio_music/{id}.m4a, créées par
// functions/scripts/gen_studio_music.cjs, sans droits d'auteur) et sons des artistes validés (payants, l'artiste est payé).

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../../services/music_queue.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/music/streams_text.dart';
import '../artist_marketplace.dart';
import '../../../utils/media_cdn.dart';
import '../artist_sound_common.dart';
import '../sound_countries.dart';

const _c = AppColors.dark;

class StudioTrack {
  const StudioTrack(this.id, this.title, this.emoji, this.mood, this.durationMs);
  final String id;
  final String title;
  final String emoji;
  final String mood;
  final int durationMs;
}

/// Pistes gratuites (durées réelles des fichiers envoyés dans Storage).
const kStudioTracks = <StudioTrack>[
  StudioTrack('love_afro', 'Love afro', '💕', 'Amour', 31304),
  StudioTrack('piano_triste', 'Piano triste', '🌧️', 'Triste', 28235),
  StudioTrack('afrobeat', 'Afrobeat énergique', '🔥', 'Énergie', 26667),
  StudioTrack('amapiano', 'Amapiano', '😎', 'Ambiance', 34286),
  StudioTrack('coupe_decale', 'Coupé-décalé', '🕺', 'Fête', 30000),
  StudioTrack('highlife', 'Highlife joyeux', '😁', 'Joie', 33103),
  StudioTrack('afro_trap', 'Afro trap', '👑', 'Boss', 27429),
  StudioTrack('workout', 'Afro workout', '💪', 'Sport', 30968),
  StudioTrack('fanfare', 'Fanfare festive', '🎉', 'Fête', 32000),
  StudioTrack('noel', 'Clochettes de fête', '🎄', 'Fête', 28800),
  StudioTrack('zen_kalimba', 'Kalimba zen', '🧘', 'Calme', 27429),
  StudioTrack('kora_calme', 'Kora calme', '🌿', 'Calme', 25263),
  StudioTrack('plage', 'Vagues et guitare', '🌊', 'Calme', 34286),
  StudioTrack('nuit', 'Nuit douce', '🌙', 'Nuit', 32000),
  StudioTrack('berceuse', 'Berceuse', '👶', 'Douceur', 30000),
  StudioTrack('oud', 'Oud doux', '🕌', 'Spirituel', 36000),
  StudioTrack('tension', 'Suspense', '😱', 'Tension', 32000),
];

StudioTrack? studioTrack(String? id) {
  for (final t in kStudioTracks) {
    if (t.id == id) return t;
  }
  return null;
}

/// Musique choisie pour un montage.
class MontageMusic {
  MontageMusic.free(StudioTrack t)
      : type = 'free',
        id = t.id,
        title = t.title,
        subtitle = 'Musique Afrolook · gratuite',
        url = null,
        artistId = null,
        useCoins = 0,
        paid = false,
        durationMs = t.durationMs,
        coverUrl = null;

  MontageMusic.artist(ArtistSound s)
      : type = 'artist',
        id = s.id,
        title = s.title,
        subtitle = '@${s.userPseudo}${s.genre != null && s.genre!.isNotEmpty ? ' · ${s.genre}' : ''}',
        url = s.previewUrl, // extrait de 30 s : l'original n'est jamais exposé
        artistId = s.userId,
        useCoins = s.unitPrice,
        paid = !s.isFree,
        durationMs = s.previewSec * 1000,
        coverUrl = s.coverImageUrl;

  final String type;
  final String id;
  final String title;
  final String subtitle;
  final String? url;
  final String? artistId;
  final String? coverUrl;

  /// Durée de l'extrait disponible (millisecondes) : la piste gratuite entière, ou l'extrait public de 30 s d'un son d'artiste.
  final int durationMs;

  /// Son d'artiste payant (la personne paie, l'artiste gagne).
  final bool paid;

  /// Prix d'utilisation dans le Studio (pièces) et part de l'artiste (60 %).
  final int useCoins;
  int get shareCoins => (useCoins * 60) ~/ 100;

  bool get isArtist => type == 'artist';
}

/// Lecture d'aperçu (une seule à la fois dans l'app).
class MontageMusicPlayer {
  MontageMusicPlayer._();
  static final AudioPlayer _player = AudioPlayer();
  static final Map<String, String> _urls = {};
  static String? playingKey;

  static Future<String?> urlOf(MontageMusic m) async {
    if (m.url != null) return m.url;
    if (m.isArtist) return null;
    final key = 'free:${m.id}';
    if (_urls[key] != null) return _urls[key];
    try {
      final u = MediaCdn.url(await FirebaseStorage.instance.ref('studio_music/${m.id}.m4a').getDownloadURL());
      _urls[key] = u;
      return u;
    } catch (_) {
      return null;
    }
  }

  /// Joue [m] en boucle à partir de [startMs]. Renvoie false si la musique n'a pas pu être chargée.
  static Future<bool> play(MontageMusic m, {int startMs = 0}) async {
    final url = await urlOf(m);
    if (url == null) return false;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(UrlSource(url), position: Duration(milliseconds: startMs));
      playingKey = '${m.type}:${m.id}';
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    playingKey = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<Duration?> duration() async {
    try {
      return await _player.getDuration();
    } catch (_) {
      return null;
    }
  }
}

/// Choix de la musique : pistes gratuites, sons des artistes, ou aucune. Renvoie null si on ferme sans choisir,
/// et un [MusicPick] sinon (music == null : « Sans musique »).
class MusicPick {
  const MusicPick(this.music);
  final MontageMusic? music;
}

Future<MusicPick?> showMontageMusicPicker(BuildContext context, {MontageMusic? current, required VoidCallback onArtistCta}) async {
  await ArtistSoundPricing.load();
  if (!context.mounted) return null;
  final r = await showModalBottomSheet<MusicPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => _MusicSheet(current: current, onArtistCta: onArtistCta),
  );
  await MontageMusicPlayer.stop();
  return r;
}

class _MusicSheet extends StatefulWidget {
  const _MusicSheet({required this.current, required this.onArtistCta});
  final MontageMusic? current;
  final VoidCallback onArtistCta;

  @override
  State<_MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<_MusicSheet> {
  String? _playing;
  String? _loading;

  Future<void> _toggle(MontageMusic m) async {
    final key = '${m.type}:${m.id}';
    if (_playing == key) {
      await MontageMusicPlayer.stop();
      if (mounted) setState(() => _playing = null);
      return;
    }
    setState(() => _loading = key);
    final ok = await MontageMusicPlayer.play(m);
    if (!mounted) return;
    setState(() {
      _loading = null;
      _playing = ok ? key : null;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire ce son. Vérifie ta connexion.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        maxChildSize: .95,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(children: [
              Expanded(child: Text('Musique', style: TextStyle(color: _c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, const MusicPick(null)),
                icon: Icon(Icons.music_off_rounded, size: 18, color: _c.textSecondary),
                label: Text('Sans musique', style: TextStyle(color: _c.textSecondary, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          TabBar(
            labelColor: _c.accent,
            unselectedLabelColor: _c.textSecondary,
            indicatorColor: _c.accent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: const [Tab(text: '🎵 Gratuites'), Tab(text: '🎤 Artistes')],
          ),
          Expanded(
            child: TabBarView(children: [
              ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
                for (final t in kStudioTracks) _row(MontageMusic.free(t), leading: _emojiBox(t.emoji), trailing: Text(t.mood, style: TextStyle(color: _c.textSecondary, fontSize: 11.5))),
              ]),
              _artists(ctrl),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _emojiBox(String e) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _c.background, borderRadius: BorderRadius.circular(10)),
        child: Text(e, style: const TextStyle(fontSize: 22)),
      );

  Widget _row(MontageMusic m, {required Widget leading, Widget? trailing, VoidCallback? onReport}) {
    final key = '${m.type}:${m.id}';
    final selected = widget.current?.type == m.type && widget.current?.id == m.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selected ? _c.primary.withValues(alpha: .14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _c.primary : Colors.transparent),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: leading,
        title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(m.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textSecondary, fontSize: 11.5)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (trailing != null) trailing,
          if (onReport != null)
            IconButton(tooltip: 'Signaler ce son', visualDensity: VisualDensity.compact, onPressed: onReport, icon: Icon(Icons.flag_outlined, size: 19, color: _c.textSecondary)),
          IconButton(
            onPressed: () => _toggle(m),
            icon: _loading == key
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _c.primary))
                : Icon(_playing == key ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: _c.primary, size: 30),
          ),
        ]),
        onTap: () => Navigator.pop(context, MusicPick(m)),
      ),
    );
  }

  /// Liste des sons d'artistes : une lecture (100 documents au plus) gardée 10 minutes, au lieu d'une écoute en direct à chaque ouverture.
  static Future<QuerySnapshot>? _artistsFuture;
  static DateTime? _artistsAt;
  static Future<QuerySnapshot> _loadArtists() {
    final at = _artistsAt;
    if (_artistsFuture != null && at != null && DateTime.now().difference(at) < const Duration(minutes: 10)) return _artistsFuture!;
    _artistsAt = DateTime.now();
    final f = FirebaseFirestore.instance
        .collection('artist_sounds')
        .where('status', isEqualTo: 'validated')
        .orderBy('validatedAt', descending: true)
        .limit(100)
        .get();
    f.then((_) {}, onError: (Object _) {
      _artistsFuture = null; // échec : on réessaiera à la prochaine ouverture
      _artistsAt = null;
    });
    return _artistsFuture = f;
  }

  Widget _artists(ScrollController ctrl) {
    return FutureBuilder<QuerySnapshot>(
      future: _loadArtists(),
      builder: (_, snap) {
        final docs = SoundCountries.forViewer<ArtistSound>(
          [for (final d in snap.data?.docs ?? const <QueryDocumentSnapshot>[]) ArtistSound.fromMap(d.data() as Map<String, dynamic>, d.id)],
          countries: (s) => s.availableCountries,
          owner: (s) => s.userId,
          viewerCountry: SoundCountries.viewerCountry(context),
        );
        return ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
          _ArtistCta(onTap: () {
            Navigator.pop(context);
            widget.onArtistCta();
          }),
          const SizedBox(height: 10),
          if (!snap.hasData && !snap.hasError) Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: _c.primary))),
          if (snap.hasData && docs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Aucun son d’artiste pour l’instant. Les premiers artistes arrivent bientôt !', textAlign: TextAlign.center, style: TextStyle(color: _c.textSecondary)),
            ),
          for (final s in docs)
            Builder(builder: (_) {
              return _row(
                MontageMusic.artist(s),
                onReport: s.userId == FirebaseAuth.instance.currentUser?.uid ? null : () => reportArtistSound(context, s.id, s.title),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: s.coverImageUrl != null
                      ? CachedNetworkImage(imageUrl: s.coverImageUrl!, width: 44, height: 44, fit: BoxFit.cover)
                      : _emojiBox('🎤'),
                ),
                trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: s.isFree ? const Color(0x332ECC71) : const Color(0x33FFD400), borderRadius: BorderRadius.circular(99)),
                    child: Text(s.isFree ? 'Gratuit' : '🪙 ${s.unitPrice}', style: TextStyle(color: s.isFree ? const Color(0xFF2ECC71) : const Color(0xFFFFD400), fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 3),
                  StreamsText(track: MusicTrack.fromSound(s), color: _c.textSecondary, fontSize: 10),
                ]),
              );
            }),
        ]);
      },
    );
  }
}

/// Encadré « Tu es artiste ? » : mène à la page où l'artiste dépose ses sons et suit ses gains.
class _ArtistCta extends StatelessWidget {
  const _ArtistCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Text('🎤', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tu es artiste ? Propose ton son', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text('Gratuit ou payant, c’est toi qui choisis. Payant : tu touches 60 % de chaque utilisation et vente.',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }
}

/// Ouvre l'espace artiste (dépôt des sons, suivi des utilisations et des gains).
void openArtistSpace(BuildContext context) {
  unawaited(MontageMusicPlayer.stop());
  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyArtistSoundsPage()));
}
