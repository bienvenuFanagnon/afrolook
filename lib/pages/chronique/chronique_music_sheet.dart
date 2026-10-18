import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../studio/montage/montage_music.dart';
import 'chronique_music.dart';

String _mmss(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Réglage de la musique d'une chronique : extrait (5 à 30 s), volume, et pour une vidéo garder ou non son son d'origine.
/// Renvoie true quand la personne valide ; [music] est modifié sur place.
Future<bool?> showChroniqueMusicOptions(BuildContext context, MontageMusic source, ChroniqueMusic music, {required bool isVideo}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _OptionsSheet(source: source, music: music, isVideo: isVideo),
  );
  await MontageMusicPlayer.stop();
  return r;
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({required this.source, required this.music, required this.isVideo});
  final MontageMusic source;
  final ChroniqueMusic music;
  final bool isVideo;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  bool _playing = false;

  ChroniqueMusic get m => widget.music;

  Future<void> _togglePlay() async {
    if (_playing) {
      await MontageMusicPlayer.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final ok = await MontageMusicPlayer.play(widget.source, startMs: m.startMs);
    if (mounted) setState(() => _playing = ok);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final maxSpan = m.durationMs < ChroniqueMusic.maxClipMs ? m.durationMs : ChroniqueMusic.maxClipMs;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text('Régler la musique', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(children: [
              IconButton.filled(
                onPressed: _togglePlay,
                style: IconButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
                icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                  Text(m.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (m.coins > 0 ? c.accent : c.primary).withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(m.coins > 0 ? '🪙 ${m.coins}' : 'Gratuit', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 14),
            Text('Extrait : ${_mmss(m.startMs)} à ${_mmss(m.endMs)} (${(m.clipMs / 1000).round()} s)',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            RangeSlider(
              values: RangeValues(m.startMs.toDouble(), m.endMs.toDouble()),
              min: 0,
              max: m.durationMs.toDouble(),
              activeColor: c.primary,
              onChanged: (v) {
                setState(() {
                  var s = v.start.round();
                  var e = v.end.round();
                  if (e - s > maxSpan) {
                    // la poignée qui bouge pousse l'autre pour garder 30 s au plus
                    if ((s - m.startMs).abs() > (e - m.endMs).abs()) {
                      e = s + maxSpan;
                    } else {
                      s = e - maxSpan;
                    }
                  }
                  m.startMs = s;
                  m.endMs = e;
                  m.clamp();
                });
              },
            ),
            Text('Entre 5 et 30 secondes, lu en boucle pendant que la chronique s\'affiche.', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.volume_up_rounded, size: 18, color: c.textSecondary),
              Expanded(
                child: Slider(value: m.volume, min: .1, max: 1, activeColor: c.primary, onChanged: (v) => setState(() => m.volume = v)),
              ),
              SizedBox(width: 40, child: Text('${(m.volume * 100).round()} %', style: TextStyle(color: c.textSecondary, fontSize: 12))),
            ]),
            if (widget.isVideo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: m.keepVideoSound,
                activeColor: c.primary,
                onChanged: (v) => setState(() => m.keepVideoSound = v),
                title: Text('Garder le son de la vidéo', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(m.keepVideoSound ? 'Le son de la vidéo et la musique sont mélangés.' : 'La musique remplace le son de la vidéo.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ),
            if (m.coins > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text('${m.coins} pièces seront débitées à la publication. L\'artiste en reçoit 60 %.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Utiliser cette musique', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
