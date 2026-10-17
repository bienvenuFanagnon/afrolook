import 'package:afrotok/layout/centered_content.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/card_coins.dart';
import '../../theme/app_colors.dart';
import '../../utils/payment_region.dart';

/// Pays proposés pour l'adresse de facturation de la carte (code ISO → nom).
const Map<String, String> kCardCountries = {
  'BJ': 'Bénin', 'TG': 'Togo', 'CI': "Côte d'Ivoire", 'SN': 'Sénégal', 'BF': 'Burkina Faso', 'ML': 'Mali', 'NE': 'Niger',
  'GN': 'Guinée', 'CM': 'Cameroun', 'GA': 'Gabon', 'CG': 'Congo', 'CD': 'RD Congo', 'MG': 'Madagascar', 'MA': 'Maroc',
  'DZ': 'Algérie', 'TN': 'Tunisie', 'EG': 'Égypte', 'NG': 'Nigeria', 'GH': 'Ghana', 'KE': 'Kenya', 'ZA': 'Afrique du Sud',
  'FR': 'France', 'BE': 'Belgique', 'CH': 'Suisse', 'LU': 'Luxembourg', 'DE': 'Allemagne', 'ES': 'Espagne', 'IT': 'Italie',
  'PT': 'Portugal', 'NL': 'Pays-Bas', 'GB': 'Royaume-Uni', 'IE': 'Irlande', 'CA': 'Canada', 'US': 'États-Unis',
  'AE': 'Émirats arabes unis', 'CN': 'Chine', 'JP': 'Japon', 'BR': 'Brésil',
};

/// Achat de pièces par carte bancaire — Afrolook Web uniquement (voir [CardCoins]).
class CardCoinPage extends StatefulWidget {
  const CardCoinPage({super.key, this.prefill});

  /// Profil utilisé pour pré-remplir le formulaire (tests) ; par défaut, le compte connecté.
  final UserData? prefill;

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CardCoinPage()));

  /// Au retour de la page de paiement FeexPay (web) : annonce le résultat de la commande en cours.
  static Future<void> resume(BuildContext context) async {
    final coins = await CardCoins.resumePending();
    if (coins == null || !context.mounted) return;
    final f = NumberFormat.decimalPattern('fr');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text(coins > 0
          ? context.tr('Paiement confirmé : {n} pièces ajoutées à ton compte.', {'n': f.format(coins)})
          : context.tr("Le paiement par carte n'a pas abouti. Tu n'as pas été débité.")),
    ));
  }

  @override
  State<CardCoinPage> createState() => _CardCoinPageState();
}

class _CardCoinPageState extends State<CardCoinPage> {
  CardQuote? _quote;
  bool _loading = true;
  bool _busy = false;
  bool _terms = false;
  int? _coins;
  String? _error;
  String _country = 'FR';
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();

  static final _usd = NumberFormat('#,##0.00', 'fr');
  static final _n = NumberFormat.decimalPattern('fr');

  @override
  void initState() {
    super.initState();
    final me = widget.prefill ?? context.read<UserAuthProvider>().loginUserData;
    _first.text = me.prenom ?? '';
    _last.text = me.nom ?? '';
    _phone.text = (me.numeroDeTelephone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    final c = PaymentRegion.countryOf(me);
    if (c != null && kCardCountries.containsKey(c)) _country = c;
    CardCoins.quote().then((q) {
      if (!mounted) return;
      setState(() {
        _quote = q;
        _loading = false;
        if (q != null && q.packs.isNotEmpty) _coins = q.packs.length > 2 ? q.packs[2].coins : q.packs.first.coins;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _city, _zip]) {
      c.dispose();
    }
    super.dispose();
  }

  CardPack? get _pack => _quote?.packs.where((p) => p.coins == _coins).firstOrNull;

  Future<void> _pay() async {
    final p = _pack;
    if (p == null || _busy) return;
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty || _city.text.trim().isEmpty || _zip.text.trim().isEmpty || digits.length < 8) {
      setState(() => _error = context.tr('Renseigne ton nom, ta ville, ton code postal, ton pays et ton téléphone.'));
      return;
    }
    if (!_terms) {
      setState(() => _error = context.tr('Accepte les conditions pour continuer.'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await CardCoins.pay(
        coins: p.coins, firstName: _first.text.trim(), lastName: _last.text.trim(), phone: digits,
        city: _city.text.trim(), zip: _zip.text.trim(), country: _country,
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message ?? context.tr('Le paiement par carte a échoué. Réessaie.'); });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = context.tr('Le paiement par carte a échoué. Réessaie.'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.tr('Payer par carte bancaire'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: CenteredContent(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_quote == null || !_quote!.enabled || _quote!.packs.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.tr('Le paiement par carte est momentanément indisponible. Utilise le Mobile Money.'),
                          textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
                    ),
                  )
                : _form(colors, _quote!),
      ),
    );
  }

  Widget _form(AppColors colors, CardQuote q) {
    final p = _pack;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.primary.withValues(alpha: 0.4))),
          child: Row(children: [
            Icon(Icons.lock_rounded, color: colors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(context.tr('Paiement sécurisé par FeexPay (3-D Secure). Tes données de carte ne passent jamais par Afrolook.'),
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.5, height: 1.35)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(context.tr('Choisis ton pack'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        for (final pk in q.packs) _packTile(colors, pk, q),
        const SizedBox(height: 6),
        Text(
          context.tr('Prix en dollars US, frais bancaires et de conversion inclus ({p} %). Équivalent en FCFA indicatif.', {'p': q.feePct.toStringAsFixed(1).replaceAll('.', ',')}),
          style: TextStyle(color: colors.textSecondary, fontSize: 11.5, height: 1.35),
        ),
        const SizedBox(height: 18),
        Text(context.tr('Informations de facturation'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field(colors, _first, context.tr('Prénom'))),
          const SizedBox(width: 10),
          Expanded(child: _field(colors, _last, context.tr('Nom'))),
        ]),
        const SizedBox(height: 10),
        _field(colors, _phone, context.tr('Téléphone (avec indicatif)'), keyboard: TextInputType.phone),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(flex: 3, child: _field(colors, _city, context.tr('Ville'))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _field(colors, _zip, context.tr('Code postal'))),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _country,
          isExpanded: true,
          decoration: _deco(colors, context.tr('Pays')),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          items: [for (final e in kCardCountries.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _country = v ?? _country),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => setState(() => _terms = !_terms),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false), activeColor: colors.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  context.tr("J'accepte que ce paiement international soit débité en dollars US. Les pièces achetées ne sont pas convertibles en argent et ne sont pas remboursables une fois utilisées."),
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.5, height: 1.4),
                ),
              ),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_busy || p == null) ? null : _pay,
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _busy
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.onPrimary))
                : Text(p == null ? context.tr('Payer') : context.tr('Payer {a} \$', {'a': _usd.format(p.total)}),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 10),
        Text(context.tr('Tu seras redirigé vers la page de paiement sécurisée, puis ramené sur Afrolook. Tes pièces sont ajoutées dès la confirmation.'),
            style: TextStyle(color: colors.textSecondary, fontSize: 11.5, height: 1.35)),
      ]),
    );
  }

  Widget _packTile(AppColors colors, CardPack pk, CardQuote q) {
    final sel = pk.coins == _coins;
    final fcfa = (pk.total * q.xofPerUsd / 10).round() * 10;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _coins = pk.coins),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? colors.primary.withValues(alpha: 0.1) : colors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? colors.primary : colors.border, width: sel ? 1.6 : 1),
          ),
          child: Row(children: [
            Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? colors.primary : colors.textSecondary, size: 20),
            const SizedBox(width: 10),
            const Text('🪙', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.tr('{n} pièces', {'n': _n.format(pk.coins)}), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_usd.format(pk.total)} \$', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              Text('≈ ${_n.format(fcfa)} FCFA', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
            ]),
          ]),
        ),
      ),
    );
  }

  InputDecoration _deco(AppColors colors, String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: colors.surfaceVariant,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
      );

  Widget _field(AppColors colors, TextEditingController c, String label, {TextInputType? keyboard}) => TextField(
        controller: c,
        keyboardType: keyboard,
        style: TextStyle(color: colors.textPrimary, fontSize: 14),
        decoration: _deco(colors, label),
      );
}
