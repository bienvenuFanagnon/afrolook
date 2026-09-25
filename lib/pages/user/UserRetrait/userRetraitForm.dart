// pages/retrait/user_retrait_page.dart
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/user/UserRetrait/userRetraitListe.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../models/payment_config.dart';
import '../../../providers/authProvider.dart';
import '../../../services/payment_methods_config_service.dart';
import '../../../services/retraitService.dart';
import '../../../theme/app_colors.dart';

/// Formulaire de demande de retrait (thèmes clair et sombre via [AppColors]).
/// La demande est enregistrée dans Firestore puis traitée manuellement.
class UserDemandeRetraitPage extends StatefulWidget {
  @override
  _UserDemandeRetraitPageState createState() => _UserDemandeRetraitPageState();
}

class _UserDemandeRetraitPageState extends State<UserDemandeRetraitPage> {
  static const double _minRetrait = 2500;
  static final NumberFormat _moneyFmt = NumberFormat('#,##0.##', 'fr');

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();

  PaymentConfig? _selectedCountry;
  PaymentMethod? _selectedMethod;

  bool _isLoading = false;
  bool _hasAcceptedConditions = false;
  List<PaymentConfig> _availableCountries = [];

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _numeroController.dispose();
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
      setState(() {
        _availableCountries = countries;
        if (countries.isNotEmpty) _selectedCountry = countries.first;
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
    if (_selectedCountry == null) return 'Sélectionnez un pays';
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
        title: Text('Demande de retrait',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long_rounded, color: c.textPrimary),
            tooltip: 'Mes retraits',
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
              const SizedBox(height: 20),
              _buildCountrySelector(c),
              const SizedBox(height: 14),
              _buildMontantField(c),
              if (_selectedCountry != null) ...[
                const SizedBox(height: 14),
                _buildMethodDropdown(c),
                const SizedBox(height: 14),
                _buildNumeroField(c),
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
          Text('Gains à retirer', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(
            '${_moneyFmt.format(userData.votre_solde_principal ?? 0)} FCFA',
            style: TextStyle(
              color: c.primary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          _infoLine(c, Icons.south_rounded, 'Minimum de retrait : 2 500 FCFA'),
          const SizedBox(height: 4),
          _infoLine(c, Icons.schedule_rounded, 'Lun-ven 8h-17h · sam 8h-14h · fermé le dimanche'),
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

  Widget _buildCountrySelector(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c, 'Pays de retrait'),
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
        _label(c, 'Montant à retirer'),
        TextFormField(
          controller: _montantController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          decoration: _inputDecoration(c, hint: 'Montant en FCFA', icon: Icons.payments_outlined, suffix: 'FCFA'),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Veuillez entrer un montant';
            final montant = double.tryParse(value);
            if (montant == null || montant < _minRetrait) return 'Le montant minimum est de 2 500 FCFA';
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
        _label(c, 'Méthode de retrait'),
        DropdownButtonFormField<PaymentMethod>(
          value: _selectedMethod,
          isExpanded: true,
          hint: Text('Sélectionnez une méthode', style: TextStyle(color: c.textSecondary)),
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
          validator: (value) => value == null ? 'Veuillez sélectionner une méthode' : null,
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
          'Numéro de retrait',
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
            hint: '${_selectedCountry!.phoneCode} XX XX XX XX',
            icon: Icons.phone_android_rounded,
            prefix: '+',
            helper: 'Indicatif ${_selectedCountry!.phoneCode} suivi de ${_selectedCountry!.phoneLength} chiffres',
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
                    Text("J'ai lu et j'accepte les conditions",
                        style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: _showConditionsDetails,
                      child: Text('Lire les instructions importantes',
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
    final bool isFormValid = _selectedCountry != null &&
        _selectedMethod != null &&
        _hasAcceptedConditions &&
        _montantController.text.isNotEmpty &&
        _numeroController.text.isNotEmpty;

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
                : const Text('Soumettre la demande', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        if (!_hasAcceptedConditions) ...[
          const SizedBox(height: 8),
          Text('Accepte les conditions pour continuer', style: TextStyle(color: c.warning, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildProcedure(AppColors c) {
    const steps = [
      'Sélectionne ton pays et ta méthode de paiement',
      'Entre ton numéro au bon format',
      'Soumets la demande et note le numéro de transaction',
      'Contacte le service client avec ce numéro',
      'Reçois ton paiement sous 24 à 48 h',
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
          Text('Comment ça marche',
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
                  child: Text('Vérifie bien ton numéro : les fonds seront envoyés dessus.',
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
    const items = [
      'Contacter le service client dans les 24 h suivant ta demande',
      'Fournir le numéro de transaction généré',
      'Le traitement prend généralement 24 à 48 heures',
      'Vérifier que ton numéro de retrait est correct',
      'Vérifier que le pays et la méthode sont corrects',
      'Les demandes non finalisées sous 7 jours sont annulées automatiquement',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Instructions importantes',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pour finaliser ton retrait, tu dois :',
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
                child: Text("Ton retrait ne sera traité qu'après contact avec le service client.",
                    style: TextStyle(color: c.danger, fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: TextStyle(color: c.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _hasAcceptedConditions = true);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: const Text("J'ai compris"),
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
          Text('Horaires de retrait',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('Lundi au vendredi', '8h00 - 17h00'),
            line('Samedi', '8h00 - 14h00'),
            line('Dimanche', 'Fermé', closed: true),
            const SizedBox(height: 12),
            Text('Les demandes hors de ces créneaux ne sont pas acceptées.',
                style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: const Text("J'ai compris"),
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
          const SnackBar(content: Text('Veuillez accepter les conditions de retrait')));
      return;
    }

    final montant = double.parse(_montantController.text);
    final userData = authProvider.loginUserData;

    if ((userData.votre_solde_principal ?? 0) < montant) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solde insuffisant pour effectuer ce retrait')));
      return;
    }

    // Formater le numéro avec l'indicatif
    final formattedNumber = _selectedCountry!.formatPhoneNumber(_numeroController.text);

    setState(() => _isLoading = true);

    try {
      final success = await RetraitService.demanderRetrait(
        userId: userData.id!,
        montant: montant,
        methodPaiement: _selectedMethod!.name,
        numeroCompte: formattedNumber,
        countryCode: _selectedCountry!.countryCode,
        userData: userData,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Demande de retrait envoyée'), duration: Duration(seconds: 4)));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UserRetraitListPage()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
