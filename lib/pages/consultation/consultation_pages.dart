import 'dart:async';

import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/consultations_api.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

const _amber = Color(0xFFF9A825);
const _bg = Color(0xFF121212);
const _card = Color(0xFF242424);

Widget _avatar(Map? u, {double r = 24}) {
  final url = u?['avatar_url'] as String?;
  final name = '${u?['username'] ?? '?'}';
  return CircleAvatar(
    radius: r,
    backgroundColor: const Color(0xFF3B6A47),
    backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
    onBackgroundImageError: url != null && url.isNotEmpty ? (_, __) {} : null,
    child: url != null && url.isNotEmpty ? null : Text(name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(), style: TextStyle(color: Colors.white, fontSize: r * .7, fontWeight: FontWeight.w800)),
  );
}

/// Liste des experts disponibles pour une consultation 1 à 1. Si la personne est elle-même experte, les appels qui sonnent s'affichent ici
/// (l'écran interroge le serveur toutes les 4 secondes tant qu'il est ouvert).
class ConsultationExpertsPage extends StatefulWidget {
  const ConsultationExpertsPage({super.key});

  @override
  State<ConsultationExpertsPage> createState() => _ConsultationExpertsPageState();
}

class _ConsultationExpertsPageState extends State<ConsultationExpertsPage> {
  List<Map<String, dynamic>> _experts = const [];
  bool _loading = true;
  Timer? _poll;
  final Set<String> _asked = {};

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _checkIncoming());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final e = await ConsultationsApi.experts();
      if (mounted) setState(() => _experts = e);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkIncoming() async {
    try {
      final calls = await ConsultationsApi.incoming();
      for (final c in calls) {
        if (!mounted || !_asked.add('${c['id']}')) continue;
        final client = c['client'] as Map?;
        final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.tr('Appel de @{u}', {'u': '${client?['username'] ?? ''}'})),
            content: Text(ctx.tr('{m} · {p} pièces par minute. Il paie chaque minute au début.', {'m': c['media'] == 'video' ? ctx.tr('Vidéo') : ctx.tr('Audio'), 'p': '${c['price_per_min']}'})),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Refuser'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Décrocher'))),
            ],
          ),
        );
        if (!mounted) return;
        if (ok == true) {
          await ConsultationsApi.accept('${c['id']}');
          if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultationCallPage(consultationId: '${c['id']}', isExpert: true, media: '${c['media']}')));
        } else {
          await ConsultationsApi.decline('${c['id']}').catchError((_) {});
        }
      }
    } catch (_) {}
  }

  Future<void> _book(Map<String, dynamic> p) async {
    final media = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _BookingSheet(profile: p),
    );
    if (media == null || !mounted) return;
    try {
      final c = await ConsultationsApi.call('${(p['user'] as Map)['id']}', media);
      if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultationCallPage(consultationId: '${c['id']}', isExpert: false, media: media, expert: p['user'] as Map?)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isInsufficientCoins) {
        await CoinCheckout.insufficient(context, (e.details['coins'] as num?)?.toInt() ?? 0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(context.tr('Consultations'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationSettingsPage())), child: Text(context.tr('Devenir expert'), style: const TextStyle(color: _amber, fontWeight: FontWeight.w700))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : RefreshIndicator(
              onRefresh: _load,
              child: _experts.isEmpty
                  ? ListView(children: [Padding(padding: const EdgeInsets.all(32), child: Text(context.tr('Aucun expert disponible pour le moment.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)))])
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      Text(context.tr('Un appel privé, rien que vous deux. Tu paies à la minute et tu peux raccrocher quand tu veux.'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12.5, height: 1.4)),
                      const SizedBox(height: 12),
                      for (final p in _experts)
                        GestureDetector(
                          onTap: p['busy'] == true ? null : () => _book(p),
                          child: Opacity(
                            opacity: p['busy'] == true ? .5 : 1,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
                              child: Row(children: [
                                _avatar(p['user'] as Map?),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('@${(p['user'] as Map?)?['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                                    Text('${p['topic']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 12.5)),
                                    const SizedBox(height: 3),
                                    Text('${p['video_coins']} ${context.tr('pièces / min en vidéo')} · ${p['audio_coins']} ${context.tr('en audio')}', style: const TextStyle(color: _amber, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                                if (p['busy'] == true) Text(context.tr('En consultation'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11)) else const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                              ]),
                            ),
                          ),
                        ),
                    ]),
            ),
    );
  }
}

/// Fiche de réservation (maquette « Consulter @expert ») : tarifs, choix vidéo ou audio, appel.
class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  String _media = 'video';

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final v = (p['video_coins'] as num?)?.toInt() ?? 0;
    final a = (p['audio_coins'] as num?)?.toInt() ?? 0;
    final min = (p['min_minutes'] as num?)?.toInt() ?? 5;
    final price = _media == 'video' ? v : a;
    Widget choice(String key, String title, int coins) {
      final on = _media == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _media = key),
          child: Container(
            height: 54,
            decoration: BoxDecoration(color: on ? const Color(0xFF2A2312) : _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? _amber : const Color(0xFF2F2F2F), width: 2)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('$coins ${context.tr('pièces / min')}', style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11)),
            ]),
          ),
        ),
      );
    }

    Widget row(String l, String r, [Color c = Colors.white]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 13)), Text(r, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700))]),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).padding.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4A4A46), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text(context.tr('Consulter @{u}', {'u': '${(p['user'] as Map?)?['username'] ?? ''}'}), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(context.tr('Un appel privé, rien que vous deux. Tu paies à la minute, tu peux raccrocher quand tu veux.'), style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 13.5, height: 1.45)),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            row(context.tr('Sujet'), '${p['topic']}'),
            row(context.tr('Solde nécessaire pour appeler'), '${price * min} ${context.tr('pièces')}'),
            row(context.tr('Disponible'), context.tr('maintenant'), const Color(0xFF69F0AE)),
          ]),
        ),
        const SizedBox(height: 11),
        Row(children: [choice('video', context.tr('Vidéo'), v), const SizedBox(width: 8), choice('audio', context.tr('Audio'), a)]),
        const SizedBox(height: 11),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _media),
            style: ElevatedButton.styleFrom(backgroundColor: _amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
            child: Text(context.tr('Appeler'), style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
        Text(context.tr('Rien n\'est payé d\'avance : chaque minute est payée quand elle commence, et tu ne paies que les minutes écoulées.'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11.5, height: 1.4)),
      ]),
    );
  }
}

/// Réglages de l'expert : disponible ou non, sujet, tarifs à la minute (planchers fixés par le serveur).
class ConsultationSettingsPage extends StatefulWidget {
  const ConsultationSettingsPage({super.key});

  @override
  State<ConsultationSettingsPage> createState() => _ConsultationSettingsPageState();
}

class _ConsultationSettingsPageState extends State<ConsultationSettingsPage> {
  bool _enabled = false;
  final _topic = TextEditingController();
  final _video = TextEditingController(text: '30');
  final _audio = TextEditingController(text: '15');
  int _minVideo = 10;
  int _minAudio = 5;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final s = await ConsultationsApi.settings();
        _enabled = s['enabled'] == true;
        _topic.text = '${s['topic'] ?? ''}';
        _video.text = '${s['video_coins'] ?? 30}';
        _audio.text = '${s['audio_coins'] ?? 15}';
        final m = s['minimums'] as Map?;
        _minVideo = (m?['video'] as num?)?.toInt() ?? 10;
        _minAudio = (m?['audio'] as num?)?.toInt() ?? 5;
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      await ConsultationsApi.saveSettings(enabled: _enabled, topic: _topic.text.trim(), videoCoins: int.tryParse(_video.text) ?? 0, audioCoins: int.tryParse(_audio.text) ?? 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Réglages enregistrés.'))));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('Enregistrement impossible.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String l, [String? h]) => InputDecoration(labelText: l, helperText: h, labelStyle: const TextStyle(color: Color(0xFF9A9A95)), helperStyle: const TextStyle(color: Color(0xFF9A9A95)), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF3A3A37))), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _amber)));
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, foregroundColor: Colors.white, elevation: 0, title: Text(context.tr('Mon activité d\'expert'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : ListView(padding: const EdgeInsets.all(16), children: [
              SwitchListTile(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                activeColor: _amber,
                title: Text(context.tr('Je suis disponible pour des consultations'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: Text(context.tr('Garde l\'écran « Consultations » ouvert pour recevoir les appels.'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12)),
              ),
              const SizedBox(height: 8),
              TextField(controller: _topic, style: const TextStyle(color: Colors.white), maxLength: 80, decoration: dec(context.tr('Mon sujet'), context.tr('Nutrition, droit, coaching, couture…'))),
              const SizedBox(height: 8),
              TextField(controller: _video, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: dec(context.tr('Tarif vidéo (pièces par minute)'), context.tr('Au moins {n}', {'n': '$_minVideo'}))),
              const SizedBox(height: 12),
              TextField(controller: _audio, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: dec(context.tr('Tarif audio (pièces par minute)'), context.tr('Au moins {n}', {'n': '$_minAudio'}))),
              const SizedBox(height: 10),
              Text(context.tr('Le client paie chaque minute quand elle commence ; tu reçois le partage habituel des cadeaux. Le tarif couvre toujours les frais de connexion des deux personnes.'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12, height: 1.4)),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 16),
              SizedBox(height: 50, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: _amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: Text(context.tr('Enregistrer'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)))),
            ]),
    );
  }
}

/// Appel de consultation : sonnerie, puis Agora (canal propre à la consultation), compteur de minutes et de pièces, raccrocher.
class ConsultationCallPage extends StatefulWidget {
  const ConsultationCallPage({super.key, required this.consultationId, required this.isExpert, required this.media, this.expert});

  final String consultationId;
  final bool isExpert;
  final String media;
  final Map? expert;

  @override
  State<ConsultationCallPage> createState() => _ConsultationCallPageState();
}

class _ConsultationCallPageState extends State<ConsultationCallPage> {
  RtcEngine? _engine;
  Map<String, dynamic> _c = const {};
  int? _remote;
  bool _joined = false;
  bool _closing = false;
  int _minutesLeft = 0;
  Timer? _poll;
  Timer? _tick;
  Timer? _clock;
  DateTime? _startedAt;

  bool get _video => widget.media == 'video';

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _clock?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_closing) return;
    try {
      final c = await ConsultationsApi.get(widget.consultationId);
      if (!mounted) return;
      setState(() => _c = c);
      _startedAt ??= DateTime.tryParse('${c['started_at']}')?.toLocal();
      if (c['status'] == 'active' && !_joined) await _join();
      if (c['status'] != 'ringing' && c['status'] != 'active') _finish(c);
    } catch (_) {}
  }

  Future<void> _join() async {
    _joined = true;
    try {
      await [Permission.microphone, if (_video) Permission.camera].request();
      final t = await ConsultationsApi.token(widget.consultationId, 0);
      final e = createAgoraRtcEngine();
      _engine = e;
      await e.initialize(const RtcEngineContext(appId: '957063f627aa471581a52d4160f7c054', channelProfile: ChannelProfileType.channelProfileLiveBroadcasting));
      e.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (conn, uid, el) => mounted ? setState(() => _remote = uid) : null,
        onUserOffline: (conn, uid, r) => mounted ? setState(() => _remote = null) : null,
      ));
      if (_video) {
        await e.enableVideo();
        await e.startPreview();
      } else {
        await e.disableVideo();
      }
      await e.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await e.joinChannel(
        token: '${t['token']}',
        channelId: '${t['channel']}',
        uid: 0,
        options: ChannelMediaOptions(channelProfile: ChannelProfileType.channelProfileLiveBroadcasting, clientRoleType: ClientRoleType.clientRoleBroadcaster, publishCameraTrack: _video, publishMicrophoneTrack: true, autoSubscribeAudio: true, autoSubscribeVideo: _video),
      );
      _tick = Timer.periodic(const Duration(seconds: 30), (_) => _doTick());
      _doTick();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _doTick() async {
    try {
      final r = await ConsultationsApi.tick(widget.consultationId);
      if (!mounted) return;
      setState(() {
        _c = r;
        _minutesLeft = (r['minutes_left'] as num?)?.toInt() ?? 0;
      });
      if (r['status'] != 'active') _finish(r);
    } catch (_) {}
  }

  Future<void> _hangUp() async {
    try {
      final r = await ConsultationsApi.end(widget.consultationId);
      _finish(r);
    } catch (_) {
      _finish(_c);
    }
  }

  Future<void> _finish(Map<String, dynamic> c) async {
    if (_closing) return;
    _closing = true;
    _poll?.cancel();
    _tick?.cancel();
    final status = '${c['status']}';
    final coins = (c['coins_total'] as num?)?.toInt() ?? 0;
    final reason = '${c['end_reason']}';
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'declined' ? ctx.tr('Appel refusé') : status == 'missed' ? ctx.tr('Pas de réponse') : ctx.tr('Consultation terminée')),
        content: Text(status == 'declined' || status == 'missed'
            ? ctx.tr('Rien n\'a été payé.')
            : '${ctx.tr('{m} minute(s) · {p} pièces', {'m': '${c['minutes_charged'] ?? 0}', 'p': CoinCheckout.fmt(coins)})}${reason == 'balance' ? '\n${ctx.tr('Le solde ne suffisait plus pour la minute suivante.')}' : ''}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (mounted) {
      await CoinCheckout.refreshBalance(context);
      Navigator.pop(context);
    }
  }

  String _elapsed() {
    final s = _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inSeconds.clamp(0, 86400);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final active = _c['status'] == 'active';
    final other = (widget.isExpert ? _c['client'] : _c['expert']) as Map? ?? widget.expert;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (active && _video && _remote != null && _engine != null)
          Positioned.fill(child: AgoraVideoView(controller: VideoViewController.remote(rtcEngine: _engine!, canvas: VideoCanvas(uid: _remote), connection: RtcConnection(channelId: 'consult-${widget.consultationId}'))))
        else
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF31503A), Color(0xFF0B0B0B)])),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                _avatar(other, r: 48),
                const SizedBox(height: 14),
                Text('@${other?['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(active ? (_video ? context.tr('Connexion de la vidéo…') : context.tr('Appel audio en cours')) : context.tr('Ça sonne… (60 secondes)'), style: const TextStyle(color: Colors.white70)),
              ])),
            ),
          ),
        if (active && _video && _engine != null)
          Positioned(right: 16, top: 70, width: 84, height: 140, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: AgoraVideoView(controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0))))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (active) _chip(_elapsed()),
              if (active && !widget.isExpert) ...[const SizedBox(width: 6), _chip('${CoinCheckout.fmt((_c['coins_total'] as num?)?.toInt() ?? 0)} pcs', _amber)],
              if (active && widget.isExpert) ...[const SizedBox(width: 6), _chip('+${CoinCheckout.fmt((((_c['coins_total'] as num?)?.toInt() ?? 0) * 0.7).floor())} pcs', const Color(0xFF69F0AE))],
            ]),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black.withOpacity(.72), border: Border.all(color: _amber), borderRadius: BorderRadius.circular(18)),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!widget.isExpert)
                  Text(active ? context.tr('Tu paies à la minute : {p} pièces', {'p': '${_c['price_per_min'] ?? ''}'}) : context.tr('Tu ne paies rien tant que l\'expert n\'a pas décroché.'), style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                if (!widget.isExpert && active)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(context.tr('Le compteur s\'arrête dès que tu raccroches. Il te reste environ {m} minute(s) de solde.', {'m': '$_minutesLeft'}), style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
                if (widget.isExpert && active) Text(context.tr('Le client paie chaque minute au début. Raccroche quand tu veux.'), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: active ? _hangUp : () async {
                      await ConsultationsApi.decline(widget.consultationId).catchError((_) {});
                      _finish({'status': 'missed'});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD92D3A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                    child: Text(active ? context.tr('Raccrocher') : context.tr('Annuler l\'appel'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String t, [Color c = Colors.white]) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}
