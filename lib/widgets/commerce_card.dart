import '../utils/platform_guard.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/tr.dart';
import '../services/api/commerce_api.dart';
import '../theme/app_colors.dart';

/// Carte Commerce posée sur un post : une PASTILLE (prix ou titre) que le spectateur déplie d'un toucher ; dans la carte dépliée, des boutons dans l'application
/// (WhatsApp avec un message prêt, appel, lien « Commander maintenant ») : seuls ces boutons ouvrent quelque chose, le reste de la carte ne fait rien.
class PostCommerceOverlay extends StatefulWidget {
  const PostCommerceOverlay({super.key, required this.postId});

  final String postId;

  @override
  State<PostCommerceOverlay> createState() => _PostCommerceOverlayState();
}

class _PostCommerceOverlayState extends State<PostCommerceOverlay> {
  PostCommerce? _card;
  bool _open = false;
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    CommerceApi.get(widget.postId).then((c) {
      if (mounted) setState(() => _card = c);
    }).catchError((_) {});
  }

  Future<void> _launch(Uri uri, String kind) async {
    CommerceApi.click(widget.postId, kind);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Impossible d\'ouvrir ce lien pour le moment.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _card;
    if (c == null) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    if (!_open) {
      return GestureDetector(
        key: const ValueKey('commerce_pill'),
        onTap: () {
          setState(() => _open = true);
          if (!_counted) {
            _counted = true;
            CommerceApi.click(widget.postId, 'open');
          }
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .96), borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
              child: Icon(Icons.shopping_bag_rounded, size: 13, color: colors.onAccent),
            ),
            const SizedBox(width: 7),
            Flexible(child: Text(c.priceText ?? c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF15201A), fontWeight: FontWeight.w800, fontSize: 13))),
          ]),
        ),
      );
    }
    // sur iPhone / iPad le bouton de lien externe n'est pas montré (règle App Store sur les achats de contenus numériques hors achat intégré) ; WhatsApp et appel restent
    final hasLink = c.linkUrl != null && !kIsAppleStore;
    return Container(
      key: const ValueKey('commerce_card'),
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .97), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF15201A), fontWeight: FontWeight.w800, fontSize: 14.5))),
          GestureDetector(key: const ValueKey('commerce_close'), onTap: () => setState(() => _open = false), child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF5D6B63)))),
        ]),
        if (c.priceText != null) Text(c.priceText!, style: const TextStyle(color: Color(0xFF15201A), fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -.2)),
        if (c.place != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              const Icon(Icons.place_rounded, size: 15, color: Color(0xFF5D6B63)),
              const SizedBox(width: 4),
              Expanded(child: Text(c.place!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5D6B63), fontSize: 12.5))),
            ]),
          ),
        if (hasLink && (c.linkImage != null || c.linkTitle != null)) ...[
          const SizedBox(height: 8),
          // mini-aperçu du lien : image et titre de la page (pas cliquable : seul le bouton ouvre le lien)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F3F1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              if (c.linkImage != null)
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(c.linkImage!, width: 48, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 64))),
              if (c.linkImage != null) const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (c.linkTitle != null) Text(c.linkTitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF15201A), fontWeight: FontWeight.w800, fontSize: 12.5, height: 1.2)),
                  Text(Uri.tryParse(c.linkUrl!)?.host ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5D6B63), fontSize: 11.5)),
                ]),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (c.whatsapp != null)
            _action(const ValueKey('commerce_whatsapp'), Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), Colors.white, () => _launch(c.whatsappUri(context.tr('Bonjour, je suis intéressé(e) par votre publication sur Afrolook : ${c.title}')), 'whatsapp')),
          if (c.phone != null) _action(const ValueKey('commerce_call'), Icons.call_rounded, context.tr('Appeler'), const Color(0xFFEEF1EE), const Color(0xFF15201A), () => _launch(c.callUri(), 'call')),
          if (hasLink) _action(const ValueKey('commerce_link'), Icons.shopping_cart_checkout_rounded, c.linkLabel, colors.accent, colors.onAccent, () => _launch(Uri.parse(c.linkUrl!), 'link')),
        ]),
      ]),
    );
  }

  Widget _action(Key key, IconData icon, String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      ),
    );
  }
}

/// Fenêtre de l'auteur : régler (ou retirer) la carte Commerce de sa publication, et voir les chiffres.
Future<void> showCommerceEditor(BuildContext context, String postId) async {
  PostCommerce? existing;
  CommerceStats? stats;
  try {
    existing = await CommerceApi.get(postId);
    if (existing != null) stats = await CommerceApi.stats(postId);
  } catch (_) {}
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _CommerceEditor(postId: postId, existing: existing, stats: stats),
  );
}

class _CommerceEditor extends StatefulWidget {
  const _CommerceEditor({required this.postId, this.existing, this.stats});
  final String postId;
  final PostCommerce? existing;
  final CommerceStats? stats;

  @override
  State<_CommerceEditor> createState() => _CommerceEditorState();
}

class _CommerceEditorState extends State<_CommerceEditor> {
  static const _labels = ['Commander maintenant', 'Réserver', 'S\'inscrire', 'Télécharger', 'Voir'];

  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _price = TextEditingController(text: widget.existing?.priceText ?? '');
  late final _place = TextEditingController(text: widget.existing?.place ?? '');
  late final _wa = TextEditingController(text: widget.existing?.whatsapp ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _link = TextEditingController(text: widget.existing?.linkUrl ?? '');
  late String _label = widget.existing?.linkLabel ?? _labels.first;
  late bool _collapsed = widget.existing?.collapsed ?? true;
  String? _linkTitle;
  String? _linkImage;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _linkTitle = widget.existing?.linkTitle;
    _linkImage = widget.existing?.linkImage;
  }

  String? _n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// Lit l'image et le titre de la page quand on quitte le champ du lien (mini-aperçu de la carte).
  Future<void> _fetchPreview() async {
    final u = _link.text.trim();
    if (!u.startsWith('http')) return;
    final p = await CommerceApi.linkPreview(u);
    if (!mounted || p == null) return;
    setState(() {
      _linkTitle = p.title ?? _linkTitle;
      _linkImage = p.image ?? _linkImage;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = context.tr('Donne un titre à ta carte.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _fetchPreview();
      await CommerceApi.save(
        widget.postId,
        PostCommerce(postId: widget.postId, title: _title.text.trim(), priceText: _n(_price), place: _n(_place), whatsapp: _n(_wa)?.replaceAll(' ', ''), phone: _n(_phone)?.replaceAll(' ', ''), linkUrl: _n(_link), linkLabel: _label, linkTitle: _linkTitle, linkImage: _linkImage, collapsed: _collapsed),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.tr('Vérifie le numéro (avec l\'indicatif, par ex. +22890000000) et le lien (https://…). Il faut au moins un numéro ou un lien.');
        });
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await CommerceApi.remove(widget.postId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type, int? max, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(key: key, controller: c, keyboardType: type, maxLength: max, decoration: InputDecoration(labelText: context.tr(label), counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final st = widget.stats;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('Carte Commerce'), style: TextStyle(color: colors.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(context.tr('Une pastille sur ta publication : au toucher, elle montre le prix, le lieu et des boutons (WhatsApp, appel, lien).'), style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          if (st != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(12)),
              child: Text('${context.tr('Personnes ayant ouvert la carte')} : ${st.opened}  ·  WhatsApp : ${st.whatsapp}  ·  ${context.tr('Appel')} : ${st.call}  ·  ${context.tr('Lien')} : ${st.link}', style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 14),
          _field(_title, 'Titre (ex. Robes wax)', max: 80, key: const ValueKey('commerce_title')),
          _field(_price, 'Prix (ex. 15 000 F)', max: 40, key: const ValueKey('commerce_price')),
          _field(_place, 'Lieu (ex. Lomé, Tokoin)', max: 80),
          _field(_wa, 'WhatsApp (ex. +22890000000)', type: TextInputType.phone, max: 20, key: const ValueKey('commerce_wa')),
          _field(_phone, 'Numéro pour appeler', type: TextInputType.phone, max: 20),
          Focus(onFocusChange: (f) => f ? null : _fetchPreview(), child: _field(_link, 'Lien (https://…)', type: TextInputType.url, max: 600, key: const ValueKey('commerce_link_field'))),
          if (_linkTitle != null || _linkImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                if (_linkImage != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_linkImage!, width: 40, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 52))),
                const SizedBox(width: 10),
                Expanded(child: Text(_linkTitle ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 12.5))),
              ]),
            ),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final l in _labels) ChoiceChip(label: Text(context.tr(l)), selected: _label == l, onSelected: (_) => setState(() => _label = l)),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _collapsed, onChanged: (v) => setState(() => _collapsed = v), title: Text(context.tr('Pastille réduite au départ'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14))),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: colors.danger, fontSize: 12.5))),
          Row(children: [
            if (widget.existing != null) TextButton(key: const ValueKey('commerce_remove'), onPressed: _busy ? null : _remove, child: Text(context.tr('Retirer la carte'))),
            const Spacer(),
            FilledButton(key: const ValueKey('commerce_save'), onPressed: _busy ? null : _save, child: Text(context.tr('Enregistrer'))),
          ]),
        ]),
      ),
    );
  }
}
