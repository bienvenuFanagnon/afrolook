import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/live_stage.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:flutter/material.dart';

const _amber = Color(0xFFF9A825);
const _yellow = Color(0xFFFFE14D);

/// Pastille ronde avec les initiales (ou la photo) d'une personne.
class StageAvatar extends StatelessWidget {
  const StageAvatar({super.key, required this.user, this.size = 30, this.ring = false});

  final StageUser user;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final colors = [const Color(0xFF2ECC71), const Color(0xFF5B9CFA), const Color(0xFFFF9248), const Color(0xFFB57BFF)];
    final c = colors[user.id.hashCode.abs() % colors.length];
    final url = user.avatarUrl;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        boxShadow: ring ? const [BoxShadow(color: Color(0xFF69F0AE), spreadRadius: 2)] : null,
        image: url != null && url.isNotEmpty ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover, onError: (_, __) {}) : null,
      ),
      child: url != null && url.isNotEmpty ? null : Text(user.initials, style: TextStyle(color: const Color(0xFF0E0E0E), fontSize: size * .37, fontWeight: FontWeight.w700)),
    );
  }
}

/// La scène : les invités en vidéo forment une bande (82 × 110), les invités en audio sont dessous ; l'hôte reste en plein écran.
class LiveStageStrip extends StatelessWidget {
  const LiveStageStrip({
    super.key,
    required this.stage,
    required this.isHost,
    required this.videoTile,
    required this.onRemove,
    required this.onFreeSlot,
    this.myUserId,
  });

  final LiveStageState stage;
  final bool isHost;
  final String? myUserId;

  /// Construit la vidéo d'une personne sur scène (la mienne ou celle d'un autre) ; `null` tant que sa vidéo n'est pas arrivée.
  final Widget? Function(StageSpeaker s) videoTile;
  final void Function(StageSpeaker s) onRemove;
  final VoidCallback onFreeSlot;

  @override
  Widget build(BuildContext context) {
    final video = stage.videoSpeakers;
    final audio = stage.audioSpeakers;
    final freeVideo = (stage.maxVideo - stage.usedVideo).clamp(0, 6);
    if (video.isEmpty && audio.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.tr('Sur scène').toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6, color: _yellow)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final s in video) ...[
              _Tile(
                label: '@${s.user.username}',
                video: videoTile(s),
                onRemove: isHost || s.user.id == myUserId ? () => onRemove(s) : null,
                color: Color(0xFF4A5D7A + (s.user.id.hashCode.abs() % 0x303030)).withOpacity(1),
              ),
              const SizedBox(width: 10),
            ],
            if (isHost && freeVideo > 0 && stage.enabled)
              GestureDetector(
                onTap: onFreeSlot,
                child: Container(
                  width: 82,
                  height: 110,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white30, width: 2)),
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded, color: Colors.white70, size: 22),
                    const SizedBox(height: 4),
                    Text(context.tr('Place libre'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          if (audio.isNotEmpty) ...[
            Text(context.tr('En audio'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(width: 8),
            for (final s in audio) ...[
              GestureDetector(
                onLongPress: isHost || s.user.id == myUserId ? () => onRemove(s) : null,
                child: StageAvatar(user: s.user, ring: true),
              ),
              const SizedBox(width: 8),
            ],
          ],
          Flexible(child: Text(stage.placesLabel.replaceAll('vidéo', context.tr('vidéo')).replaceAll('audio', context.tr('audio')), style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
        ]),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.video, required this.color, this.onRemove});

  final String label;
  final Widget? video;
  final Color color;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 110,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, const Color(0xFF1A1A1A)]),
      ),
      child: Stack(children: [
        if (video != null) Positioned.fill(child: video!),
        Positioned(
          left: 5,
          bottom: 5,
          right: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(7)),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 14)),
            ),
          ),
      ]),
    );
  }
}

/// « Demander à monter sur scène » : vidéo ou audio, prix de la place, solde. Renvoie le choix (`video` ou `audio`) ou `null`.
Future<String?> showRaiseHandSheet(
  BuildContext context, {
  required String hostName,
  required int placeCoins,
  required int depot,
  required int earned,
  required bool videoFull,
  required bool audioFull,
}) {
  var media = videoFull && !audioFull ? 'audio' : 'video';
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      Widget choice(String key, String title, String sub, bool full) {
        final on = media == key;
        return Expanded(
          child: GestureDetector(
            onTap: full ? null : () => setSheet(() => media = key),
            child: Opacity(
              opacity: full ? .4 : 1,
              child: Container(
                height: 62,
                decoration: BoxDecoration(color: on ? const Color(0xFF2A2312) : const Color(0xFF242424), borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? _amber : const Color(0xFF2F2F2F), width: 2)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(full ? ctx.tr('Complet') : sub, style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12)),
                ]),
              ),
            ),
          ),
        );
      }

      final paid = placeCoins > 0;
      return Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(ctx).padding.bottom + 22),
        decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4A4A46), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text(ctx.tr('Demander à monter sur scène'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(ctx.tr('Tu seras vu et entendu par tous les spectateurs. {h} doit accepter ta demande.', {'h': hostName}), style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 14, height: 1.45)),
          const SizedBox(height: 13),
          Row(children: [
            choice('video', ctx.tr('Vidéo'), ctx.tr('Caméra et micro'), videoFull),
            const SizedBox(width: 8),
            choice('audio', ctx.tr('Audio'), ctx.tr('Micro seul'), audioFull),
          ]),
          if (paid) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.stars_rounded, color: _amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ctx.tr('Place sur scène : {p} pièces', {'p': CoinCheckout.fmt(placeCoins)}), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(ctx.tr('Prix actuel d\'une place de participant. Débité seulement si l\'hôte accepte ; rien si l\'hôte refuse ou ne répond pas en 2 min.'),
                        style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 13),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(ctx.tr('Ton solde (dépôt · gagnées)'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 13)),
              Text('${CoinCheckout.fmt(depot)} · ${CoinCheckout.fmt(earned)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ],
          const SizedBox(height: 13),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: (media == 'video' && videoFull) || (media == 'audio' && audioFull) ? null : () => Navigator.pop(ctx, media),
              style: ElevatedButton.styleFrom(backgroundColor: _amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
              child: Text(
                paid ? ctx.tr('Demander ({p} pièces)', {'p': CoinCheckout.fmt(placeCoins)}) : ctx.tr('Demander à monter'),
                style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]),
      );
    }),
  );
}

/// Panneau « Participants » : à droite, 70 % de la largeur, fond noir, bordure ambre. Pour l'hôte : demandes, personnes sur scène, spectateurs à inviter.
class LiveParticipantsPanel extends StatelessWidget {
  const LiveParticipantsPanel({
    super.key,
    required this.stage,
    required this.isHost,
    required this.viewers,
    required this.totalCount,
    required this.onClose,
    required this.onDecide,
    required this.onInvite,
    required this.onRemove,
  });

  final LiveStageState stage;
  final bool isHost;

  /// Spectateurs présents (hors hôte et personnes sur scène).
  final List<StageUser> viewers;
  final int totalCount;
  final VoidCallback onClose;
  final void Function(StageRequest r, bool accept) onDecide;
  final void Function(StageUser u, String media) onInvite;
  final void Function(StageSpeaker s) onRemove;

  @override
  Widget build(BuildContext context) {
    Widget sec(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .7, color: _amber)),
        );
    Widget row(Widget avatar, Widget body, List<Widget> actions) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF212121), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [avatar, const SizedBox(width: 8), Expanded(child: body), ...actions]),
        );
    Widget small(String label, Color c, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(.8))),
            child: Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        );
    Widget round(IconData icon, bool filled, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: filled ? _amber : Colors.transparent, border: filled ? null : Border.all(color: Colors.white30)),
            child: Icon(icon, size: 16, color: filled ? Colors.black : Colors.white),
          ),
        );

    final canInvite = isHost && stage.enabled;
    return Positioned(
      top: 100,
      right: 16,
      bottom: 100,
      width: MediaQuery.of(context).size.width * 0.7,
      child: Container(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: _amber)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${context.tr('Participants')} ($totalCount)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: onClose),
            ]),
          ),
          if (stage.enabled)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              width: double.infinity,
              decoration: BoxDecoration(color: _amber.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
              child: Text(
                context.tr('Places : vidéo {a} sur {b} · audio {c} sur {d}', {'a': '${stage.usedVideo}', 'b': '${stage.maxVideo}', 'c': '${stage.usedAudio}', 'd': '${stage.maxAudio}'}),
                style: const TextStyle(fontSize: 11.5, color: _amber, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              if (isHost && stage.requests.isNotEmpty) ...[
                sec('${context.tr('Demandes')} · ${stage.requests.length}'),
                for (final r in stage.requests)
                  if (r.user != null)
                    row(
                      StageAvatar(user: r.user!),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('@${r.user!.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(
                          r.coins > 0
                              ? '${r.media == 'video' ? context.tr('Vidéo') : context.tr('Audio')} · ${context.tr('{p} pcs à la validation', {'p': CoinCheckout.fmt(r.coins)})}'
                              : '${context.tr('Veut monter')} · ${r.media == 'video' ? context.tr('vidéo') : context.tr('audio')}',
                          style: TextStyle(color: r.coins > 0 ? const Color(0xFF69F0AE) : const Color(0xFF9A9A95), fontSize: 10, fontWeight: r.coins > 0 ? FontWeight.w700 : FontWeight.w400),
                        ),
                      ]),
                      [round(Icons.check_rounded, true, () => onDecide(r, true)), round(Icons.close_rounded, false, () => onDecide(r, false))],
                    ),
              ],
              if (stage.speakers.isNotEmpty) ...[
                sec('${context.tr('Sur scène')} · ${stage.speakers.length}'),
                for (final s in stage.speakers)
                  row(
                    StageAvatar(user: s.user),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '@${s.user.username} ', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      TextSpan(text: '· ${s.isVideo ? context.tr('Vidéo') : context.tr('Audio')}', style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 10)),
                    ]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    [if (isHost) small(context.tr('Retirer'), const Color(0xFFFF6B6F), () => onRemove(s))],
                  ),
              ],
              sec('${context.tr('Spectateurs')} · ${viewers.length}'),
              for (final v in viewers)
                row(
                  StageAvatar(user: v),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '@${v.username} ', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    TextSpan(text: '· ${context.tr('Spectateur')}', style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 10)),
                  ]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  [
                    if (canInvite && !stage.invited.contains(v.id))
                      small(context.tr('Inviter'), _amber, () => onInvite(v, stage.videoFull ? 'audio' : 'video'))
                    else if (canInvite)
                      Text(context.tr('Invité'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 10)),
                  ],
                ),
              const SizedBox(height: 8),
            ]),
          ),
          if (isHost && stage.enabled)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
              child: Text(context.tr('Un spectateur qui lève la main apparaît dans « Demandes ». « Inviter » lui envoie une invitation qu\'il accepte ou refuse.'),
                  style: const TextStyle(fontSize: 10.5, height: 1.4, color: Color(0xFF9A9A95))),
            ),
        ]),
      ),
    );
  }
}
