// pages/retrait/user_retrait_page.dart
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/user/UserRetrait/userRetraitListe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../models/payment_config.dart';
import '../../../providers/authProvider.dart';
import '../../../services/payment_methods_config_service.dart';
import '../../../services/retraitService.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/tr.dart';
import '../../../services/currency_service.dart';
import '../../../utils/tx_amount.dart';

/// Formulaire de demande de retrait (thèmes clair et sombre via [AppColors]).
/// La demande est enregistrée dans Firestore puis traitée manuellement.
class UserDemandeRetraitPage extends StatefulWidget {
  @override
  _UserDemandeRetraitPageState createState() => _UserDemandeRetraitPageState();
}

class _UserDemandeRetraitPageState extends State<UserDemandeRetraitPage> {
  static const double _minRetrait = 2500;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();

  PaymentConfig? _selectedCountry;
  PaymentMethod? _selectedMethod;

  bool _isLoading = false;
  bool _hasAcceptedConditions = false;
  List<PaymentConfig> _availableCountries = [];

  // Retrait hors Mobile Money (virement, carte, PayPal) : demande traitée à la main
  bool _manual = false;
  AfricanCountry? _manualCountry;
  String _manualMethod = 'bank';
  final TextEditingController _holderController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  CurrencyService get _cur => CurrencyService.instance;

  /// Minimum en FCFA : 2 500 FCFA en Mobile Money, l'équivalent de 100 $ sinon.
  double get _minFcfa => _manual ? _cur.toFcfa(100, 'USD') : _minRetrait;

  /// Montant saisi (dans la devise de l'utilisateur) converti en FCFA.
  double? get _montantFcfa {
    final v = double.tryParse(_montantController.text.replaceAll(',', '.').replaceAll(' ', ''));
    return v == null ? null : _cur.toFcfa(v);
  }

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _numeroController.dispose();
    _holderController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    await PaymentMethodsConfigService.instance.load();
    final svc = PaymentMethodsConfigService.instance;
    final countries = PaymentConfig.activeCountries
        .map((c) => PaymentConfig(
              countryCode: c.countryCode,
              countryName: c.countryName,
              phoneCode: c.phoneCode,
              phoneLength: c.phoneLength,
              paymentMethods: c.paymentMethods
                  .where((m) => svc.isPayoutEnabled(m.code))
                  .toList(),
            ))
        .where((c) => c.paymentMethods.isNotEmpty)
        .toList();
    if (mounted) {
      final userCountry = (Provider.of<UserAuthProvider>(context, listen: false)
                  .loginUserData
                  .countryData?['countryCode'] ??
              '')
          .toUpperCase();
      setState(() {
        _availableCountries = countries;
        final mine = countries.where((c) => c.countryCode == userCountry).toList();
        if (countries.isNotEmpty) _selectedCountry = mine.isNotEmpty ? mine.first : countries.first;
        // Pays sans Mobile Money : demande manuelle par défaut
        _manual = mine.isEmpty && userCountry.isNotEmpty;
        final world = AfricanCountry.everyCountry.where((c) => c.code == userCountry).toList();
        _manualCountry = world.isNotEmpty ? world.first : null;
      });
    }
  }

  // ========== VALIDATION DES HORAIRES DE RETRAIT ==========
  bool _isRetraitAllowed() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final hour = now.hour;
    final minute = now.minute;

    if (weekday == 7) return false;
    if (weekday == 6) {
      if (hour < 8 || (hour == 14 && minute > 0) || hour > 14) return false;
      return true;
    }
    if (hour < 8 || (hour == 17 && minute > 0) || hour > 17) return false;
    return true;
  }

  // Validation du numéro selon le pays sélectionné
  String? _validatePhoneNumber(String? value) {
    if (_selectedCountry == null) return context.tr('Sélectionnez un pays');
    return _selectedCountry!.validatePhoneNumber(value);
  }

  // Mise à jour des méthodes de paiement quand le pays change
  void _onCountryChanged(PaymentConfig? newCountry) {
    setState(() {
      _selectedCountry = newCountry;
      _selectedMethod = null;
      _numeroController.clear();
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final authProvider = context.watch<UserAuthProvider>();
    final userData = authProvider.loginUserData;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(context.tr('Demande de retrait'),
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long_rounded, color: c.textPrimary),
            tooltip: context.tr('Mes retraits'),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => UserRetraitListPage())),
          ),
        ],
      ),
      body: CenteredContent(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildSoldeCard(userData, c),
              const SizedBox(height: 16),
              _buildModeSwitch(c),
              const SizedBox(height: 16),
              if (!_manual) ...[
                _buildCountrySelector(c),
                const SizedBox(height: 14),
                _buildMontantField(c),
                if (_selectedCountry != null) ...[
                  const SizedBox(height: 14),
                  _buildMethodDropdown(c),
                  const SizedBox(height: 14),
                  _buildNumeroField(c),
                ],
              ] else ...[
                _buildManualCountry(c),
                const SizedBox(height: 14),
                _buildMontantField(c),
                const SizedBox(height: 14),
                _buildManualFields(c),
              ],
              const SizedBox(height: 16),
              _buildConditionsCheckbox(c),
              const SizedBox(height: 16),
              _buildSubmitButton(authProvider, c),
              const SizedBox(height: 20),
              _buildProcedure(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoldeCard(UserData userData, AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Gains à retirer'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(
            Money.fmt(userData.votre_solde_principal ?? 0),
            style: TextStyle(
              color: c.primary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          _infoLine(c, Icons.south_rounded, context.tr('Minimum de retrait : {a}', {'a': Money.fmt(_minFcfa)})),
          const SizedBox(height: 4),
          _infoLine(c, Icons.schedule_rounded, context.tr('Lun-ven 8h-17h · sam 8h-14h · fermé le dimanche')),
        ],
      ),
    );
  }

  Widget _infoLine(AppColors c, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: c.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
      ],
    );
  }

  Widget _label(AppColors c, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Row(
        children: [
          Text(text, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(AppColors c, {String? hint, IconData? icon, String? suffix, String? helper, String? prefix}) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textSecondary),
      helperText: helper,
      helperStyle: TextStyle(color: c.textSecondary, fontSize: 11),
      filled: true,
      fillColor: c.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: icon != null ? Icon(icon, color: c.textSecondary, size: 20) : null,
      prefixText: prefix,
      prefixStyle: TextStyle(color: c.textPrimary, fontSize: 15),
      suffixText: suffix,
      suffixStyle: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
      border: border(c.border),
      enabledBorder: border(c.border),
      focusedBorder: border(c.primary, 1.5),
      errorBorder: border(c.danger),
      focusedErrorBorder: border(c.danger, 1.5),
    );
  }

  static String _manualMethodLabel(String code) => switch (code) {
        'card' => 'Carte bancaire',
        'paypal' => 'PayPal',
        _ => 'Virement bancaire',
      };

  /// Choix : Mobile Money (pays couverts) ou autre moyen (demande traitée à la main).
  Widget _buildModeSwitch(AppColors c) {
    Widget seg(bool manual, IconData icon, String label) {
      final on = _manual == manual;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _manual = manual;
            _formKey.currentState?.reset();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? c.primary.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? c.primary : Colors.transparent),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 17, color: on ? c.primary : c.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: on ? c.primary : c.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          seg(false, Icons.phone_android_rounded, context.tr('Mobile Money')),
          const SizedBox(width: 4),
          seg(true, Icons.account_balance_rounded, context.tr('Virement, carte, PayPal')),
        ]),
      ),
      if (_manual) ...[
        const SizedBox(height: 8),
        _infoLine(c, Icons.info_outline_rounded,
            context.tr('Demande traitée à la main par notre équipe, sous 72 h ouvrées. Minimum : {a}.', {'a': Money.fmt(_minFcfa)})),
      ],
    ]);
  }

  Widget _buildManualCountry(AppColors c) {
    final list = AfricanCountry.sortedFor(_manualCountry?.code);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c, context.tr('Pays de retrait')),
        DropdownButtonFormField<String>(
          value: _manualCountry?.code,
          isExpanded: true,
          dropdownColor: c.surface,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          iconEnabledColor: c.textSecondary,
          decoration: _inputDecoration(c, icon: Icons.public_rounded),
          hint: Text(context.tr('Sélectionnez un pays'), style: TextStyle(color: c.textSecondary)),
          items: list
              .map((x) => DropdownMenuItem<String>(
                    value: x.code,
                    child: Text('${x.flag}  ${x.name}', overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (code) => setState(() => _manualCountry = list.firstWhere((x) => x.code == code)),
          validator: (v) => v == null ? context.tr('Sélectionnez un pays') : null,
        ),
      ],
    );
  }

  Widget _buildManualFields(AppColors c) {
    final accountHint = switch (_manualMethod) {
      'paypal' => context.tr('Adresse e-mail PayPal'),
      'card' => context.tr('E-mail pour recevoir le lien de paiement'),
      _ => context.tr('IBAN ou numéro de compte'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c, context.tr('Méthode de retrait')),
        DropdownButtonFormField<String>(
          value: _manualMethod,
          isExpanded: true,
          dropdownColor: c.surface,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          iconEnabledColor: c.textSecondary,
          decoration: _inputDecoration(c, icon: Icons.account_balance_wallet_outlined),
          items: [
            DropdownMenuItem(value: 'bank', child: Text(context.tr('Virement bancaire'))),
            DropdownMenuItem(value: 'card', child: Text(context.tr('Carte bancaire'))),
            DropdownMenuItem(value: 'paypal', child: Text(context.tr('PayPal'))),
          ],
          onChanged: (v) => setState(() {
            _manualMethod = v ?? 'bank';
            _accountController.clear();
          }),
        ),
        const SizedBox(height: 14),
        _label(c, context.tr('Nom du titulaire')),
        TextFormField(
          controller: _holderController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          decoration: _inputDecoration(c, hint: context.tr('Prénom et nom'), icon: Icons.person_outline_rounded),
          onChanged: (_) => setState(() {}),
          validator: (v) => (v == null || v.trim().length < 3) ? context.tr('Indique le nom du titulaire') : null,
        ),
        const SizedBox(height: 14),
        _label(c, accountHint),
        TextFormField(
          controller: _accountController,
          keyboardType: _manualMethod == 'bank' ? TextInputType.text : TextInputType.emailAddress,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          decoration: _inputDecoration(c,
              hint: accountHint,
              icon: _manualMethod == 'bank' ? Icons.account_balance_outlined : Icons.alternate_email_rounded,
              // Jamais de numéro de carte : on envoie un lien de paiement sécurisé
              helper: _manualMethod == 'card' ? context.tr('Ne saisis jamais ton numéro de carte ici.') : null),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return context.tr('Champ obligatoire');
            if (_manualMethod != 'bank' && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
              return context.tr('Adresse e-mail invalide');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCountrySelector(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c, context.tr('Pays de retrait')),
        DropdownButtonFormField<String>(
          value: _selectedCountry?.countryCode,
          isExpanded: true,
          dropdownColor: c.surface,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          iconEnabledColor: c.textSecondary,
          decoration: _inputDecoration(c, icon: Icons.public_rounded),
          items: _availableCountries.map((country) {
            return DropdownMenuItem<String>(
              value: country.countryCode,
              child: Row(
                children: [
                  Flexible(child: Text(country.countryName, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text('+${country.phoneCode}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? countryCode) {
            if (countryCode != null) {
              final newCountry = _availableCountries.firstWhere(
                (x) => x.countryCode == countryCode,
                orElse: () => _availableCountries.first,
              );
              _onCountryChanged(newCountry);
            }
          },
        ),
      ],
    );
  }

  Widget _buildMontantField(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c, context.tr('Montant à retirer')),
        TextFormField(
          controller: _montantController,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration(c,
              hint: context.tr('Montant en {a}', {'a': _cur.symbol()}),
              icon: Icons.payments_outlined,
              suffix: _cur.symbol(),
              helper: _cur.isFcfa || _montantFcfa == null
                  ? null
                  : context.tr('Soit {a} (taux du jour)', {'a': '${TxAmount.fmt(_montantFcfa!)} FCFA'})),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            if (value == null || value.isEmpty) return context.tr('Veuillez entrer un montant');
            final montant = _montantFcfa;
            if (montant == null || montant < _minFcfa - 0.5) {
              return context.tr('Le montant minimum est de {a}', {'a': Money.fmt(_minFcfa)});
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMethodDropdown(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c, context.tr('Méthode de retrait')),
        DropdownButtonFormField<PaymentMethod>(
          value: _selectedMethod,
          isExpanded: true,
          hint: Text(context.tr('Sélectionnez une méthode'), style: TextStyle(color: c.textSecondary)),
          dropdownColor: c.surface,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          iconEnabledColor: c.textSecondary,
          decoration: _inputDecoration(c, icon: Icons.account_balance_wallet_outlined),
          items: _selectedCountry!.paymentMethods.map((method) {
            return DropdownMenuItem(
              value: method,
              child: Row(
                children: [
                  Icon(method.icon, color: c.primary, size: 18),
                  const SizedBox(width: 10),
                  Flexible(child: Text(method.name, overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedMethod = value),
          validator: (value) => value == null ? context.tr('Veuillez sélectionner une méthode') : null,
        ),
      ],
    );
  }

  Widget _buildNumeroField(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(
          c,
          context.tr('Numéro de retrait'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_selectedCountry!.countryName,
                style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
        ),
        TextFormField(
          controller: _numeroController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          decoration: _inputDecoration(
            c,
            hint: context.tr('{a} XX XX XX XX', {'a': _selectedCountry!.phoneCode}),
            icon: Icons.phone_android_rounded,
            prefix: '+',
            helper: context.tr('Indicatif {a} suivi de {b} chiffres', {'a': _selectedCountry!.phoneCode, 'b': _selectedCountry!.phoneLength}),
          ),
          onChanged: (value) {
            // Auto-formatage
            if (_selectedCountry != null) {
              final formatted = _selectedCountry!.formatPhoneNumber(value);
              if (formatted != value) {
                _numeroController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            }
            setState(() {});
          },
          validator: (value) => _validatePhoneNumber(value),
        ),
      ],
    );
  }

  Widget _buildConditionsCheckbox(AppColors c) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _hasAcceptedConditions = !_hasAcceptedConditions),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hasAcceptedConditions ? c.primary.withOpacity(0.5) : c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _hasAcceptedConditions,
              onChanged: (value) => setState(() => _hasAcceptedConditions = value ?? false),
              activeColor: c.primary,
              checkColor: c.onPrimary,
              side: BorderSide(color: c.textSecondary),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('J\'ai lu et j\'accepte les conditions'),
                        style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: _showConditionsDetails,
                      child: Text(context.tr('Lire les instructions importantes'),
                          style: TextStyle(
                            color: c.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: c.primary,
                          )),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(UserAuthProvider authProvider, AppColors c) {
    final bool isFormValid = _hasAcceptedConditions &&
        _montantController.text.isNotEmpty &&
        (_manual
            ? _manualCountry != null && _holderController.text.trim().isNotEmpty && _accountController.text.trim().isNotEmpty
            : _selectedCountry != null && _selectedMethod != null && _numeroController.text.isNotEmpty);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _isLoading ? null : () => _submitRetrait(authProvider),
            style: FilledButton.styleFrom(
              backgroundColor: isFormValid ? c.primary : c.surfaceVariant,
              foregroundColor: isFormValid ? c.onPrimary : c.textSecondary,
              disabledBackgroundColor: c.surfaceVariant,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: c.primary, strokeWidth: 2))
                : Text(context.tr('Soumettre la demande'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        if (!_hasAcceptedConditions) ...[
          const SizedBox(height: 8),
          Text(context.tr('Accepte les conditions pour continuer'), style: TextStyle(color: c.warning, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildProcedure(AppColors c) {
    final steps = [
      context.tr('Sélectionne ton pays et ta méthode de paiement'),
      context.tr('Entre ton numéro au bon format'),
      context.tr('Soumets la demande et note le numéro de transaction'),
      context.tr('Contacte le service client avec ce numéro'),
      context.tr('Reçois ton paiement sous 24 à 48 h'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Comment ça marche'),
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: c.primary.withOpacity(0.15), shape: BoxShape.circle),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[i], style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35))),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.warning.withOpacity(c.isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: c.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(context.tr('Vérifie bien ton numéro : les fonds seront envoyés dessus.'),
                      style: TextStyle(color: c.textPrimary, fontSize: 12, height: 1.3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConditionsDetails() {
    final c = AppColors.of(context);
    final items = [
      context.tr('Contacter le service client dans les 24 h suivant ta demande'),
      context.tr('Fournir le numéro de transaction généré'),
      context.tr('Le traitement prend généralement 24 à 48 heures'),
      context.tr('Vérifier que ton numéro de retrait est correct'),
      context.tr('Vérifier que le pays et la méthode sont corrects'),
      context.tr('Les demandes non finalisées sous 7 jours sont annulées automatiquement'),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(context.tr('Instructions importantes'),
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('Pour finaliser ton retrait, tu dois :'),
                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              for (final text in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, color: c.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13))),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.danger.withOpacity(c.isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(context.tr('Ton retrait ne sera traité qu\'après contact avec le service client.'),
                    style: TextStyle(color: c.danger, fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Fermer'), style: TextStyle(color: c.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _hasAcceptedConditions = true);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: Text(context.tr('J\'ai compris')),
          ),
        ],
      ),
    );
  }

  void _showHorairesModal() {
    final c = AppColors.of(context);
    Widget line(String day, String hours, {bool closed = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(day, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600))),
              Text(hours, style: TextStyle(color: closed ? c.danger : c.textSecondary)),
            ],
          ),
        );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Icon(Icons.schedule_rounded, color: c.primary, size: 24),
          const SizedBox(width: 10),
          Text(context.tr('Horaires de retrait'),
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(context.tr('Lundi au vendredi'), '8h00 - 17h00'),
            line(context.tr('Samedi'), '8h00 - 14h00'),
            line(context.tr('Dimanche'), context.tr('Fermé'), closed: true),
            const SizedBox(height: 12),
            Text(context.tr('Les demandes hors de ces créneaux ne sont pas acceptées.'),
                style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: Text(context.tr('J\'ai compris')),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRetrait(UserAuthProvider authProvider) async {
    if (!_isRetraitAllowed()) {
      _showHorairesModal();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (!_hasAcceptedConditions) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Veuillez accepter les conditions de retrait'))));
      return;
    }

    final montant = _montantFcfa!;
    final localAmount = double.parse(_montantController.text.replaceAll(',', '.').replaceAll(' ', ''));
    final userData = authProvider.loginUserData;

    if ((userData.votre_solde_principal ?? 0) < montant) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Solde insuffisant pour effectuer ce retrait'))));
      return;
    }

    // Mobile Money : numéro avec indicatif ; sinon coordonnées saisies (virement, carte, PayPal)
    final formattedNumber = _manual ? _accountController.text.trim() : _selectedCountry!.formatPhoneNumber(_numeroController.text);
    final method = _manual ? _manualMethodLabel(_manualMethod) : _selectedMethod!.name;
    final countryCode = _manual ? _manualCountry!.code : _selectedCountry!.countryCode;

    setState(() => _isLoading = true);

    try {
      final success = await RetraitService.demanderRetrait(
        userId: userData.id!,
        montant: montant,
        methodPaiement: method,
        numeroCompte: formattedNumber,
        countryCode: countryCode,
        userData: userData,
        extra: {
          // Montant demandé dans la devise de l'utilisateur et taux appliqué
          'withdrawalType': _manual ? 'manual' : 'mobile_money',
          'currency': _cur.currency,
          'localAmount': localAmount,
          'exchangeRate': _cur.rate,
          if (_manual) 'accountHolder': _holderController.text.trim(),
          if (_manual) 'manualMethod': _manualMethod,
        },
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Demande de retrait envoyée')), duration: Duration(seconds: 4)));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UserRetraitListPage()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Erreur : {a}', {'a': e.toString()}))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
