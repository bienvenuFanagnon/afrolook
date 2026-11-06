import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/api/studio_voice_api.dart';
import '../../theme/app_colors.dart';

/// Voix retenue : le fichier à publier et l'effet appliqué (null = voix d'origine, sans mention « Voix modifiée »).
class VoiceChoice {
  const VoiceChoice({required this.file, this.effect});
  final File file;
  final String? effect;
}

typedef VoiceUploader = Future<String> Function(File audio);
typedef VoiceRenderer = Future<File> Function(String uploadId, String effect);
typedef VoiceEffectsLoader = Future<List<VoiceEffect>> Function();

/// « Choisis ta voix » : la personne choisit un effet, le SERVEUR produit le vrai rendu, et elle l'ÉCOUTE avant de valider. Rien n'est publié sans qu'elle ait
/// entendu le résultat final ; elle peut essayer autant d'effets qu'elle veut (chaque rendu est gardé), ou revenir à sa propre voix.
/// L'effet n'imite jamais la voix d'une autre personne, et le fil indique « Voix modifiée ».
class VoiceEffectPage extends StatefulWidget {
  const VoiceEffectPage({
    super.key,
    required this.original,
    this.upload = StudioVoiceApi.upload,
    this.render = StudioVoiceApi.apply,
    this.loadEffects = StudioVoiceApi.effects,
    this.autoPlay = true,
  });

  final File original;
  final VoiceUploader upload;
  final VoiceRenderer render;
  final VoiceEffectsLoader loadEffects;

  /// Écoute automatique du rendu dès qu'il est prêt (désactivée dans les tests).
  final bool autoPlay;

  @override
  State<VoiceEffectPage> createState() => _VoiceEffectPageState();
}

class _VoiceEffectPageState extends State<VoiceEffectPage> {
  final _player = AudioPlayer();
  List<VoiceEffect> _effects = StudioVoiceApi.fallback;
  final Map<String, File> _rendered = {};
  String? _uploadId;
  String? _selected; // null = voix d'origine
  String? _busy;
  String? _error;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    widget.loadEffects().then((l) {
      if (mounted) setState(() => _effects = l);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  File get _current => _selected == null ? widget.original : (_rendered[_selected] ?? widget.original);

  Future<void> _select(String? effect) async {
    if (_busy != null) return;
    await _player.stop();
    if (effect == null || _rendered.containsKey(effect)) {
      setState(() {
        _selected = effect;
        _error = null;
      });
      if (widget.autoPlay) await _play();
      return;
    }
    setState(() {
      _busy = effect;
      _error = null;
    });
    try {
      _uploadId ??= await widget.upload(widget.original);
      _rendered[effect] = await widget.render(_uploadId!, effect);
      if (!mounted) return;
      setState(() {
        _selected = effect;
        _busy = null;
      });
      if (widget.autoPlay) await _play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = null;
          _error = context.tr('L\'effet n\'a pas pu être appliqué. Réessaie dans un instant.');
        });
      }
    }
  }

  Future<void> _play() async {
    await _player.stop();
    await _player.play(DeviceFileSource(_current.path));
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final name = _selected == null ? null : _effects.where((e) => e.id == _selected).map((e) => e.name).firstOrNull;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        title: Text(context.tr('Choisis ta voix'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Essaie un effet : tu écoutes le vrai résultat avant de publier.'), style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.4)),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _EffectChip(key: const ValueKey('effect_none'), label: context.tr('Ma voix'), selected: _selected == null && _busy == null, onTap: () => _select(null)),
                for (final e in _effects)
                  _EffectChip(
                    key: ValueKey('effect_${e.id}'),
                    label: context.tr(e.name),
                    selected: _selected == e.id && _busy == null,
                    busy: _busy == e.id,
                    onTap: () => _select(e.id),
                  ),
              ]),
              const SizedBox(height: 28),
              Center(
                child: Column(children: [
                  Text(
                    _busy != null
                        ? context.tr('Préparation de l\'effet…')
                        : (name == null ? context.tr('Ta voix, sans effet') : '${context.tr('Rendu final')} · $name'),
                    key: const ValueKey('voice_status'),
                    style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  InkResponse(
                    key: const ValueKey('voice_play_current'),
                    onTap: _busy != null ? null : _toggle,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _busy != null ? c.surfaceVariant : c.accent),
                      child: _busy != null
                          ? Padding(padding: const EdgeInsets.all(28), child: CircularProgressIndicator(strokeWidth: 3, color: c.textSecondary))
                          : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44, color: c.onAccent),
                    ),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Center(child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger, fontSize: 13))),
              ],
              const Spacer(),
              if (_selected != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(context.tr('Le post indiquera « Voix modifiée ».'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('voice_use'),
                  onPressed: _busy != null
                      ? null
                      : () async {
                          await _player.stop();
                          if (mounted) Navigator.of(context).pop(VoiceChoice(file: _current, effect: _selected));
                        },
                  style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(context.tr(_selected == null ? 'Garder ma voix' : 'Utiliser cette voix'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectChip extends StatelessWidget {
  const _EffectChip({super.key, required this.label, required this.selected, required this.onTap, this.busy = false});
  final String label;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surfaceVariant,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? c.accent : c.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (busy) Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary))),
          Text(label, style: TextStyle(color: selected ? c.onAccent : c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      ),
    );
  }
}
