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
  bool _isExpert = false;   // la personne a déjà créé son profil d'expert (sujet renseigné) : le bouton devient « Mon espace expert »
  bool _expertOn = false;   // et elle est disponible en ce moment

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
    try {
      final me = await ConsultationsApi.settings();
      if (mounted) setState(() {
        _isExpert = '${me['topic'] ?? ''}'.trim().isNotEmpty;
        _expertOn = me['enabled'] == true;
      });
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
      if (!mounted) return;
      if (c['status'] == 'waiting') {
        // l'expert est pris : le patient entre dans la file (rang, attente estimée, notification quand c'est son tour)
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultationQueuePage(consultationId: '${c['id']}', media: media, expert: p['user'] as Map?, initial: c)));
      } else {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultationCallPage(consultationId: '${c['id']}', isExpert: false, media: media, expert: p['user'] as Map?)));
      }
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'expert_offline') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpertSlotsPage(profile: p)));
      } else if (e.isInsufficientCoins) {
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
          IconButton(tooltip: context.tr('Mes rendez-vous'), icon: const Icon(Icons.event_note_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAppointmentsPage()))),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _isExpert ? const ExpertSpacePage() : const ConsultationSettingsPage())).then((_) => _load()), child: Text(_isExpert ? '${_expertOn ? '● ' : '○ '}${context.tr('Mon espace expert')}' : context.tr('Devenir expert'), style: const TextStyle(color: _amber, fontWeight: FontWeight.w700))),
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
                          onTap: () => p['online'] == true ? _book(p) : Navigator.push(context, MaterialPageRoute(builder: (_) => ExpertSlotsPage(profile: p))),
                          child: Opacity(
                            opacity: p['online'] == true ? 1 : .8,
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
                                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(
                                    p['online'] == true ? (p['busy'] == true || ((p['waiting'] as num?) ?? 0) > 0 ? context.tr('Occupé · {n} en attente', {'n': '${p['waiting'] ?? 0}'}) : context.tr('● En ligne')) : context.tr('Hors ligne'),
                                    style: TextStyle(color: p['online'] == true ? const Color(0xFF69F0AE) : const Color(0xFF9A9A95), fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpertSlotsPage(profile: p))),
                                    child: Text(context.tr('Rendez-vous ›'), style: const TextStyle(color: _amber, fontSize: 11.5, fontWeight: FontWeight.w800)),
                                  ),
                                ]),
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
          Positioned.fill(child: AgoraVideoView(controller: VideoViewController.remote(rtcEngine: _engine!, canvas: VideoCanvas(uid: _remote), connection: RtcConnection(channelId: 'consult-${widget.consultationId}'), useFlutterTexture: true, useAndroidSurfaceView: false)))
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
          Positioned(right: 16, top: 70, width: 84, height: 140, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: AgoraVideoView(controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0), useFlutterTexture: true, useAndroidSurfaceView: false)))),
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

// ───────────────────────── Espace expert, file d'attente, rendez-vous ─────────────────────────

String _two(int n) => n.toString().padLeft(2, '0');

/// « jeu. 20/11 · 14:30 » en heure locale.
String _when(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  const days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  return '${days[d.weekday - 1]} ${_two(d.day)}/${_two(d.month)} · ${_two(d.hour)}:${_two(d.minute)}';
}

String _mediaLabel(BuildContext c, Object? m) => m == 'video' ? c.tr('Vidéo') : c.tr('Audio');

Widget _statCard(String value, String label) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: const TextStyle(color: _amber, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11)),
        ]),
      ),
    );

Widget _sectionTitle(String t, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(children: [
        Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
        if (trailing != null) trailing,
      ]),
    );

/// Espace de l'expert : disponible maintenant, appels qui sonnent, personnes en attente (avec leur rang), gains, rendez-vous publiés, historique.
class ExpertSpacePage extends StatefulWidget {
  const ExpertSpacePage({super.key});

  @override
  State<ExpertSpacePage> createState() => _ExpertSpacePageState();
}

class _ExpertSpacePageState extends State<ExpertSpacePage> {
  Map<String, dynamic>? _q;
  Map<String, dynamic>? _hist;
  Timer? _poll;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadHistory();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final q = await ConsultationsApi.queue();
      if (mounted) setState(() => _q = q);
    } catch (_) {}
    if (mounted && _loading) setState(() => _loading = false);
  }

  Future<void> _loadHistory() async {
    try {
      final h = await ConsultationsApi.history('expert');
      if (mounted) setState(() => _hist = h);
    } catch (_) {}
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _toggleOnline(bool v) async {
    if (_q?['enabled'] != true) {
      _msg(context.tr('Active d\'abord ton profil d\'expert (sujet et tarifs).'));
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationSettingsPage()));
      return _refresh();
    }
    try {
      await ConsultationsApi.presence(v);
      await _refresh();
    } on ApiException catch (e) {
      _msg(e.message);
    } catch (_) {}
  }

  Future<void> _accept(Map c) async {
    try {
      await ConsultationsApi.accept('${c['id']}');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultationCallPage(consultationId: '${c['id']}', isExpert: true, media: '${c['media']}')));
    } on ApiException catch (e) {
      _msg(e.message);
    } catch (_) {}
    _refresh();
    _loadHistory();
  }

  Future<void> _decline(Map c) async {
    await ConsultationsApi.decline('${c['id']}').catchError((_) {});
    _refresh();
  }

  Future<void> _addSlot() async {
    final now = DateTime.now();
    final day = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 30)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null || !mounted) return;
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.tr('Durée du créneau')),
        children: [for (final m in const [15, 30, 45, 60]) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, m), child: Text(ctx.tr('{n} minutes', {'n': '$m'})))],
      ),
    );
    if (minutes == null) return;
    try {
      await ConsultationsApi.createSlot(DateTime(day.year, day.month, day.day, time.hour, time.minute), minutes);
      _msg(context.tr('Créneau publié.'));
      _refresh();
    } on ApiException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg(context.tr('Publication impossible.'));
    }
  }

  Future<void> _deleteSlot(Map s) async {
    final booked = s['status'] == 'booked';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Retirer ce créneau ?')),
        content: Text(booked ? ctx.tr('Un patient l\'a réservé : il sera prévenu de l\'annulation.') : ctx.tr('Il ne sera plus proposé aux patients.')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Garder'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Retirer')))],
      ),
    );
    if (ok != true) return;
    await ConsultationsApi.deleteSlot('${s['id']}').catchError((_) {});
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final online = q?['online'] == true;
    final until = DateTime.tryParse('${q?['online_until'] ?? ''}')?.toLocal();
    final ringing = (q?['ringing'] as List?)?.cast<Map>() ?? const [];
    final waiting = (q?['waiting'] as List?)?.cast<Map>() ?? const [];
    final slots = (q?['slots'] as List?)?.cast<Map>() ?? const [];
    final active = q?['active'] as Map?;
    final totals = (_hist?['totals'] as Map?) ?? const {};
    final items = (_hist?['items'] as List?)?.cast<Map>() ?? const [];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(context.tr('Mon espace expert'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: context.tr('Mon profil et mes tarifs'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationSettingsPage()));
              _refresh();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : RefreshIndicator(
              onRefresh: () async {
                await _refresh();
                await _loadHistory();
              },
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Container(
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: online ? const Color(0xFF2E7D32) : Colors.transparent)),
                  child: SwitchListTile(
                    value: online,
                    onChanged: _toggleOnline,
                    activeColor: _amber,
                    title: Text(context.tr('Disponible maintenant'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      online
                          ? context.tr('Jusqu\'à {h}. Les patients peuvent t\'appeler ; tu es prévenu par notification, même application fermée.', {'h': until == null ? '' : '${_two(until.hour)}:${_two(until.minute)}'})
                          : context.tr('Hors ligne : les patients ne peuvent que prendre rendez-vous.'),
                      style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12, height: 1.35),
                    ),
                  ),
                ),
                for (final c in ringing)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF2B2410), borderRadius: BorderRadius.circular(16), border: Border.all(color: _amber)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _avatar(c['client'] as Map?),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(context.tr('@{u} t\'attend', {'u': '${(c['client'] as Map?)?['username'] ?? ''}'}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                            Text('${_mediaLabel(context, c['media'])} · ${c['price_per_min']} ${context.tr('pièces par minute')} · ${c['ring_seconds_left'] ?? 0} s', style: const TextStyle(color: _amber, fontSize: 12)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => _decline(c), child: Text(context.tr('Refuser')))),
                        const SizedBox(width: 10),
                        Expanded(child: FilledButton(onPressed: () => _accept(c), style: FilledButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.black), child: Text(context.tr('Décrocher')))),
                      ]),
                    ]),
                  ),
                if (active != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      _avatar(active['client'] as Map?),
                      const SizedBox(width: 12),
                      Expanded(child: Text(context.tr('En consultation avec @{u}', {'u': '${(active['client'] as Map?)?['username'] ?? ''}'}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultationCallPage(consultationId: '${active['id']}', isExpert: true, media: '${active['media']}'))).then((_) => _refresh()),
                        child: Text(context.tr('Reprendre')),
                      ),
                    ]),
                  ),
                _sectionTitle(waiting.isEmpty ? context.tr('Personne n\'attend') : context.tr('En attente ({n})', {'n': '${waiting.length}'})),
                for (var i = 0; i < waiting.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Text('${i + 1}', style: const TextStyle(color: _amber, fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(width: 12),
                      _avatar(waiting[i]['client'] as Map?, r: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('@${(waiting[i]['client'] as Map?)?['username'] ?? ''}${waiting[i]['priority'] == true ? ' · ${context.tr('rendez-vous')}' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('${_mediaLabel(context, waiting[i]['media'])} · ${context.tr('attend depuis {n} min', {'n': '${waiting[i]['waited_minutes'] ?? 0}'})}', style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11.5)),
                        ]),
                      ),
                    ]),
                  ),
                if (waiting.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(context.tr('Quand tu raccroches, le suivant sonne tout de suite : tu n\'as rien à faire.'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11.5))),
                _sectionTitle(context.tr('Mes chiffres')),
                Row(children: [
                  _statCard('${totals['consultations'] ?? 0}', context.tr('consultations')),
                  _statCard('${totals['minutes'] ?? 0}', context.tr('minutes')),
                  _statCard('${totals['coins'] ?? 0}', context.tr('pièces gagnées')),
                ]),
                Row(children: [
                  _statCard('${totals['week_consultations'] ?? 0}', context.tr('cette semaine')),
                  _statCard('${totals['week_coins'] ?? 0}', context.tr('pièces cette semaine')),
                ]),
                _sectionTitle(context.tr('Mes rendez-vous'), trailing: TextButton.icon(onPressed: _addSlot, icon: const Icon(Icons.add_rounded, size: 18), label: Text(context.tr('Ajouter un créneau')))),
                if (slots.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(context.tr('Publie des créneaux : les patients réservent, tu reçois un rappel 15 minutes avant et l\'appel arrive à l\'heure.'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12, height: 1.35))),
                for (final s in slots)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${_when(s['starts_at'] as String?)} · ${s['minutes']} min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(
                            s['status'] == 'booked' ? context.tr('Réservé par @{u} · {m}', {'u': '${(s['client'] as Map?)?['username'] ?? ''}', 'm': _mediaLabel(context, s['media'])}) : context.tr('Libre'),
                            style: TextStyle(color: s['status'] == 'booked' ? const Color(0xFF69F0AE) : const Color(0xFF9A9A95), fontSize: 12),
                          ),
                        ]),
                      ),
                      if (s['status'] == 'open' || s['status'] == 'booked') IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54), onPressed: () => _deleteSlot(s)),
                    ]),
                  ),
                _sectionTitle(context.tr('Historique')),
                if (items.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(context.tr('Tes consultations terminées apparaîtront ici, avec les pièces reçues.'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12))),
                for (final c in items)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      _avatar(c['client'] as Map?, r: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('@${(c['client'] as Map?)?['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('${_when(c['ended_at'] as String?)} · ${_mediaLabel(context, c['media'])} · ${c['minutes_charged']} min', style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11.5)),
                        ]),
                      ),
                      Text('+${c['coins_earned']}', style: const TextStyle(color: _amber, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }
}

/// Le patient attend son tour : rang, attente estimée, quitter la file ; dès que c'est son tour, il passe à l'appel.
class ConsultationQueuePage extends StatefulWidget {
  const ConsultationQueuePage({super.key, required this.consultationId, required this.media, this.expert, this.initial});
  final String consultationId;
  final String media;
  final Map? expert;
  final Map? initial;

  @override
  State<ConsultationQueuePage> createState() => _ConsultationQueuePageState();
}

class _ConsultationQueuePageState extends State<ConsultationQueuePage> {
  Map? _c;
  Timer? _poll;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c = widget.initial;
    _tick();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_left || !mounted) return;
    try {
      final c = await ConsultationsApi.get(widget.consultationId);
      if (!mounted) return;
      setState(() => _c = c);
      final st = '${c['status']}';
      if (st == 'ringing' || st == 'active') {
        _left = true;
        _poll?.cancel();
        await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ConsultationCallPage(consultationId: widget.consultationId, isExpert: false, media: widget.media, expert: widget.expert ?? c['expert'] as Map?)));
      }
    } catch (_) {}
  }

  Future<void> _quit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Quitter la file ?')),
        content: Text(ctx.tr('Tu perds ta place. Rien n\'est payé : tu peux revenir quand tu veux.')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Rester'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Quitter')))],
      ),
    );
    if (ok != true) return;
    _left = true;
    await ConsultationsApi.cancel(widget.consultationId).catchError((_) => <String, dynamic>{});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final st = '${c?['status'] ?? 'waiting'}';
    final wait = c?['wait'] as Map?;
    final expert = widget.expert ?? c?['expert'] as Map?;
    final closed = const {'missed', 'canceled', 'expired', 'declined', 'ended'}.contains(st);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, foregroundColor: Colors.white, elevation: 0, title: Text(context.tr('File d\'attente'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _avatar(expert, r: 40),
          const SizedBox(height: 12),
          Text('@${expert?['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 28),
          if (closed) ...[
            Text(
              st == 'expired'
                  ? context.tr('Ta place dans la file est terminée.')
                  : st == 'missed' || st == 'declined'
                      ? context.tr('L\'expert n\'a pas pu te prendre cette fois.')
                      : context.tr('Tu as quitté la file.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Retour'))),
          ] else ...[
            Text(context.tr('Tu es {n}e dans la file', {'n': '${wait?['position'] ?? '…'}'}), style: const TextStyle(color: _amber, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              wait == null ? context.tr('Mise à jour…') : context.tr('Attente estimée : environ {m} minutes', {'m': '${wait['eta_minutes']}'}),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Text(context.tr('Tu peux quitter cet écran : tu seras prévenu par une notification quand ce sera à toi. Rien n\'est payé tant que la consultation n\'a pas commencé.'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: _quit, child: Text(context.tr('Quitter la file'))),
          ],
        ]),
      ),
    );
  }
}

/// Créneaux libres d'un expert : le patient en réserve un (rien n'est payé ; le solde doit couvrir la durée minimale).
class ExpertSlotsPage extends StatefulWidget {
  const ExpertSlotsPage({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<ExpertSlotsPage> createState() => _ExpertSlotsPageState();
}

class _ExpertSlotsPageState extends State<ExpertSlotsPage> {
  List<Map<String, dynamic>> _slots = const [];
  bool _loading = true;

  Map? get _user => widget.profile['user'] as Map?;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ConsultationsApi.expertSlots('${_user?['id']}');
      if (mounted) setState(() => _slots = s);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _book(Map<String, dynamic> s) async {
    final media = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_when(s['starts_at'] as String?)} · ${s['minutes']} min', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(ctx.tr('Rien n\'est payé maintenant : tu paies chaque minute au début de la consultation.'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12.5)),
            const SizedBox(height: 14),
            ListTile(leading: const Icon(Icons.videocam_rounded, color: _amber), title: Text(ctx.tr('Vidéo'), style: const TextStyle(color: Colors.white)), subtitle: Text('${widget.profile['video_coins']} ${ctx.tr('pièces par minute')}', style: const TextStyle(color: Color(0xFF9A9A95))), onTap: () => Navigator.pop(ctx, 'video')),
            ListTile(leading: const Icon(Icons.mic_rounded, color: _amber), title: Text(ctx.tr('Audio'), style: const TextStyle(color: Colors.white)), subtitle: Text('${widget.profile['audio_coins']} ${ctx.tr('pièces par minute')}', style: const TextStyle(color: Color(0xFF9A9A95))), onTap: () => Navigator.pop(ctx, 'audio')),
          ]),
        ),
      ),
    );
    if (media == null || !mounted) return;
    try {
      await ConsultationsApi.bookSlot('${s['id']}', media);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Rendez-vous réservé. Tu seras prévenu 15 minutes avant et à l\'heure.'))));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isInsufficientCoins) {
        await CoinCheckout.insufficient(context, (e.details['coins'] as num?)?.toInt() ?? 0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, foregroundColor: Colors.white, elevation: 0, title: Text(context.tr('Rendez-vous avec @{u}', {'u': '${_user?['username'] ?? ''}'}), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Text('${widget.profile['topic']}', style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 13)),
                const SizedBox(height: 12),
                if (_slots.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text(context.tr('Cet expert n\'a pas de créneau libre pour le moment.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                for (final s in _slots)
                  GestureDetector(
                    onTap: () => _book(s),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.event_available_rounded, color: _amber),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${_when(s['starts_at'] as String?)} · ${s['minutes']} min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                        Text(context.tr('Réserver'), style: const TextStyle(color: _amber, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
              ]),
            ),
    );
  }
}

/// Mes rendez-vous de patient : à venir, annulation possible.
class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  List<Map> _booked = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await ConsultationsApi.mySlots();
      if (mounted) setState(() => _booked = (m['booked'] as List?)?.cast<Map>() ?? const []);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancel(Map s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Annuler ce rendez-vous ?')),
        content: Text(ctx.tr('Le créneau redevient libre et l\'expert est prévenu.')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Garder'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Annuler le rendez-vous')))],
      ),
    );
    if (ok != true) return;
    await ConsultationsApi.unbookSlot('${s['id']}').catchError((_) {});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, foregroundColor: Colors.white, elevation: 0, title: Text(context.tr('Mes rendez-vous'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _amber))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (_booked.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text(context.tr('Aucun rendez-vous à venir. Choisis un expert pour réserver un créneau.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                for (final s in _booked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      _avatar(s['expert'] as Map?),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('@${(s['expert'] as Map?)?['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          Text('${_when(s['starts_at'] as String?)} · ${s['minutes']} min · ${_mediaLabel(context, s['media'])}', style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 12.5)),
                          Text(s['status'] == 'done' ? context.tr('Terminé ou en cours') : context.tr('À venir'), style: TextStyle(color: s['status'] == 'done' ? const Color(0xFF9A9A95) : const Color(0xFF69F0AE), fontSize: 12)),
                        ]),
                      ),
                      if (s['status'] == 'booked') TextButton(onPressed: () => _cancel(s), child: Text(context.tr('Annuler'))),
                    ]),
                  ),
              ]),
            ),
    );
  }
}
