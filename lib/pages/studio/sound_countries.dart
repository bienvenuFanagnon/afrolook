// Pays où un titre est proposé : même grille que les posts (Gratuit 1 pays, Premium 20, Gold tous), sans pièces en plus.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/utils/abonnement_utils.dart';
import '../../theme/app_colors.dart';

class SoundCountries {
  SoundCountries._();

  static String? homeOf(UserData u) {
    final c = u.countryData?['countryCode'];
    return (c != null && c.length == 2) ? c.toUpperCase() : null;
  }

  /// 1 pays (gratuit), 20 (Premium), 999 = tous (Gold, administrateur).
  static int limitOf(UserData u) {
    if (u.role == UserRole.ADM.name) return 999;
    if (AbonnementUtils.isGold(u.abonnement)) return 999;
    if (AbonnementUtils.isPremiumActive(u.abonnement)) return 20;
    return 1;
  }

  /// Un titre est montré à une personne si ses pays contiennent le sien, ou « tous ». Les anciens titres (sans liste) sont pour tous.
  /// Son propre titre et ceux qu'on a achetés restent toujours visibles.
  static bool visible(List<String> countries, String? viewerCountry) {
    if (countries.isEmpty || countries.contains('ALL')) return true;
    return viewerCountry != null && countries.contains(viewerCountry.toUpperCase());
  }

  /// Rang d'affichage : les titres visés précisément pour le pays de la personne passent avant ceux pour tous.
  static int rank(List<String> countries, String? viewerCountry) =>
      viewerCountry != null && countries.contains(viewerCountry.toUpperCase()) ? 0 : 1;

  static String summary(List<String> countries) {
    if (countries.isEmpty || countries.contains('ALL')) return '🌍 Tous les pays';
    final flags = <String>[];
    for (final code in countries.take(6)) {
      for (final c in AfricanCountry.everyCountry) {
        if (c.code == code) {
          flags.add(c.flag);
          break;
        }
      }
    }
    final more = countries.length > 6 ? ' +${countries.length - 6}' : '';
    return '${flags.join(' ')}$more · ${countries.length} pays';
  }

  /// Ouvre le choix des pays ; renvoie les codes choisis (ou ['ALL']), null si annulé.
  static Future<List<String>?> pick(BuildContext context, {required List<String> initial}) {
    final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Picker(initial: initial, limit: limitOf(user), home: homeOf(user)),
    );
  }

  /// Change les pays d'un titre déjà déposé (le serveur applique la grille).
  static Future<String> save(String soundId, List<String> countries) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('artistSoundCountries').call({'soundId': soundId, 'countries': countries});
      return 'Pays mis à jour.';
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Modification impossible.';
    } catch (_) {
      return 'Modification impossible. Vérifie ta connexion.';
    }
  }

  static String? viewerCountry(BuildContext context) => homeOf(Provider.of<UserAuthProvider>(context, listen: false).loginUserData);

  /// Filtre et classe des titres pour la personne : pays visés d'abord ; son propre titre est toujours montré.
  static List<T> forViewer<T>(Iterable<T> items, {required List<String> Function(T) countries, required String Function(T) owner, required String? viewerCountry}) {
    final me = viewerUid;
    final out = [for (final x in items) if (owner(x) == me || visible(countries(x), viewerCountry)) x];
    // tri stable : les titres visés pour son pays passent devant, l'ordre (récents d'abord) est gardé ensuite
    final idx = {for (var i = 0; i < out.length; i++) out[i]: i};
    out.sort((a, b) {
      final r = rank(countries(a), viewerCountry).compareTo(rank(countries(b), viewerCountry));
      return r != 0 ? r : idx[a]!.compareTo(idx[b]!);
    });
    return out;
  }

  static String? get viewerUid => FirebaseAuth.instance.currentUser?.uid;
}

class _Picker extends StatefulWidget {
  const _Picker({required this.initial, required this.limit, required this.home});
  final List<String> initial;
  final int limit;
  final String? home;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final Set<String> _sel = widget.initial.where((e) => e != 'ALL').toSet();
  late bool _all = widget.initial.contains('ALL') && widget.limit >= 999;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String get _grid => 'Gratuit : 1 pays · Premium : 20 pays · Gold : tous les pays.';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final list = AfricanCountry.search(AfricanCountry.sortedFor(widget.home), _q.text);
    final unlimited = widget.limit >= 999;
    return DraggableScrollableSheet(
      initialChildSize: .85,
      minChildSize: .5,
      maxChildSize: .95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: c.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Expanded(child: Text('Pays de ton titre', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w900))),
              Text(_all ? 'Tous' : '${_sel.length}/${unlimited ? '∞' : widget.limit}', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Ton titre est proposé aux personnes de ces pays. $_grid', style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Chercher un pays',
                hintStyle: TextStyle(color: c.textSecondary),
                prefixIcon: Icon(Icons.search, color: c.textSecondary),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          ListTile(
            leading: const Text('🌍', style: TextStyle(fontSize: 22)),
            title: Text('Tous les pays', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text(unlimited ? 'Ton abonnement le permet' : 'Réservé aux abonnés Gold', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            trailing: unlimited ? Switch(value: _all, activeColor: c.primary, onChanged: (v) => setState(() => _all = v)) : Icon(Icons.lock_outline, color: c.textSecondary),
            onTap: unlimited ? () => setState(() => _all = !_all) : () => _toast('Tous les pays : réservé aux abonnés Gold. $_grid'),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final co = list[i];
                final on = _all || _sel.contains(co.code);
                return ListTile(
                  dense: true,
                  enabled: !_all,
                  leading: Text(co.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(co.name, style: TextStyle(color: _all ? c.textSecondary : c.textPrimary, fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
                  trailing: Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined, color: on ? c.primary : c.textSecondary),
                  onTap: () {
                    if (_sel.contains(co.code)) {
                      setState(() => _sel.remove(co.code));
                    } else if (_sel.length >= widget.limit) {
                      _toast(widget.limit == 1 ? 'Compte gratuit : 1 pays. Passe Premium (20 pays) ou Gold (tous). ' : 'Limite de ${widget.limit} pays atteinte. Passe Gold pour tous les pays.');
                    } else {
                      setState(() => _sel.add(co.code));
                    }
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: (_all || _sel.isNotEmpty) ? () => Navigator.pop(context, _all ? ['ALL'] : _sel.toList()) : null,
                  style: FilledButton.styleFrom(backgroundColor: c.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
