import 'package:country_code_picker/country_code_picker.dart' show codes;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';

import 'card_models.dart';

/// Drapeaux des styles « drapeau » : mêmes fichiers que le paquet `country_flags`, chargés une fois et gardés en mémoire
/// pour que l'export de la carte n'attende jamais un drapeau.
class CardFlags {
  CardFlags._();

  static final Map<String, Future<void>> _warm = {};

  /// Pays utilisé quand ni l'auteur ni le choix de la personne n'en donnent un.
  static const fallback = 'TG';
  static const fallback2 = 'FR';

  static String normalize(String? code, {String or = fallback}) {
    final c = (code ?? '').trim().toUpperCase();
    return c.length == 2 && flagExists(c) ? c : or;
  }

  static bool flagExists(String c) => codes.any((m) => m['code'] == c);

  /// Lit le fichier du drapeau une première fois (échauffement avant un export) ; sans erreur.
  static Future<void> load(String code) => _warm.putIfAbsent(code.toLowerCase(), () async {
        try {
          await rootBundle.load('packages/country_flags/res/si/${code.toLowerCase()}.si');
        } catch (_) {}
      });

  static Future<void> precache(Iterable<String> list) => Future.wait(list.map(load));

  /// Le ou les drapeaux d'une carte : choix de la personne, sinon pays de l'auteur, sinon [fallback] ; [duo] en a deux.
  static List<String> flagsOf(CardSource source, CardSpec spec) {
    final a = normalize(spec.country ?? source.country);
    return [a, if (spec.style.usesSecondFlag) normalize(spec.country2, or: a == fallback2 ? fallback : fallback2)];
  }

  /// Code ISO à 3 lettres (SEN, TGO…) ; null si inconnu.
  static String? iso3(String code) {
    for (final m in codes) {
      if (m['code'] == code.toUpperCase()) return m['iso3Code'];
    }
    return null;
  }

  /// Nom du pays (celui de `country_code_picker`, en français) ; le code si inconnu.
  static String name(String code) {
    for (final m in codes) {
      if (m['code'] == code.toUpperCase()) return m['name'] ?? code;
    }
    return code;
  }

  /// Tous les pays proposés dans le sélecteur : code et nom, par ordre alphabétique.
  static List<({String code, String name})> all() {
    final out = [for (final m in codes) (code: m['code'] ?? '', name: m['name'] ?? '')]..removeWhere((e) => e.code.length != 2);
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }
}

/// Un drapeau qui remplit son espace (recadré, comme `BoxFit.cover`) : il sert de fond ou de motif.
/// Chaque instance charge son propre dessin (le fichier est tout petit) : on ne partage jamais un même objet entre deux arbres.
class CardFlag extends StatefulWidget {
  const CardFlag(this.code, {super.key, this.fit = BoxFit.cover});
  final String code;
  final BoxFit fit;

  @override
  State<CardFlag> createState() => _CardFlagState();
}

class _CardFlagState extends State<CardFlag> {
  ScalableImage? _si;
  String? _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CardFlag old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) _load();
  }

  Future<void> _load() async {
    final code = widget.code.toLowerCase();
    if (_loaded == code) return;
    _loaded = code;
    ScalableImage? si;
    try {
      si = await ScalableImage.fromSIAsset(rootBundle, 'packages/country_flags/res/si/$code.si');
    } catch (_) {}
    if (mounted && _loaded == code) setState(() => _si = si);
  }

  @override
  Widget build(BuildContext context) => _si == null ? const ColoredBox(color: Color(0xFF444444)) : ScalableImageWidget(si: _si!, fit: widget.fit);
}
