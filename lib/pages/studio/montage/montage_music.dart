import 'package:afrotok/services/api/api_identity.dart';
// Musique des templates : pistes gratuites d'Afrolook (Storage studio_music/{id}.m4a, créées par
// functions/scripts/gen_studio_music.cjs, sans droits d'auteur) et sons des artistes validés (payants, l'artiste est payé).

import 'dart:async';
import 'package:afrotok/l10n/tr.dart';
import '../../../services/music_clip.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api/music_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/music_queue.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/music/streams_text.dart';
import '../../../widgets/music/music_like.dart';
import '../artist_marketplace.dart';
import '../../../utils/media_cdn.dart';
import '../artist_sound_common.dart';
import '../sound_countries.dart';
import '../studio_theme.dart';
import 'studio_track.dart';
export 'studio_track.dart';

AppColors get _c => studioColors;


/// Pistes gratuites (durées réelles des fichiers envoyés dans Storage).
final List<StudioTrack> kStudioTracks = <StudioTrack>[
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
  ...kLibreTracks,
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
        subtitle = t.credit == null ? 'Musique Afrolook · gratuite' : 'Musique libre · ${t.credit}',
        url = null,
        artistId = null,
        useCoins = 0,
        paid = false,
        usable = true,
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
        usable = s.hasOriginal,
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

  /// Faux : le titre s'écoute mais ne peut pas encore servir dans un montage (son original pas encore migré) : « bientôt disponible », jamais choisi puis refusé par le serveur.
  final bool usable;

  /// Prix d'utilisation dans le Studio (pièces) et part de l'artiste (60 %).
  final int useCoins;
  int get shareCoins => (useCoins * 60) ~/ 100;

  bool get isArtist => type == 'artist';
}

/// Lecture d'aperçu (une seule à la fois dans l'app).
class MontageMusicPlayer {
  MontageMusicPlayer._();
  static final AudioPlayer _player = AudioPlayer();
  static final Map<String, ({String url, DateTime at})> _urls = {};   // le lien d'écoute dure une heure : on le garde 50 minutes
  static String? playingKey;

  /// Numéro de la lecture en cours : tout `stop()` (page quittée, autre musique) l'invalide, et une lecture dont le chargement finit APRÈS ne démarre plus (sinon la musique continuait après la sortie du montage).
  static int _gen = 0;

  static Future<String?> urlOf(MontageMusic m) async {
    if (m.url != null) return m.url;
    if (m.isArtist) return null;
    final key = 'free:${m.id}';
    final hit = _urls[key];
    if (hit != null && DateTime.now().difference(hit.at) < const Duration(minutes: 50)) return hit.url;
    try {
      // Musiques gratuites d'Afrolook : adresse donnée par l'API (lien valable une heure)
      final u = MediaCdn.url(await MusicApi.freeTrackUrl(m.id));
      _urls[key] = (url: u, at: DateTime.now());
      return u;
    } catch (_) {
      return null;
    }
  }

  /// Joue [m] en boucle à partir de [startMs]. Renvoie false si la musique n'a pas pu être chargée.
  static Future<bool> play(MontageMusic m, {int startMs = 0, double volume = 1}) async {
    final g = ++_gen;
    final url = await urlOf(m);
    if (url == null || g != _gen) return false;
    try {
      _clipTimer?.cancel();
      _clipMode = false;
      await _player.stop();
      if (g != _gen) return false;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.play(UrlSource(url), position: Duration(milliseconds: startMs));
      if (g != _gen) {
        await _player.stop();   // la page a été quittée pendant le chargement
        return false;
      }
      playingKey = '${m.type}:${m.id}';
      return true;
    } catch (e) {
      debugPrint('Aperçu de la musique impossible : $e');   // visible dans la console : la cause d'un silence
      return false;
    }
  }

  static Timer? _clipTimer;
  static final Stopwatch _clipWatch = Stopwatch();
  static double _clipVolume = 1;
  static bool _clipMode = false;

  /// Joue [m] EXACTEMENT comme le serveur le mettra sur le film : de [MusicClipPlan.startMs], pendant la durée du film, avec le fondu d'entrée et le fondu de sortie, répété
  /// s'il est plus court, coupé s'il est plus long ; puis l'aperçu recommence. Renvoie false si la musique n'a pas pu être chargée.
  static Future<bool> playClip(MontageMusic m, MusicClipPlan plan, {double volume = 1}) async {
    final g = ++_gen;
    final url = await urlOf(m);
    if (url == null || g != _gen) return false;
    try {
      _clipTimer?.cancel();
      await _player.stop();
      if (g != _gen) return false;
      await _player.setReleaseMode(ReleaseMode.stop);
      _clipVolume = volume.clamp(0.0, 1.0);
      _clipMode = true;
      await _player.setVolume(0);
      await _player.play(UrlSource(url), position: Duration(milliseconds: plan.startMs));
      if (g != _gen) {
        await _player.stop();   // la page a été quittée pendant le chargement
        _clipMode = false;
        return false;
      }
      playingKey = '${m.type}:${m.id}';
      _clipWatch
        ..reset()
        ..start();
      _clipTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        try {
          final e = _clipWatch.elapsedMilliseconds;
          if (e >= plan.clipMs) {
            // fin du film : l'aperçu recommence au début du son
            _clipWatch
              ..reset()
              ..start();
            await _player.setVolume(0);
            await _player.seek(Duration(milliseconds: plan.startMs));
            await _player.resume();
            return;
          }
          await _player.setVolume((plan.volumeAt(e) * _clipVolume).clamp(0.0, 1.0));
          // son plus court que le film : on revient à son point de départ, comme le serveur répète le son
          if (plan.loops && plan.trackMs != null) {
            final pos = await _player.getCurrentPosition();
            if (pos != null && pos.inMilliseconds >= plan.trackMs! - 120) await _player.seek(Duration(milliseconds: plan.startMs));
          }
        } catch (_) {}
      });
      return true;
    } catch (e) {
      debugPrint('Aperçu de la musique impossible : $e');
      return false;
    }
  }

  /// Volume de l'aperçu (0 à 1), appliqué tout de suite si la musique joue.
  static Future<void> setVolume(double v) async {
    _clipVolume = v.clamp(0.0, 1.0);
    if (_clipMode) return;   // en lecture « film », le volume est recalculé toutes les 100 ms avec les fondus
    try {
      await _player.setVolume(v.clamp(0.0, 1.0));
    } catch (_) {}
  }

  static Future<void> stop() async {
    _gen++;   // une lecture en cours de chargement ne démarrera plus
    playingKey = null;
    _clipTimer?.cancel();
    _clipTimer = null;
    _clipMode = false;
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

/// Sons d'artistes validés (une lecture, gardée 10 minutes) : partagée avec la musique des chroniques.
Future<List<ArtistSound>> loadArtistSounds() => _MusicSheetState._loadArtists();

/// Choix de la musique : pistes gratuites, sons des artistes, ou aucune. Renvoie null si on ferme sans choisir,
/// et un [MusicPick] sinon (music == null : « Sans musique »).
class MusicPick {
  const MusicPick(this.music, {this.keepVideoAudio = false});
  final MontageMusic? music;

  /// « Garder le son de ma vidéo » (proposé seulement pour une vidéo) : la voix de la vidéo est mélangée à la musique.
  final bool keepVideoAudio;
}

Future<MusicPick?> showMontageMusicPicker(BuildContext context, {MontageMusic? current, required VoidCallback onArtistCta, bool offerKeepAudio = false}) async {
  await ArtistSoundPricing.load();
  if (!context.mounted) return null;
  // le fond de la feuille et les textes viennent du MÊME thème (clair ou sombre) : sans cela, le fond restait sombre alors que les textes passaient en sombre aussi (illisible)
  syncStudioColors(context);
  final r = await showModalBottomSheet<MusicPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => _MusicSheet(current: current, onArtistCta: onArtistCta, offerKeepAudio: offerKeepAudio),
  );
  await MontageMusicPlayer.stop();
  return r;
}

class _MusicSheet extends StatefulWidget {
  const _MusicSheet({required this.current, required this.onArtistCta, this.offerKeepAudio = false});
  final MontageMusic? current;
  final VoidCallback onArtistCta;
  final bool offerKeepAudio;

  @override
  State<_MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<_MusicSheet> {
  String? _playing;
  String? _loading;
  bool _keepAudio = false;
  String? _group;   // catégorie choisie (null = toutes)
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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

  /// Recherche d'une musique gratuite par titre, catégorie ou ambiance.
  Widget _searchField() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          key: const ValueKey('music_search'),
          controller: _search,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: _c.textPrimary, fontSize: 14),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: tr('Rechercher une musique'),
            hintStyle: TextStyle(color: _c.textSecondary),
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, color: _c.textSecondary, size: 20),
            suffixIcon: _search.text.isEmpty ? null : IconButton(icon: Icon(Icons.close_rounded, size: 18, color: _c.textSecondary), onPressed: () => setState(_search.clear)),
            filled: true,
            fillColor: _c.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      );

  /// Catégories des musiques gratuites : un clic ne montre que celle-là (courage, amour, Noël…).
  Widget _groupChips() {
    final groups = <String>[...kStudioGroups.where((g) => kStudioTracks.any((t) => t.section == g)), ...{for (final t in kStudioTracks) if (!kStudioGroups.contains(t.section)) t.section}];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final g in [null, ...groups])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('music_group_${g ?? "all"}'),
                label: Text(g == null ? tr('Toutes') : tr(g)),
                selected: _group == g,
                selectedColor: _c.accent,
                labelStyle: TextStyle(color: _group == g ? Colors.black : _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
                onSelected: (_) => setState(() => _group = g),
              ),
            ),
        ]),
      ),
    );
  }

  /// Crédits exigés par la licence des musiques libres de droits (Creative Commons Attribution 4.0).
  void _showCredits() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _c.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(tr('Crédits musique'), style: TextStyle(color: _c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(kLibreCredit, style: TextStyle(color: _c.textSecondary, height: 1.4)),
            const SizedBox(height: 10),
            Text(tr('Titres concernés :'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text([for (final t in kStudioTracks) if (t.libre) t.title].join(' · '), style: TextStyle(color: _c.textSecondary, fontSize: 12.5, height: 1.4)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    syncStudioColors(context);
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
          if (widget.offerKeepAudio)
            SwitchListTile(
              key: const ValueKey('keep_video_audio'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              activeColor: _c.accent,
              title: Text(tr('Garder le son de ma vidéo'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text(_keepAudio ? tr('Ta voix et la musique sont mélangées.') : tr('Le son de ta vidéo est coupé, seule la musique reste.'), style: TextStyle(color: _c.textSecondary, fontSize: 12)),
              value: _keepAudio,
              onChanged: (v) => setState(() => _keepAudio = v),
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
                _searchField(),
                _groupChips(),
                if (filterStudioTracks(kStudioTracks, query: _search.text, group: _group).isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 28), child: Center(child: Text(tr('Aucune musique ne correspond.'), style: TextStyle(color: _c.textSecondary)))),
                for (final t in filterStudioTracks(kStudioTracks, query: _search.text, group: _group))
                  _row(MontageMusic.free(t), leading: _emojiBox(t.emoji), trailing: Text(t.voice ? '🎤 ${tr(t.section)}' : tr(t.section), style: TextStyle(color: _c.textSecondary, fontSize: 11.5))),
                if (kStudioTracks.any((t) => t.libre))
                  Center(child: TextButton(key: const ValueKey('music_credits'), onPressed: _showCredits, child: Text(tr('Crédits musique'), style: TextStyle(color: _c.textSecondary, fontSize: 12.5)))),
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
        subtitle: Text(m.usable ? m.subtitle : '${m.subtitle} · bientôt disponible', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textSecondary, fontSize: 11.5)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!m.usable)
            Container(
              key: const ValueKey('music_soon'),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _c.textSecondary.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
              child: Text('Bientôt', style: TextStyle(color: _c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
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
        onTap: () {
          if (!m.usable) {
            // écoutable, mais pas encore utilisable dans un montage : on le dit tout de suite, au lieu d'un échec du serveur après l'attente
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce titre sera bientôt disponible pour les montages. Tu peux déjà l\u2019écouter ; choisis un autre titre ou une musique gratuite.')));
            return;
          }
          Navigator.pop(context, MusicPick(m, keepVideoAudio: _keepAudio));
        },
      ),
    );
  }

  /// Liste des sons d'artistes : une lecture (100 documents au plus) gardée 10 minutes, au lieu d'une écoute en direct à chaque ouverture.
  static Future<List<ArtistSound>> _loadArtists() => MusicApi.latestCached();

  Widget _artists(ScrollController ctrl) {
    return FutureBuilder<List<ArtistSound>>(
      future: _loadArtists(),
      builder: (_, snap) {
        final docs = SoundCountries.forViewer<ArtistSound>(
          snap.data ?? const <ArtistSound>[],
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
                onReport: s.userId == ApiIdentity.myId ? null : () => reportArtistSound(context, s.id, s.title),
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
                  Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: StreamsText(track: MusicTrack.fromSound(s), color: _c.textSecondary, fontSize: 10)), const SizedBox(width: 6), Flexible(child: MusicLikeButton(track: MusicTrack.fromSound(s), color: _c.textSecondary, fontSize: 10))]),
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
    syncStudioColors(context);
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
