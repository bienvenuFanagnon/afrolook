import 'dart:async';

import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/tr.dart';
import '../models/post_widget.dart';
import '../services/api/widgets_api.dart';

/// Un widget posé sur une publication : sondage, quiz, question, réaction, rappel (le public répond), compte à rebours, lien, lieu, WhatsApp, appel, carte de vente.
/// `preview` : aperçu dans l'éditeur (rien ne s'envoie). Fond clair et texte sombre : lisible sur n'importe quelle image ou vidéo, en mode clair comme sombre.
class PostWidgetView extends StatefulWidget {
  const PostWidgetView({super.key, required this.widget, this.preview = false, this.onChanged});

  final PostWidget widget;
  final bool preview;
  final VoidCallback? onChanged;

  @override
  State<PostWidgetView> createState() => _PostWidgetViewState();
}

class _PostWidgetViewState extends State<PostWidgetView> {
  static const _ink = Color(0xFF14201A);
  static const _sub = Color(0xFF5B6A62);
  static const _line = Color(0xFFDFE6E2);
  static const _green = Color(0xFF1B8A3C);

  Timer? _tick;
  bool _sending = false;
  final _answer = TextEditingController();

  PostWidget get w => widget.widget;

  @override
  void initState() {
    super.initState();
    if (w.kind == WidgetKind.countdown) _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _respond(Object value) async {
    if (widget.preview || _sending || w.id == null) return;
    setState(() => _sending = true);
    try {
      final r = await WidgetsApi.respond(w.id!, value);
      if (r != null) {
        w.counts = r.counts;
        w.myValue = r.myValue;
        w.responsesCount = r.responsesCount;
        if (r.correct != null) w.config['correct'] = r.correct;
      }
      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(e.message.isNotEmpty ? e.message : context.tr('Impossible pour le moment. Réessaie plus tard.'))));
    } catch (_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('Impossible pour le moment. Réessaie plus tard.'))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _open(String url) async {
    if (widget.preview) return;
    final u = Uri.tryParse(url);
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _wa(String phone, String? message) => 'https://wa.me/${phone.replaceAll('+', '')}${message == null || message.isEmpty ? '' : '?text=${Uri.encodeComponent(message)}'}';

  Widget _card(List<Widget> children) => Container(
        key: ValueKey('widget_${w.kind.id}'),
        constraints: const BoxConstraints(maxWidth: 270, minWidth: 190),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 5))]),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _title(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 13.5, height: 1.25, decoration: TextDecoration.none)));

  Widget _button(String label, {IconData? icon, Color color = _green, VoidCallback? onTap, Color fg = Colors.white}) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, color: fg, size: 16), const SizedBox(width: 6)],
            Flexible(child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12.5, decoration: TextDecoration.none))),
          ]),
        ),
      );

  /// Options d'un sondage ou d'un quiz : avant la réponse des boutons ; après, des barres de pourcentage (et le bon choix d'un quiz).
  Widget _choices({required bool quiz}) {
    final opts = w.options;
    final answered = w.myValue != null;
    final total = w.counts.values.fold<int>(0, (a, b) => a + b);
    return Column(children: [
      for (var i = 0; i < opts.length; i++)
        GestureDetector(
          key: ValueKey('widget_option_$i'),
          onTap: answered || widget.preview ? null : () => _respond(i),
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: const Color(0xFFEEF2EF), borderRadius: BorderRadius.circular(10), border: Border.all(color: answered && quiz && w.correct == i ? _green : Colors.transparent, width: 1.6)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              if (answered && total > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ((w.counts['$i'] ?? 0) / total).clamp(0.0, 1.0),
                    child: ColoredBox(color: (quiz && w.correct == i ? _green : const Color(0xFFFFD21F)).withOpacity(.45)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(opts[i], style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12.5, decoration: TextDecoration.none))),
                  if (answered && total > 0) Text('${(((w.counts['$i'] ?? 0) / total) * 100).round()} %', style: const TextStyle(color: _sub, fontWeight: FontWeight.w800, fontSize: 11.5, decoration: TextDecoration.none)),
                  if (answered && w.myValue == '$i') const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check_circle_rounded, size: 15, color: _green)),
                ]),
              ),
            ]),
          ),
        ),
      if (answered)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('{n} réponses', {'n': total}), style: const TextStyle(color: _sub, fontSize: 11, decoration: TextDecoration.none))),
    ]);
  }

  String _countdown(DateTime at) {
    final d = at.difference(DateTime.now());
    if (d.isNegative) return context.tr('Terminé');
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return days > 0 ? '${days} j ${h} h ${m} min' : '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Feuille des réponses reçues (réservée à l'auteur) : pseudo et texte, les plus récentes d'abord.
  Future<void> _showAnswers(BuildContext context) async {
    final id = w.id;
    if (id == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .6,
        child: FutureBuilder<List<({String user, String text})>>(
          future: WidgetsApi.responses(id),
          builder: (ctx, snap) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Text('${w.question}', style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: snap.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : (snap.data ?? const []).isEmpty
                      ? Center(child: Text(context.tr('Aucune réponse pour le moment.'), style: const TextStyle(color: _sub)))
                      : ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
                          for (final a in snap.data!)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('@${a.user}', style: const TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w700)),
                                Text(a.text, style: const TextStyle(color: _ink, fontSize: 14.5)),
                              ]),
                            ),
                        ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = w.config;
    switch (w.kind) {
      case WidgetKind.poll:
        return _card([_title('📊 ${c['question'] ?? ''}'), _choices(quiz: false)]);
      case WidgetKind.quiz:
        return _card([_title('🧠 ${c['question'] ?? ''}'), _choices(quiz: true)]);
      case WidgetKind.question:
        final answered = w.myValue != null;
        return _card([
          _title('❓ ${c['question'] ?? ''}'),
          if (w.isAuthor && !widget.preview)
            GestureDetector(
              key: const ValueKey('widget_see_answers'),
              onTap: () => _showAnswers(context),
              child: Text('${context.tr('Voir les réponses')} (${w.responsesCount})', style: const TextStyle(color: _green, fontWeight: FontWeight.w800, fontSize: 13, decoration: TextDecoration.none)),
            )
          else if (answered && !widget.preview)
            Text('${context.tr('Envoyé')} ✓', style: const TextStyle(color: _green, fontWeight: FontWeight.w800, fontSize: 12.5, decoration: TextDecoration.none))
          else
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2EF), borderRadius: BorderRadius.circular(10)),
                  child: TextField(controller: _answer, enabled: !widget.preview, maxLength: 300, style: const TextStyle(color: _ink, fontSize: 12.5), decoration: InputDecoration(hintText: context.tr('Ta réponse…'), hintStyle: const TextStyle(color: _sub, fontSize: 12.5), border: InputBorder.none, counterText: '', isDense: true)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(onTap: () => _answer.text.trim().isEmpty ? null : _respond(_answer.text.trim()), child: const CircleAvatar(radius: 16, backgroundColor: _green, child: Icon(Icons.send_rounded, color: Colors.white, size: 16))),
            ]),
        ]);
      case WidgetKind.reaction:
        final emojis = [for (final e in (c['emojis'] as List? ?? const ['😍', '😂', '😮', '😢', '🔥', '👏'])) '$e'];
        return _card([
          if ('${c['question'] ?? ''}'.isNotEmpty) _title('${c['question']}'),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final e in emojis)
              GestureDetector(
                onTap: () => _respond(e),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(color: w.myValue == e ? const Color(0xFFFFD21F) : const Color(0xFFEEF2EF), borderRadius: BorderRadius.circular(12)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(e, style: const TextStyle(fontSize: 20, decoration: TextDecoration.none)),
                    if ((w.counts[e] ?? 0) > 0) Text('${w.counts[e]}', style: const TextStyle(color: _sub, fontSize: 10.5, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                  ]),
                ),
              ),
          ]),
        ]);
      case WidgetKind.countdown:
        final at = DateTime.tryParse('${c['at']}')?.toLocal();
        return _card([
          _title('⏳ ${c['title'] ?? ''}'),
          Text(at == null ? '' : _countdown(at), style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 20, decoration: TextDecoration.none)),
        ]);
      case WidgetKind.reminder:
        final at = DateTime.tryParse('${c['at']}')?.toLocal();
        final on = w.myValue != null;
        return _card([
          _title('🔔 ${c['title'] ?? ''}'),
          if (at != null) Text('${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: _sub, fontSize: 12, decoration: TextDecoration.none)),
          _button(on ? context.tr('C\'est noté ✓') : context.tr('Me le rappeler'), icon: on ? null : Icons.notifications_active_rounded, color: on ? const Color(0xFFEEF2EF) : _green, fg: on ? _ink : Colors.white, onTap: on ? null : () => _respond(1)),
          if (w.responsesCount > 0) Padding(padding: const EdgeInsets.only(top: 5), child: Text(context.tr('{n} personnes intéressées', {'n': w.responsesCount}), style: const TextStyle(color: _sub, fontSize: 11, decoration: TextDecoration.none))),
        ]);
      case WidgetKind.link:
        return _card([_button('🔗 ${c['label'] ?? ''}', color: _ink, onTap: () => _open('${c['url'] ?? ''}'))]);
      case WidgetKind.place:
        final maps = '${c['maps_url'] ?? ''}';
        return _card([
          _title('📍 ${c['name'] ?? ''}'),
          _button(context.tr('Voir sur la carte'), icon: Icons.map_rounded, color: _ink, onTap: () => _open(maps.isNotEmpty ? maps : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${c['name'] ?? ''}')}')),
        ]);
      case WidgetKind.whatsapp:
        return _card([_button('💬 ${c['label'] ?? context.tr('Écrire sur WhatsApp')}', color: const Color(0xFF25D366), onTap: () => _open(_wa('${c['phone'] ?? ''}', '${c['message'] ?? ''}')))]);
      case WidgetKind.call:
        return _card([_button('📞 ${c['label'] ?? context.tr('Appeler')}', color: _ink, onTap: () => _open('tel:${c['phone'] ?? ''}'))]);
      case WidgetKind.sale:
        return _card([
          _title('🛍️ ${c['product'] ?? ''}'),
          if ('${c['price'] ?? ''}'.isNotEmpty) Text('${c['price']}', style: const TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: 18, decoration: TextDecoration.none)),
          if ('${c['place'] ?? ''}'.isNotEmpty) Text('📍 ${c['place']}', style: const TextStyle(color: _sub, fontSize: 12, decoration: TextDecoration.none)),
          if ('${c['order_url'] ?? ''}'.isNotEmpty) _button(context.tr('Commander maintenant'), color: _green, onTap: () => _open('${c['order_url']}')),
          if ('${c['whatsapp'] ?? ''}'.isNotEmpty) _button('💬 WhatsApp', color: const Color(0xFF25D366), onTap: () => _open(_wa('${c['whatsapp']}', '${c['product'] ?? ''}'))),
          if ('${c['phone'] ?? ''}'.isNotEmpty) _button('📞 ${context.tr('Appeler')}', color: _ink, onTap: () => _open('tel:${c['phone']}')),
        ]);
    }
  }
}

/// Couche de widgets au-dessus d'un média : chaque widget à sa place (fractions du cadre) et à sa taille. Les widgets réagissent aux touchers ; le reste de la couche laisse passer les gestes.
class PostWidgetsLayer extends StatelessWidget {
  const PostWidgetsLayer({super.key, required this.widgets});

  final List<PostWidget> widgets;

  @override
  Widget build(BuildContext context) {
    if (widgets.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      return Stack(children: [
        for (final w in widgets)
          Positioned(
            left: 0,
            top: 0,
            width: box.maxWidth,
            height: box.maxHeight,
            child: Align(
              alignment: Alignment((w.x * 2 - 1).clamp(-1.0, 1.0), (w.y * 2 - 1).clamp(-1.0, 1.0)),
              child: Transform.scale(scale: w.scale, child: PostWidgetView(widget: w)),
            ),
          ),
      ]);
    });
  }
}
