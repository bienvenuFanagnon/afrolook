import 'package:flutter/material.dart';

import '../data/country_list.dart';
import '../l10n/tr.dart';
import '../theme/app_colors.dart';

/// Sélecteur de pays, région et ville LÉGER (09/11/2026) : il remplace `csc_picker_plus`, dont la liste mondiale des villes (25,7 Mo) alourdissait l'application
/// sur Android comme sur iPhone. Le pays se choisit dans une liste avec recherche (mêmes noms que l'ancien paquet, donc compatibles avec les profils déjà
/// enregistrés) ; la région et la ville se saisissent librement (facultatives).
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    this.countryFilter,
    this.initialCountry,
    this.initialState = '',
    this.initialCity = '',
    this.showStateCity = true,
    this.fillColor,
    this.textColor,
    this.hintColor,
    this.borderColor,
    this.accentColor,
    this.radius = 12,
    required this.onCountryChanged,
    this.onStateChanged,
    this.onCityChanged,
  });

  /// Pays proposés (noms comme dans [kCountryList]) ; null = tous.
  final List<String>? countryFilter;

  /// Pays affiché au départ ; l'écran en est aussitôt prévenu (comme l'ancien paquet avec `defaultCountry`).
  final String? initialCountry;
  final String initialState;
  final String initialCity;
  final bool showStateCity;
  final Color? fillColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? borderColor;
  final Color? accentColor;
  final double radius;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String>? onStateChanged;
  final ValueChanged<String>? onCityChanged;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  String _country = '';
  late final TextEditingController _state = TextEditingController(text: widget.initialState);
  late final TextEditingController _city = TextEditingController(text: widget.initialCity);

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry ?? '';
    if (_country.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? widget.onCountryChanged(_country) : null);
  }

  @override
  void dispose() {
    _state.dispose();
    _city.dispose();
    super.dispose();
  }

  List<(String name, String flag)> get _options {
    final f = widget.countryFilter;
    if (f == null) return kCountryList;
    return [for (final n in f) (n, countryFlag(n))];
  }

  Future<void> _pickCountry() async {
    final c = AppColors.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CountrySheet(options: _options, selected: _country),
    );
    if (picked == null || !mounted) return;
    setState(() => _country = picked);
    widget.onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fill = widget.fillColor ?? c.surface;
    final text = widget.textColor ?? c.textPrimary;
    final hint = widget.hintColor ?? c.textSecondary;
    final border = widget.borderColor ?? c.border;
    final flag = _country.isEmpty ? '' : countryFlag(_country);
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: hint),
          filled: true,
          fillColor: fill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(widget.radius), borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(widget.radius), borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(widget.radius), borderSide: BorderSide(color: widget.accentColor ?? c.primary, width: 1.6)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        key: const ValueKey('location_country'),
        borderRadius: BorderRadius.circular(widget.radius),
        onTap: _pickCountry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(widget.radius), border: Border.all(color: border)),
          child: Row(children: [
            if (flag.isNotEmpty) ...[Text(flag, style: const TextStyle(fontSize: 20)), const SizedBox(width: 10)],
            Expanded(child: Text(_country.isEmpty ? context.tr('Sélectionnez un pays') : _country, style: TextStyle(color: _country.isEmpty ? hint : text, fontSize: 14.5))),
            Icon(Icons.arrow_drop_down_rounded, color: hint),
          ]),
        ),
      ),
      if (widget.showStateCity) ...[
        const SizedBox(height: 10),
        TextField(key: const ValueKey('location_state'), controller: _state, enabled: _country.isNotEmpty, style: TextStyle(color: text), decoration: deco(context.tr('Région (facultatif)')), onChanged: (v) => widget.onStateChanged?.call(v.trim())),
        const SizedBox(height: 10),
        TextField(key: const ValueKey('location_city'), controller: _city, enabled: _country.isNotEmpty, style: TextStyle(color: text), decoration: deco(context.tr('Ville (facultatif)')), onChanged: (v) => widget.onCityChanged?.call(v.trim())),
      ],
    ]);
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.options, required this.selected});
  final List<(String name, String flag)> options;
  final String selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final q = _q.trim().toLowerCase();
    final list = [for (final o in widget.options) if (q.isEmpty || o.$1.toLowerCase().contains(q)) o];
    final h = MediaQuery.sizeOf(context).height * .8;
    return SafeArea(
      child: SizedBox(
        height: h,
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('country_search'),
              autofocus: false,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: context.tr('Rechercher un pays'),
                hintStyle: TextStyle(color: c.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
                filled: true,
                fillColor: c.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text(context.tr('Aucun pays trouvé.'), style: TextStyle(color: c.textSecondary)))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final o = list[i];
                        final sel = o.$1 == widget.selected;
                        return ListTile(
                          key: ValueKey('country_${o.$1}'),
                          leading: Text(o.$2, style: const TextStyle(fontSize: 22)),
                          title: Text(o.$1, style: TextStyle(color: c.textPrimary, fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
                          trailing: sel ? Icon(Icons.check_circle_rounded, color: c.primary) : null,
                          onTap: () => Navigator.pop(context, o.$1),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
