import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';
import '../../utils/platform_guard.dart';

/// Carte de vente d'une chronique business (produit, prix, lieu, WhatsApp, appel, lien « Commander maintenant »). Même idée que la carte Commerce des publications :
/// les boutons sont dans l'application, seule la carte est cliquable. Posée par l'auteur à la création, relue par le serveur à la lecture.
class ChroniqueCommerceLink {
  ChroniqueCommerceLink._();

  static Map<String, dynamic>? _value;

  static void set(Map<String, dynamic>? v) => _value = v;

  /// À la publication : la carte en attente, puis effacée (une seule chronique).
  static Map<String, dynamic>? take() {
    final v = _value;
    _value = null;
    return v;
  }
}

/// Feuille de saisie de la carte de vente. Rend la carte (clés de l'API) ou null si la personne annule ; une carte vide (produit absent) = pas de carte.
Future<Map<String, dynamic>?> showChroniqueCommerceEditor(BuildContext context, {Map<String, dynamic>? initial}) {
  final c = AppColors.of(context);
  final title = TextEditingController(text: '${initial?['title'] ?? ''}');
  final price = TextEditingController(text: '${initial?['price_text'] ?? ''}');
  final place = TextEditingController(text: '${initial?['place'] ?? ''}');
  final whatsapp = TextEditingController(text: '${initial?['whatsapp'] ?? ''}');
  final phone = TextEditingController(text: '${initial?['phone'] ?? ''}');
  final link = TextEditingController(text: '${initial?['link_url'] ?? ''}');
  String? error;
  InputDecoration deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: c.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
      );
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 12),
            Text(ctx.tr('Carte de vente'), style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(ctx.tr('Les spectateurs voient le produit et peuvent te contacter en un geste.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(controller: title, maxLength: 80, decoration: deco(ctx.tr('Produit'))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: price, maxLength: 40, decoration: deco(ctx.tr('Prix'), hint: '12 500 F'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: place, maxLength: 80, decoration: deco(ctx.tr('Lieu')))),
            ]),
            const SizedBox(height: 6),
            TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: deco('WhatsApp', hint: '+22890000000')),
            const SizedBox(height: 8),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: deco(ctx.tr('Téléphone (appel)'), hint: '+22890000000')),
            const SizedBox(height: 8),
            TextField(controller: link, keyboardType: TextInputType.url, decoration: deco(ctx.tr('Lien « Commander maintenant » (facultatif)'), hint: 'https://')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: c.danger, fontSize: 12.5))),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () {
                  final t = title.text.trim();
                  final wa = whatsapp.text.replaceAll(RegExp(r'[\s\-.()]'), '');
                  final ph = phone.text.replaceAll(RegExp(r'[\s\-.()]'), '');
                  final lk = link.text.trim();
                  final phoneOk = RegExp(r'^\+?[0-9]{6,15}$');
                  if (t.isEmpty) return set(() => error = ctx.tr('Indique le produit.'));
                  if (wa.isEmpty && ph.isEmpty && lk.isEmpty) return set(() => error = ctx.tr('Ajoute un WhatsApp, un téléphone ou un lien.'));
                  if (wa.isNotEmpty && !phoneOk.hasMatch(wa)) return set(() => error = ctx.tr('Numéro WhatsApp invalide (avec l\'indicatif du pays).'));
                  if (ph.isNotEmpty && !phoneOk.hasMatch(ph)) return set(() => error = ctx.tr('Numéro de téléphone invalide (avec l\'indicatif du pays).'));
                  if (lk.isNotEmpty && !(lk.startsWith('https://') || lk.startsWith('http://'))) return set(() => error = ctx.tr('Le lien doit commencer par https://'));
                  Navigator.pop(ctx, {
                    'title': t,
                    if (price.text.trim().isNotEmpty) 'price_text': price.text.trim(),
                    if (place.text.trim().isNotEmpty) 'place': place.text.trim(),
                    if (wa.isNotEmpty) 'whatsapp': wa,
                    if (ph.isNotEmpty) 'phone': ph,
                    if (lk.isNotEmpty) 'link_url': lk,
                  });
                },
                style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                child: Text(ctx.tr('Ajouter à la chronique'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

/// Carte posée sur la chronique à la lecture (et dans l'aperçu avant publication) : produit, prix, « Commander maintenant », WhatsApp, appel.
/// Sur iPhone et iPad le bouton de lien externe n'est pas montré (règle App Store sur les achats de contenus numériques hors achat intégré).
class ChroniqueCommerceCard extends StatelessWidget {
  const ChroniqueCommerceCard({super.key, required this.commerce, this.preview = false});

  final Map<String, dynamic> commerce;

  /// Aperçu avant publication : les boutons ne lancent rien.
  final bool preview;

  Future<void> _open(Uri uri) async {
    if (preview) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final title = '${commerce['title'] ?? ''}';
    final price = commerce['price_text'] as String?;
    final place = commerce['place'] as String?;
    final wa = commerce['whatsapp'] as String?;
    final phone = commerce['phone'] as String?;
    final link = commerce['link_url'] as String?;
    final label = (commerce['link_label'] as String?)?.isNotEmpty == true ? commerce['link_label'] as String : context.tr('Commander maintenant');
    Widget btn(String text, VoidCallback onTap, {bool primary = false, IconData? icon}) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(color: primary ? const Color(0xFF1B8A3C) : const Color(0xFFE6F6EC), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: 15, color: primary ? Colors.white : const Color(0xFF14663A)), const SizedBox(width: 4)],
                Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: primary ? Colors.white : const Color(0xFF14663A), fontSize: 12, fontWeight: FontWeight.w800))),
              ]),
            ),
          ),
        );
    final buttons = <Widget>[
      if (link != null && link.isNotEmpty && !kIsAppleStore) btn(label, () => _open(Uri.parse(link)), primary: true, icon: Icons.shopping_bag_outlined),
      if (wa != null && wa.isNotEmpty) btn('WhatsApp', () => _open(Uri.parse('https://wa.me/${wa.replaceAll('+', '')}')), icon: Icons.chat_rounded),
      if (phone != null && phone.isNotEmpty) btn(context.tr('Appeler'), () => _open(Uri.parse('tel:$phone')), icon: Icons.call_rounded),
    ];
    return Container(
      key: const ValueKey('chronique_commerce_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.97), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6))]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF15201A), fontWeight: FontWeight.w800, fontSize: 14.5)),
        if (price != null && price.isNotEmpty) Text(price, style: const TextStyle(color: Color(0xFF1B8A3C), fontWeight: FontWeight.w900, fontSize: 18)),
        if (place != null && place.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [const Icon(Icons.place_rounded, size: 14, color: Color(0xFF5D6B63)), const SizedBox(width: 3), Expanded(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5D6B63), fontSize: 12)))])),
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(width: 6), buttons[i]]]),
        ],
      ]),
    );
  }
}
