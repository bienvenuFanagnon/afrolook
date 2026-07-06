import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:convert';

import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'feexpay/feexPayPaymentScreen.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class DepositScreen extends StatefulWidget {
  final double? defaultAmount;

  const DepositScreen({Key? key, this.defaultAmount}) : super(key: key);

  @override
  _DepositScreenState createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultAmount != null) {
      amountController.text = widget.defaultAmount!.toStringAsFixed(0);
    }
  }

  void _showPaymentMethodSelection() {
    if (!_formKey.currentState!.validate()) return;
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);

    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: colors.onPrimary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.depositChooseMethodTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  children: [
                    _PaymentMethodCard(
                      title: 'Carte Bancaire',
                      subtitle: 'Visa / Mastercard — Toute l\'Afrique',
                      description: 'Frais : 7%  •  Conversion FCFA automatique',
                      icon: Icons.credit_card,
                      color: colors.primary,
                      iconColor: colors.onPrimary,
                      onTap: () {
                        Navigator.pop(context);
                        _processCinetPayPayment(paymentType: 'CARD');
                      },
                    ),
                    const SizedBox(height: 12),
                    _PaymentMethodCard(
                      title: 'FeexPay Mobile Money',
                      subtitle: 'Afrique de l\'Ouest',
                      description: 'MTN • MOOV • ORANGE • WAVE  •  Frais : 5.6%',
                      icon: Icons.qr_code_scanner,
                      color: const Color(0xFF9C27B0),
                      iconColor: Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        _processFeexPayPayment();
                      },
                    ),
                    const SizedBox(height: 12),
                    _PaymentMethodCard(
                      title: 'PayGate',
                      subtitle: 'Togo seulement',
                      description: 'FLOOZ • T-Money  •  Frais : 5.6%',
                      icon: Icons.phone_android,
                      color: colors.info,
                      iconColor: Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        _showPayGatePhoneDialog();
                      },
                    ),
                    const SizedBox(height: 16),
                    Divider(color: colors.border),
                    const SizedBox(height: 8),
                    Text(
                      t.depositSelectCountry,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
                child: Text(t.btnCancel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayGatePhoneDialog() {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    String selectedNetwork = 'FLOOZ';
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: colors.surface,
          title: Row(
            children: [
              Icon(Icons.phone_android, color: colors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.depositPaygateDialogTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.depositPaygateSubtitle, style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 20),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: t.signupPhone,
                  labelStyle: TextStyle(color: colors.textSecondary),
                  prefixText: '+228 ',
                  prefixIcon: Icon(Icons.phone, color: colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.info),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedNetwork,
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'FLOOZ', child: Text('FLOOZ (Moov)')),
                  DropdownMenuItem(value: 'T-MONEY', child: Text('T-Money (Togocel)')),
                ],
                onChanged: (value) {
                  setStateDialog(() => selectedNetwork = value!);
                },
                decoration: InputDecoration(
                  labelText: t.depositNetworkLabel,
                  labelStyle: TextStyle(color: colors.textSecondary),
                  prefixIcon: Icon(Icons.network_cell, color: colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.info),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.btnCancel, style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t.depositPhoneRequired),
                      backgroundColor: colors.danger,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _processPayGatePayment(phoneController.text, selectedNetwork);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.info,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                t.commonConfirm,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pays CinetPay (ISO 2 lettres) — les plus courants en Afrique + Europe
  static const _countries = [
    ('CI', 'Côte d\'Ivoire'), ('SN', 'Sénégal'),    ('CM', 'Cameroun'),
    ('TG', 'Togo'),          ('BJ', 'Bénin'),        ('BF', 'Burkina Faso'),
    ('ML', 'Mali'),          ('NE', 'Niger'),        ('GN', 'Guinée'),
    ('GH', 'Ghana'),         ('NG', 'Nigeria'),      ('CD', 'Congo RDC'),
    ('CG', 'Congo'),         ('GA', 'Gabon'),        ('MG', 'Madagascar'),
    ('MA', 'Maroc'),         ('TN', 'Tunisie'),      ('DZ', 'Algérie'),
    ('FR', 'France'),        ('BE', 'Belgique'),     ('CH', 'Suisse'),
    ('CA', 'Canada'),        ('US', 'États-Unis'),
  ];

  Future<void> _processCinetPayPayment({required String paymentType}) async {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final provider = Provider.of<UserAuthProvider>(context, listen: false);
    final amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) return;

    final user = provider.loginUserData;

    // Contrôleurs pré-remplis avec les données du profil
    final prenomCtrl   = TextEditingController(text: user.prenom ?? '');
    final nomCtrl      = TextEditingController(text: user.nom ?? '');
    final phoneCtrl    = TextEditingController(text: user.numeroDeTelephone ?? '');
    final adresseCtrl  = TextEditingController(text: user.adresse ?? '');
    final villeCtrl    = TextEditingController(text: user.userPays?.placeName ?? user.userPays?.name ?? '');
    String selectedCountry = user.userPays?.id ?? 'CI';
    // S'assurer que le pays est dans la liste
    if (!_countries.any((c) => c.$1 == selectedCountry)) selectedCountry = 'CI';

    const double feeRate = 0.07;
    final int fees    = (amount * feeRate).round();
    final int credited = (amount - fees).round();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSheet) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.97,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Titre
                  Row(
                    children: [
                      Icon(Icons.credit_card, color: colors.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Carte Bancaire — Informations',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vérifiez et complétez vos informations avant de payer.',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Résumé des frais
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        _feeRow('Montant saisi', '${amount.round()} FCFA', colors.textPrimary, colors),
                        _feeRow('Frais (7%)', '- $fees FCFA', colors.danger, colors),
                        Divider(color: colors.border, height: 16),
                        _feeRow('Vous recevez', '$credited FCFA', colors.primary, colors),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Divider(color: colors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'INFORMATIONS CLIENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  // Prénom + Nom
                  Row(
                    children: [
                      Expanded(child: _buildField(prenomCtrl, 'Prénom', Icons.person_outline, colors, required: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(nomCtrl, 'Nom', Icons.person, colors, required: true)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Téléphone
                  _buildField(phoneCtrl, 'Téléphone', Icons.phone_outlined, colors,
                      required: true, keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),

                  // Adresse
                  _buildField(adresseCtrl, 'Adresse', Icons.home_outlined, colors, required: true),
                  const SizedBox(height: 14),

                  // Ville
                  _buildField(villeCtrl, 'Ville', Icons.location_city_outlined, colors, required: true),
                  const SizedBox(height: 14),

                  // Pays (dropdown)
                  DropdownButtonFormField<String>(
                    value: selectedCountry,
                    dropdownColor: colors.surface,
                    isExpanded: true,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Pays',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      prefixIcon: Icon(Icons.flag_outlined, color: colors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.primary),
                      ),
                      filled: true,
                      fillColor: colors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: _countries.map((c) => DropdownMenuItem(
                      value: c.$1,
                      child: Text('${c.$1} — ${c.$2}', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setStateSheet(() => selectedCountry = v!),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 28),

                  // Bouton confirmer
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.lock_outline, color: colors.onPrimary),
                    label: Text(
                      'Confirmer et payer',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.onPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(t.btnCancel, style: TextStyle(color: colors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    // Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(colors.primary)),
              const SizedBox(height: 20),
              Text(
                t.depositConnecting,
                style: TextStyle(fontSize: 16, color: colors.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(t.depositRedirectSecure, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            ],
          ),
        ),
      ),
    );

    final payload = {
      'amount':          amount.round(),
      'userId':          user.id,
      'paymentType':     paymentType,
      'customerName':    prenomCtrl.text.trim().isNotEmpty ? prenomCtrl.text.trim() : 'Client',
      'customerSurname': nomCtrl.text.trim().isNotEmpty   ? nomCtrl.text.trim()    : 'Afrolook',
      'customerEmail':   user.email ?? '',
      'customerPhone':   phoneCtrl.text.trim(),
      'customerAddress': adresseCtrl.text.trim().isNotEmpty ? adresseCtrl.text.trim() : 'N/A',
      'customerCity':    villeCtrl.text.trim().isNotEmpty   ? villeCtrl.text.trim()   : 'N/A',
      'customerCountry': selectedCountry,
      'customerZipCode': '00000',
    };
    debugPrint('[CinetPay] payload: $payload');

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('initiateAfrolookDeposit');
      final result = await callable(payload);

      debugPrint('[CinetPay] Réponse: ${result.data}');
      Navigator.of(context).pop();

      final paymentUrl = (result.data['payment_url'] as String?) ?? '';
      if (paymentUrl.isNotEmpty && await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
        Navigator.pop(context);
      } else {
        throw Exception('URL de paiement invalide ou vide');
      }
    } on FirebaseFunctionsException catch (e) {
      Navigator.of(context).pop();
      debugPrint('[CinetPay] FirebaseFunctionsException:');
      debugPrint('  code    : ${e.code}');
      debugPrint('  message : ${e.message}');
      debugPrint('  details : ${e.details}');
      final detail = (e.details != null && e.details is Map)
          ? (e.details as Map)['message'] ?? e.message
          : e.message;
      _showErrorDialog('[${e.code}] $detail', colors, t);
    } catch (e, stack) {
      Navigator.of(context).pop();
      debugPrint('[CinetPay] Erreur: $e\n$stack');
      _showErrorDialog(e.toString(), colors, t);
    }
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    AppColors colors, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: colors.textSecondary, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary),
        ),
        filled: true,
        fillColor: colors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null
          : null,
    );
  }

  void _showErrorDialog(String message, AppColors colors, AppLocalizations t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colors.surface,
        title: Row(
          children: [
            Icon(Icons.error_outline, color: colors.danger),
            const SizedBox(width: 10),
            Text('Échec du paiement', style: TextStyle(color: colors.textPrimary, fontSize: 16)),
          ],
        ),
        content: SelectableText(
          message,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            child: Text('OK', style: TextStyle(color: colors.onPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, Color valueColor, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Future<void> _processPayGatePayment(String phoneNumber, String network) async {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final amount = double.tryParse(amountController.text) ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(colors.info)),
              const SizedBox(height: 20),
              Text(
                t.depositConnectingPaygate,
                style: TextStyle(fontSize: 16, color: colors.info, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                t.depositInitPayment,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final transactionId = 'pg_${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse('https://initiatepaymentfromafrolook-b6fm6gdlrq-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'data': {
            'transactionId': transactionId,
            'amount': amount,
            'userId': userProvider.loginUserData.id,
            'type': 'afrolook_deposit',
            'phoneNumber': phoneNumber,
            'network': network,
            'userEmail': userProvider.loginUserData.email,
            'userName': userProvider.loginUserData.nom,
          }
        }),
      );

      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['result']?['success'] == true) {
          final paymentUrl = result['result']?['payment_url'];
          if (!kIsWeb && paymentUrl != null) {
            if (await canLaunchUrl(Uri.parse(paymentUrl))) {
              await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
            }
          }
          Navigator.pop(context);
        } else {
          throw Exception(result['error']?['message'] ?? 'Erreur inconnue');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec PayGate : ${e.toString()}'),
          backgroundColor: colors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processFeexPayPayment() async {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final amount = double.tryParse(amountController.text) ?? 0;

    if (amount < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.depositAmountMin), backgroundColor: colors.danger),
      );
      return;
    }

    final int totalAmount = (amount / (1 - 0.056)).ceil();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF9C27B0)),
              ),
              const SizedBox(height: 20),
              Text(
                t.depositPreparingPayment,
                style: const TextStyle(fontSize: 16, color: Color(0xFF9C27B0), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(t.depositPleaseWait, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            ],
          ),
        ),
      ),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('initiateAfrolookFeexpayPayment');
      final result = await callable({
        'amount': totalAmount,
        'userId': userProvider.loginUserData.id,
        'type': 'afrolook_deposit',
      });

      Navigator.of(context).pop();

      final params = result.data as Map<String, dynamic>;
      final callbackInfoMap = jsonDecode(params['callback_info']) as Map<String, dynamic>;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeexPayPaymentScreen(
            token: '',
            shopId: '',
            amount: params['amount'] as int,
            redirectUrl: (params['redirecturl'] as String?) ?? '',
            transKey: (params['trans_key'] as String?) ?? '',
            callbackInfo: callbackInfoMap,
            depositNumber: (params['depositNumber'] as String?) ?? '',
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec FeexPay : ${e.toString()}'),
          backgroundColor: colors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          t.depositTitle,
          style: TextStyle(fontWeight: FontWeight.bold, color: colors.onPrimary),
        ),
        centerTitle: true,
        backgroundColor: colors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.onPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                color: colors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: colors.primary, size: 35),
                      const SizedBox(height: 16),
                      Text(
                        t.depositImportantInfo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInfoRow(t.depositMinAmount, '200 FCFA', colors),
                      const SizedBox(height: 8),
                      _buildInfoRow(t.depositFeesMM, '5,6%', colors),
                      const SizedBox(height: 8),
                      _buildInfoRow(t.depositFeesCard, '7%', colors),
                      const SizedBox(height: 8),
                      _buildInfoRow(t.depositSupportLabel, t.depositSupportVal, colors),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.warning.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: colors.warning),
                        const SizedBox(width: 8),
                        Text(
                          t.depositImportantInfo,
                          style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(t.depositNoticeText, style: TextStyle(color: colors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(t.depositNoticeProblem, style: TextStyle(color: colors.textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          onChanged: (value) {
                            setState(() => _termsAccepted = value ?? false);
                          },
                          activeColor: colors.primary,
                        ),
                        Expanded(
                          child: Text(
                            t.depositTermsText,
                            style: TextStyle(fontSize: 14, color: colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.depositAmountLabel,
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: t.depositAmountHint,
                        hintStyle: TextStyle(color: colors.textSecondary),
                        suffixText: 'FCFA',
                        suffixStyle: TextStyle(color: colors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.primary),
                        ),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return t.depositAmountRequired;
                        final amount = double.tryParse(value) ?? 0;
                        if (amount < 200) return t.depositAmountMin;
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _termsAccepted ? _showPaymentMethodSelection : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _termsAccepted ? colors.primary : colors.border,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: _termsAccepted ? 3 : 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payment,
                            color: _termsAccepted ? colors.onPrimary : colors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            t.depositChooseMethod,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _termsAccepted ? colors.onPrimary : colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  t.depositSecureRedirect,
                  style: TextStyle(color: colors.primary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
        const SizedBox(width: 5),
        Expanded(child: Text(value, style: TextStyle(color: colors.textSecondary))),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Card(
      elevation: 2,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withOpacity(0.2), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
