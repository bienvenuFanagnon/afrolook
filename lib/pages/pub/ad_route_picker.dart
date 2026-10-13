import 'package:flutter/material.dart';

import 'ad_actions.dart';

/// Affiche un bottom sheet permettant à un admin (rôle ADM) de choisir
/// une route interne et un libellé de bouton pour une publicité.
///
/// Retourne un Map avec les clés :
///   - `actionType`       : `'route'`
///   - `actionUrl`        : `'afrolook://route/<path>'`
///   - `actionButtonText` : libellé saisi par l'admin
///
/// Retourne `null` si l'admin annule.
Future<Map<String, String>?> showAdRoutePicker(
  BuildContext context, {
  String? currentUrl,
  String? currentLabel,
}) {
  return showModalBottomSheet<Map<String, String>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AdRoutePickerSheet(
      currentUrl: currentUrl,
      currentLabel: currentLabel,
    ),
  );
}

class _AdRoutePickerSheet extends StatefulWidget {
  final String? currentUrl;
  final String? currentLabel;

  const _AdRoutePickerSheet({this.currentUrl, this.currentLabel});

  @override
  State<_AdRoutePickerSheet> createState() => _AdRoutePickerSheetState();
}

class _AdRoutePickerSheetState extends State<_AdRoutePickerSheet> {
  AdRoute? _selected;
  final TextEditingController _labelCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _labelCtrl.text = widget.currentLabel ?? '';
    if (widget.currentUrl != null &&
        widget.currentUrl!.startsWith(AdActions.routeScheme)) {
      final path =
          '/${widget.currentUrl!.substring(AdActions.routeScheme.length)}';
      try {
        _selected = kAdAppRoutes.firstWhere((r) => r.route == path);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, {
      'actionType': 'route',
      'actionUrl': '${AdActions.routeScheme}${_selected!.route.substring(1)}',
      'actionButtonText': _labelCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Poignée
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Titre
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.route, color: Color(0xFF2E7D32), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Choisir la page destination',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Champ libellé
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Form(
                key: _formKey,
                child: TextFormField(
                  controller: _labelCtrl,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Texte du bouton d\'action',
                    labelStyle:
                        const TextStyle(color: Colors.white54, fontSize: 13),
                    hintText: 'Ex : Découvrir, Rejoindre, Essayer…',
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.text_fields,
                        color: Colors.white38, size: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Le texte du bouton est obligatoire';
                    }
                    if (v.trim().length > 30) {
                      return 'Maximum 30 caractères';
                    }
                    return null;
                  },
                ),
              ),
            ),
            // Sous-titre liste
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sélectionner la page :',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            // Liste des routes
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding:
                    const EdgeInsets.only(bottom: 16, left: 12, right: 12),
                itemCount: kAdAppRoutes.length,
                itemBuilder: (_, i) {
                  final r = kAdAppRoutes[i];
                  final isSelected = _selected?.route == r.route;
                  return _RouteRow(
                    route: r,
                    selected: isSelected,
                    onTap: () => setState(() => _selected = r),
                  );
                },
              ),
            ),
            // Bouton confirmer
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, 8 + mq.viewInsets.bottom),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selected == null ? null : _confirm,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_selected == null
                        ? 'Choisir une page'
                        : 'Confirmer — ${_selected!.label}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final AdRoute route;
  final bool selected;
  final VoidCallback onTap;

  const _RouteRow({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2E7D32).withOpacity(0.18)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF2E7D32)
                : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2E7D32).withOpacity(0.25)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                route.icon,
                color: selected ? const Color(0xFF4CAF50) : Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route.description,
                    style: TextStyle(
                      color: selected
                          ? Colors.white54
                          : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF4CAF50), size: 20),
          ],
        ),
      ),
    );
  }
}
