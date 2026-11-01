import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/ad_config_service.dart';
import 'package:afrotok/services/api/wallet_api.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:afrotok/widgets/api_error_dialogs.dart';
import 'package:afrotok/widgets/coin_balances_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Pièces communes aux pages de boost payant (publication, profil, canal, groupe) et au renouvellement.
class BoostUi {
  BoostUi._();

  /// Choix du type d'action d'une publicité de publication.
  static const Map<String, String> actionLabels = {
    'visit': 'Visiter',
    'learn_more': 'En savoir plus',
    'download': 'Télécharger',
    'whatsapp': 'WhatsApp',
    'none': 'Aucun bouton',
  };

  /// Tarif affiché sur les boutons de durée, à partir du tarif de la durée (affichage seul : le serveur calcule le prix à payer et fait foi).
  static int estimateCoins(List<AdDuration> durations, int weeks, {bool combined = false}) {
    final base = AdConfigService.toMap(durations)[weeks] ?? 0;
    return CoinCheckout.coinsFor((combined ? (base * 1.5).round() : base).toDouble());
  }

  /// Prix en pièces demandé AU SERVEUR (`GET /purchases/quote`, `combined` accepté en texte). Aucune estimation de repli : si le devis
  /// échoue (réseau, durée refusée…), l'erreur remonte et l'écran affiche un message en français avec « Réessayer ».
  static Future<int> quote(String kind, int weeks, List<AdDuration> durations, {bool combined = false}) async {
    final c = await WalletApi.instance.quote(kind, weeks: weeks, combined: combined ? true : null);
    if (c <= 0) {
      throw ApiException(status: 0, code: 'quote_unavailable', message: "Le prix n'a pas pu être calculé pour le moment. Vérifie ta connexion puis réessaie.");
    }
    return c;
  }

  /// Fenêtre de confirmation du prix. Renvoie true si la personne paie (et que son solde suffit).
  static Future<bool> confirmPrice(BuildContext context, {required String title, required int coins, String? detail}) async {
    final user = context.read<UserAuthProvider>().loginUserData;
    if ((user.giftCoinsBalance ?? 0) < coins) {
      await CoinCheckout.insufficient(context, coins);
      return false;
    }
    if (!context.mounted) return false;
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(CoinCheckout.coinsLabel(coins), style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          if (detail != null) ...[const SizedBox(height: 6), Text(detail, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.35))],
          const SizedBox(height: 12),
          CoinBalancesInline(user: user),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Payer')),
        ],
      ),
    );
    return ok == true;
  }

  /// Relit les soldes sur l'API après un paiement.
  static Future<void> refreshBalance(BuildContext context) => CoinCheckout.refreshBalance(context);

  /// Erreur d'un paiement : 402 → recharger ; sinon bannière avec « Réessayer ».
  static void showError(BuildContext context, Object e, VoidCallback onRetry, {String fallback = 'Impossible d\'envoyer la demande. Réessaie.'}) =>
      handleApiError(context, e, onRetry: onRetry, fallback: fallback);

  /// Sélection de pays (liste cherchable). Renvoie les codes choisis, ou null si la personne annule.
  static Future<Set<String>?> pickCountries(BuildContext context, Set<String> initial) async {
    final all = AfricanCountry.everyCountry;
    final chosen = {...initial};
    var confirmed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(builder: (ctx, setM) {
          final c = AppColors.of(ctx);
          final list = all.where((x) => x.name.toLowerCase().contains(q) || x.code.toLowerCase().contains(q)).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.8,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  onChanged: (v) => setM(() => q = v.trim().toLowerCase()),
                  decoration: const InputDecoration(hintText: 'Chercher un pays', prefixIcon: Icon(Icons.search)),
                ),
              ),
              Expanded(
                child: ListView(children: [
                  for (final x in list)
                    CheckboxListTile(
                      value: chosen.contains(x.code),
                      onChanged: (v) => setM(() => v == true ? chosen.add(x.code) : chosen.remove(x.code)),
                      title: Text('${x.flag}  ${x.name}', style: TextStyle(color: c.textPrimary)),
                    ),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        confirmed = true;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Valider'),
                    ),
                  ),
                ),
              ),
            ]),
          );
        });
      },
    );
    return confirmed ? chosen : null;
  }
}

/// Choix de la durée (tarifs lus sur `GET /config`, clé `ad_durations`).
class BoostDurationChips extends StatelessWidget {
  const BoostDurationChips({super.key, required this.durations, required this.selected, required this.onSelected, this.combined = false, this.color});
  final List<AdDuration> durations;
  final int? selected;
  final ValueChanged<int> onSelected;
  final bool combined;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.of(context).primary;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final d in durations)
        ChoiceChip(
          selected: selected == d.weeks,
          onSelected: (_) => onSelected(d.weeks),
          label: Text('${d.label} · ${CoinCheckout.coinsLabel(BoostUi.estimateCoins(durations, d.weeks, combined: combined))}'),
          selectedColor: accent.withOpacity(0.25),
        ),
    ]);
  }
}

/// Bloc « pays visés » : « partout » ou une liste choisie.
class BoostCountriesField extends StatelessWidget {
  const BoostCountriesField({super.key, required this.allCountries, required this.countries, required this.onAllChanged, required this.onCountriesChanged});
  final bool allCountries;
  final Set<String> countries;
  final ValueChanged<bool> onAllChanged;
  final ValueChanged<Set<String>> onCountriesChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: allCountries,
        onChanged: onAllChanged,
        title: Text('Diffuser partout', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        subtitle: Text(allCountries ? 'Tous les pays' : '${countries.length} pays choisis', style: TextStyle(color: c.textSecondary)),
      ),
      if (!allCountries)
        OutlinedButton.icon(
          onPressed: () async {
            final r = await BoostUi.pickCountries(context, countries);
            if (r != null) onCountriesChanged(r);
          },
          icon: const Icon(Icons.public),
          label: const Text('Choisir les pays'),
        ),
    ]);
  }
}
