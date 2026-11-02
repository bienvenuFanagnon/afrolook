import 'dart:async';
import 'dart:io';

import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/argent_upload.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Vocaux des spectateurs à l'hôte d'un live : 30 secondes au plus, 3 par spectateur, écoutés par l'hôte seul.
/// Le fichier part en privé (jamais d'adresse publique) ; le serveur l'efface 7 jours après la fin du live.
const int kLiveVoiceMaxSeconds = 30;

/// Bouton rond « micro » affiché au spectateur ; masqué si l'hôte a coupé l'option ou si les 3 vocaux sont envoyés.
class LiveVoiceButton extends StatefulWidget {
  const LiveVoiceButton({super.key, required this.liveId, this.onSent});
  final String liveId;

  /// Appelé après l'envoi : le live publie alors une ligne « vocal envoyé » dans son chat (visible de tous ; seul l'hôte peut l'écouter).
  final void Function(String noteId, int seconds)? onSent;

  @override
  State<LiveVoiceButton> createState() => _LiveVoiceButtonState();
}

class _LiveVoiceButtonState extends State<LiveVoiceButton> {
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await LivesApi.voiceStatus(widget.liveId);
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null || s['enabled'] != true) return const SizedBox.shrink();
    final can = s['can_send'] == true;
    return GestureDetector(
      onTap: () async {
        if (!can) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Tu as déjà envoyé tes 3 vocaux à cet hôte.'))));
          return;
        }
        final sent = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _RecordSheet(liveId: widget.liveId, remaining: (s['remaining'] as num?)?.toInt() ?? 0),
        );
        if (sent != null) {
          widget.onSent?.call('${sent['id']}', (sent['seconds'] as num?)?.toInt() ?? 0);
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
        child: Icon(Icons.mic_rounded, color: can ? Colors.white : Colors.white38, size: 20),
      ),
    );
  }
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({required this.liveId, required this.remaining});
  final String liveId;
  final int remaining;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  final AudioRecorder _rec = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  bool _recording = false;
  bool _sending = false;
  int _seconds = 0;
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _rec.hasPermission()) {
        _snack(context.tr('Autorise le micro pour enregistrer un vocal.'));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/live_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000), path: path);
      setState(() {
        _recording = true;
        _seconds = 0;
        _path = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _seconds = t.tick);
        if (t.tick >= kLiveVoiceMaxSeconds) _stop();   // 30 secondes au plus : arrêt automatique
      });
    } catch (_) {
      _snack(context.tr("Impossible d'enregistrer. Réessaie."));
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final p = await _rec.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _path = p;
    });
  }

  Future<void> _send() async {
    final p = _path;
    if (p == null || _sending) return;
    setState(() => _sending = true);
    try {
      final bytes = await File(p).readAsBytes();
      final uploadId = await ArgentUpload.bytes(bytes, contentType: 'audio/mp4', private: true);
      final r = await LivesApi.sendVoice(widget.liveId, uploadId, _seconds.clamp(1, kLiveVoiceMaxSeconds));
      try {
        await File(p).delete();
      } catch (_) {}
      if (!mounted) return;
      Navigator.pop(context, {'id': r['id'], 'seconds': _seconds.clamp(1, kLiveVoiceMaxSeconds)});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr("Vocal envoyé : l'hôte sera le seul à l'écouter."))));
    } on ApiException catch (e) {
      _snack(tr(e.message));
      if (mounted) setState(() => _sending = false);
    } catch (_) {
      _snack(context.tr("Envoi impossible. Réessaie."));
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr("Message vocal à l'hôte"), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            context.tr("{s} secondes au plus. Seul l'hôte peut l'écouter, personne d'autre dans le live. Il te reste {n} vocal(aux).", {'s': '$kLiveVoiceMaxSeconds', 'n': '${widget.remaining}'}),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 18),
          Text('0:${_seconds.toString().padLeft(2, '0')} / 0:$kLiveVoiceMaxSeconds', style: TextStyle(color: _recording ? Colors.redAccent : Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (_path == null)
            GestureDetector(
              onTap: _recording ? _stop : _start,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: _recording ? Colors.redAccent : const Color(0xFFF9A825), shape: BoxShape.circle),
                child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.black, size: 34),
              ),
            )
          else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                tooltip: context.tr('Réécouter'),
                onPressed: () => _player.play(DeviceFileSource(_path!)),
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: _sending ? null : () => setState(() => _path = null), child: Text(context.tr('Refaire'))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF9A825), foregroundColor: Colors.black),
                child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text(context.tr('Envoyer')),
              ),
            ]),
          const SizedBox(height: 8),
          Text(_recording ? context.tr('Touche pour arrêter') : (_path == null ? context.tr('Touche pour enregistrer') : ''), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
    );
  }
}

/// Boîte de réception de l'hôte : liste des vocaux reçus, écoute, ignorer, signaler (bloque l'auteur), activer/couper l'option.
Future<void> showLiveVoiceInbox(BuildContext context, String liveId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoiceInbox(liveId: liveId),
    );

class _VoiceInbox extends StatefulWidget {
  const _VoiceInbox({required this.liveId});
  final String liveId;

  @override
  State<_VoiceInbox> createState() => _VoiceInboxState();
}

class _VoiceInboxState extends State<_VoiceInbox> {
  final AudioPlayer _player = AudioPlayer();
  List<Map<String, dynamic>> _notes = [];
  bool _enabled = true;
  bool _loading = true;
  String? _playing;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await LivesApi.voiceNotes(widget.liveId);
      if (!mounted) return;
      setState(() {
        _enabled = r['enabled'] != false;
        _notes = List<Map<String, dynamic>>.from((r['notes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(Map<String, dynamic> n) async {
    try {
      if (_playing == n['id']) {
        await _player.stop();
        setState(() => _playing = null);
        return;
      }
      final url = await LivesApi.voiceListen('${n['id']}');
      await _player.play(UrlSource(url));
      if (mounted) {
        setState(() {
          _playing = '${n['id']}';
          n['status'] = 'heard';
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr("Écoute impossible. Réessaie."))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text(context.tr('Vocaux des spectateurs'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
            Text(context.tr('Autoriser'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Switch(
              value: _enabled,
              onChanged: (v) async {
                setState(() => _enabled = v);
                try {
                  await LivesApi.voiceSettings(widget.liveId, enabled: v);
                } catch (_) {
                  if (mounted) setState(() => _enabled = !v);
                }
              },
            ),
          ]),
          Text(context.tr("Toi seul peux les écouter. Ils sont effacés 7 jours après la fin du live."), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
          else if (_notes.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(context.tr('Aucun vocal pour le moment.'), style: const TextStyle(color: Colors.white54)))
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _notes.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                itemBuilder: (ctx, i) {
                  final n = _notes[i];
                  final sender = (n['sender'] as Map?) ?? {};
                  final isNew = n['status'] == 'new';
                  final name = '${sender['display_name'] ?? sender['username'] ?? ''}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.white12,
                      backgroundImage: (sender['avatar_url'] ?? '') != '' ? NetworkImage('${sender['avatar_url']}') : null,
                      child: (sender['avatar_url'] ?? '') == '' ? const Icon(Icons.person, color: Colors.white54) : null,
                    ),
                    title: Text(name, style: TextStyle(color: Colors.white, fontWeight: isNew ? FontWeight.w800 : FontWeight.w500)),
                    subtitle: Text('${n['duration_seconds']} s${isNew ? ' · ${ctx.tr('nouveau')}' : ''}', style: TextStyle(color: isNew ? const Color(0xFFF9A825) : Colors.white54, fontSize: 12)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: Icon(_playing == n['id'] ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
                        onPressed: () => _play(n),
                      ),
                      PopupMenuButton<String>(
                        color: Colors.grey[850],
                        icon: const Icon(Icons.more_vert, color: Colors.white54),
                        onSelected: (v) async {
                          try {
                            if (v == 'ignore') await LivesApi.voiceIgnore('${n['id']}');
                            if (v == 'report') await LivesApi.voiceReport('${n['id']}');
                            if (mounted) setState(() => _notes.removeAt(i));
                          } catch (_) {}
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'ignore', child: Text(ctx.tr('Ignorer'), style: const TextStyle(color: Colors.white))),
                          PopupMenuItem(value: 'report', child: Text(ctx.tr('Signaler et bloquer'), style: const TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    ]),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// Ligne « vocal » dans le chat du live : tout le monde voit qu'un vocal a été envoyé (et sa durée), SEUL l'hôte peut l'écouter (le serveur refuse le lien d'écoute aux autres).
class VoiceChatBadge extends StatefulWidget {
  const VoiceChatBadge({super.key, required this.noteId, required this.seconds, required this.isHost});
  final String noteId;
  final int seconds;
  final bool isHost;

  @override
  State<VoiceChatBadge> createState() => _VoiceChatBadgeState();
}

class _VoiceChatBadgeState extends State<VoiceChatBadge> {
  static final AudioPlayer _player = AudioPlayer();
  bool _loading = false;
  bool _playing = false;

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await LivesApi.voiceListen(widget.noteId);
      await _player.stop();
      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _playing = false);
      });
      await _player.play(UrlSource(url));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Écoute impossible. Réessaie.'))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = tr("a envoyé un message vocal à l'hôte") + ' · ${widget.seconds} s';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.mic_rounded, color: Colors.white70, size: 14),
      const SizedBox(width: 4),
      Flexible(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 6),
      if (widget.isHost)
        GestureDetector(
          onTap: _toggle,
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_playing ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
        )
      else
        const Icon(Icons.lock_rounded, color: Colors.white54, size: 13),   // spectateur : on voit qu'un vocal existe, on ne peut pas l'écouter
    ]);
  }
}
