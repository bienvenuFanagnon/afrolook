import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/post_widget.dart';
import '../theme/app_colors.dart';

/// Feuille « Ajouter un widget » puis formulaire du widget choisi. Rend le widget prêt à poser (null si on annule). Aucun widget n'est réservé à Gold (décision du 07/11/2026).
Future<PostWidget?> addWidgetFlow(BuildContext context) async {
  final kind = await showModalBottomSheet<WidgetKind>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _KindSheet(),
  );
  if (kind == null || !context.mounted) return null;
  return editWidget(context, kind);
}

/// Formulaire d'un widget ([existing] : on le modifie). Rend le widget (même place si modification) ou null.
Future<PostWidget?> editWidget(BuildContext context, WidgetKind kind, {PostWidget? existing}) {
  return showModalBottomSheet<PostWidget>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditSheet(kind: kind, existing: existing),
  );
}

class _KindSheet extends StatelessWidget {
  const _KindSheet();

  static const _groups = <(String, List<WidgetKind>)>[
    ('INTERAGIR', [WidgetKind.poll, WidgetKind.question, WidgetKind.quiz, WidgetKind.reaction, WidgetKind.countdown, WidgetKind.reminder]),
    ('VENDRE', [WidgetKind.sale, WidgetKind.whatsapp, WidgetKind.call]),
    ('INFOS', [WidgetKind.place, WidgetKind.link]),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      key: const ValueKey('widgets_sheet'),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
      decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 12),
            Text(context.tr('Ajouter un widget'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
            Text(context.tr('5 au plus par publication. Gratuit.'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
            for (final g in _groups) ...[
              Padding(padding: const EdgeInsets.fromLTRB(2, 14, 0, 8), child: Text(context.tr(g.$1), style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8))),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.15,
                children: [
                  for (final k in g.$2)
                    GestureDetector(
                      key: ValueKey('widget_kind_${k.id}'),
                      onTap: () => Navigator.pop(context, k),
                      child: Container(
                        decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(k.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(context.tr(k.label), textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                ],
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.kind, this.existing});
  final WidgetKind kind;
  final PostWidget? existing;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final Map<String, TextEditingController> _f;
  late List<TextEditingController> _opts;
  int _correct = 0;
  DateTime? _at;
  String? _error;

  PostWidget? get _old => widget.existing;

  @override
  void initState() {
    super.initState();
    final c = _old?.config ?? const <String, dynamic>{};
    _f = {for (final k in const ['question', 'title', 'label', 'url', 'name', 'maps_url', 'phone', 'message', 'product', 'price', 'place', 'whatsapp', 'order_url']) k: TextEditingController(text: '${c[k] ?? ''}')};
    final o = [for (final e in (c['options'] as List? ?? const ['', ''])) '$e'];
    _opts = [for (var i = 0; i < (o.length < 2 ? 2 : o.length); i++) TextEditingController(text: i < o.length ? o[i] : '')];
    _correct = (c['correct'] as num?)?.toInt() ?? 0;
    _at = DateTime.tryParse('${c['at']}')?.toLocal() ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    for (final t in _f.values) {
      t.dispose();
    }
    for (final t in _opts) {
      t.dispose();
    }
    super.dispose();
  }

  String _v(String k) => _f[k]!.text.trim();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _at ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365 * 2)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at ?? now));
    if (!mounted) return;
    setState(() => _at = DateTime(d.year, d.month, d.day, t?.hour ?? 20, t?.minute ?? 0));
  }

  void _save() {
    final k = widget.kind;
    final cfg = <String, dynamic>{};
    String? need(String key) => _v(key).isEmpty ? key : null;
    String? missing;
    switch (k) {
      case WidgetKind.poll:
      case WidgetKind.quiz:
        final opts = [for (final t in _opts) if (t.text.trim().isNotEmpty) t.text.trim()];
        missing = need('question');
        if (missing == null && opts.length < 2) missing = 'options';
        cfg.addAll({'question': _v('question'), 'options': opts});
        if (k == WidgetKind.quiz) cfg['correct'] = _correct.clamp(0, opts.isEmpty ? 0 : opts.length - 1);
      case WidgetKind.question:
        missing = need('question');
        cfg['question'] = _v('question');
      case WidgetKind.reaction:
        cfg['question'] = _v('question').isEmpty ? 'Ta réaction ?' : _v('question');
      case WidgetKind.countdown:
      case WidgetKind.reminder:
        missing = need('title');
        cfg.addAll({'title': _v('title'), 'at': (_at ?? DateTime.now()).toUtc().toIso8601String()});
      case WidgetKind.link:
        missing = need('label') ?? need('url');
        cfg.addAll({'label': _v('label'), 'url': _v('url')});
      case WidgetKind.place:
        missing = need('name');
        cfg.addAll({'name': _v('name'), 'maps_url': _v('maps_url')});
      case WidgetKind.whatsapp:
        missing = need('phone');
        cfg.addAll({'phone': _v('phone'), 'message': _v('message'), if (_v('label').isNotEmpty) 'label': _v('label')});
      case WidgetKind.call:
        missing = need('phone');
        cfg.addAll({'phone': _v('phone'), if (_v('label').isNotEmpty) 'label': _v('label')});
      case WidgetKind.sale:
        missing = need('product');
        cfg.addAll({'product': _v('product'), 'price': _v('price'), 'place': _v('place'), 'whatsapp': _v('whatsapp'), 'phone': _v('phone'), 'order_url': _v('order_url')});
    }
    if (missing != null) {
      setState(() => _error = context.tr('Complète les champs demandés.'));
      return;
    }
    final w = PostWidget(id: _old?.id, kind: k, config: cfg, x: _old?.x ?? .5, y: _old?.y ?? .5, scale: _old?.scale ?? 1, start: _old?.start, end: _old?.end);
    Navigator.pop(context, w);
  }

  Widget _field(String key, String label, {String? hint, TextInputType? type, int max = 120}) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: ValueKey('wf_$key'),
        controller: _f[key],
        keyboardType: type,
        maxLength: max,
        style: TextStyle(color: c.textPrimary, fontSize: 14),
        decoration: InputDecoration(labelText: context.tr(label), hintText: hint == null ? null : context.tr(hint), counterText: '', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  List<Widget> _form() {
    switch (widget.kind) {
      case WidgetKind.poll:
      case WidgetKind.quiz:
        final quiz = widget.kind == WidgetKind.quiz;
        return [
          _field('question', 'Question'),
          for (var i = 0; i < _opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                if (quiz) Radio<int>(value: i, groupValue: _correct, onChanged: (v) => setState(() => _correct = v ?? 0)),
                Expanded(child: TextField(key: ValueKey('wo_$i'), controller: _opts[i], maxLength: 40, decoration: InputDecoration(labelText: '${context.tr('Choix')} ${i + 1}', counterText: '', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
              ]),
            ),
          if (_opts.length < 4) TextButton.icon(onPressed: () => setState(() => _opts = [..._opts, TextEditingController()]), icon: const Icon(Icons.add_rounded), label: Text(context.tr('Ajouter un choix'))),
          if (quiz) Text(context.tr('Touche le rond de la bonne réponse.'), style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 12)),
        ];
      case WidgetKind.question:
        return [_field('question', 'Ta question', hint: 'Pose-moi une question')];
      case WidgetKind.reaction:
        return [_field('question', 'Texte (facultatif)', hint: 'Ta réaction ?', max: 80)];
      case WidgetKind.countdown:
      case WidgetKind.reminder:
        final a = _at ?? DateTime.now();
        return [
          _field('title', 'Titre', hint: widget.kind == WidgetKind.reminder ? 'Live ce soir' : 'Concert', max: 60),
          OutlinedButton.icon(
            key: const ValueKey('wf_date'),
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded),
            label: Text('${a.day.toString().padLeft(2, '0')}/${a.month.toString().padLeft(2, '0')}/${a.year}  ${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}'),
          ),
        ];
      case WidgetKind.link:
        return [_field('label', 'Texte du bouton', hint: 'Ma boutique', max: 40), _field('url', 'Adresse (https://…)', type: TextInputType.url, max: 300)];
      case WidgetKind.place:
        return [_field('name', 'Nom du lieu', hint: 'Marché de Hanoukopé, Lomé', max: 60), _field('maps_url', 'Lien de la carte (facultatif)', type: TextInputType.url, max: 300)];
      case WidgetKind.whatsapp:
        return [_field('phone', 'Numéro WhatsApp (+228…)', type: TextInputType.phone, max: 24), _field('message', 'Message prêt à envoyer (facultatif)'), _field('label', 'Texte du bouton (facultatif)', max: 40)];
      case WidgetKind.call:
        return [_field('phone', 'Numéro à appeler (+228…)', type: TextInputType.phone, max: 24), _field('label', 'Texte du bouton (facultatif)', max: 40)];
      case WidgetKind.sale:
        return [
          _field('product', 'Produit', hint: 'Pagne wax', max: 60),
          _field('price', 'Prix', hint: '8 000 F', max: 24),
          _field('place', 'Lieu (facultatif)', max: 60),
          _field('whatsapp', 'WhatsApp (facultatif)', type: TextInputType.phone, max: 24),
          _field('phone', 'Téléphone (facultatif)', type: TextInputType.phone, max: 24),
          _field('order_url', 'Lien « Commander » (facultatif)', type: TextInputType.url, max: 300),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        key: const ValueKey('widget_editor'),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 12),
              Text('${widget.kind.emoji}  ${context.tr(widget.kind.label)}', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              ..._form(),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: c.danger, fontSize: 12.5))),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Annuler')))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton(key: const ValueKey('wf_save'), onPressed: _save, style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent), child: Text(context.tr(_old == null ? 'Poser sur ma publication' : 'Enregistrer'), style: const TextStyle(fontWeight: FontWeight.w900)))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
