// pages/retrait/user_retrait_page.dart
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/user/UserRetrait/userRetraitListe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../models/payment_config.dart';
import '../../../providers/authProvider.dart';
import '../../../services/retraitService.dart';

class UserDemandeRetraitPage extends StatefulWidget {
  @override
  _UserDemandeRetraitPageState createState() => _UserDemandeRetraitPageState();
}

class _UserDemandeRetraitPageState extends State<UserDemandeRetraitPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();

  PaymentConfig? _selectedCountry;
  PaymentMethod? _selectedMethod;

  bool _isLoading = false;
  bool _hasAcceptedConditions = false;

  // Liste des pays disponibles (depuis la configuration)
  List<PaymentConfig> get _availableCountries => PaymentConfig.activeCountries;

  @override
  void initState() {
    super.initState();
    // Sélectionner le premier pays par défaut
    if (_availableCountries.isNotEmpty) {
      _selectedCountry = _availableCountries.first;
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
      _selectedMethod = null; // Réinitialiser la méthode
      _numeroController.clear(); // Réinitialiser le numéro
    });
  }

  Widget _buildHorairesInfo() {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.yellow[700], size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Retraits possibles : lun-ven 8h-17h, sam 8h-14h (fermé dimanche)',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final userData = authProvider.loginUserData;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Demande de Retrait',
          style: TextStyle(color: Colors.yellow[700]),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.yellow[700]),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSoldeCard(userData!),
            SizedBox(height: 20),
            Expanded(
              child: CenteredContent(child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildCountrySelector(),
                      SizedBox(height: 16),
                      _buildMontantField(),
                      SizedBox(height: 16),
                      if (_selectedCountry != null) ...[
                        _buildMethodDropdown(),
                        SizedBox(height: 16),
                        _buildNumeroField(),
                      ],
                      SizedBox(height: 16),
                      _buildConditionsCheckbox(),
                      SizedBox(height: 24),
                      _buildSubmitButton(authProvider),
                      SizedBox(height: 20),
                      _buildDetailedInfoContact(),
                    ],
                  ),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoldeCard(UserData userData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[800]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Solde Principal Disponible',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            '${userData.votre_solde_principal?.toStringAsFixed(2) ?? '0.00'} FCFA',
            style: TextStyle(color: Colors.yellow[700], fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Solde minimum de retrait: 2 500 FCFA',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          _buildHorairesInfo(),
        ],
      ),
    );
  }

  Widget _buildCountrySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pays de retrait',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCountry?.countryCode,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: TextStyle(color: Colors.white, fontSize: 16),
              padding: EdgeInsets.symmetric(horizontal: 16),
              items: _availableCountries.map((country) {
                return DropdownMenuItem<String>(
                  value: country.countryCode,
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.yellow[700], size: 20),
                      SizedBox(width: 12),
                      Text(country.countryName),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${country.phoneCode}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? countryCode) {
                if (countryCode != null) {
                  final newCountry = _availableCountries.firstWhere(
                        (c) => c.countryCode == countryCode,
                    orElse: () => _availableCountries.first,
                  );
                  _onCountryChanged(newCountry);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildMontantField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant à retirer',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _montantController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Entrez le montant en FCFA',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.yellow)),
            prefixIcon: Icon(Icons.money, color: Colors.green),
            suffixText: 'FCFA',
            suffixStyle: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Veuillez entrer un montant';
            final montant = double.tryParse(value);
            if (montant == null || montant < 2500) return 'Le montant minimum est de 2 500 FCFA';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMethodDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Méthode de retrait',
          style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<PaymentMethod>(
          value: _selectedMethod,
          hint: Text('Sélectionnez une méthode', style: TextStyle(color: Colors.grey[500])),
          dropdownColor: Colors.grey[900],
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.yellow)),
            prefixIcon: Icon(Icons.payment, color: Colors.green),
          ),
          items: _selectedCountry!.paymentMethods.map((method) {
            return DropdownMenuItem(
              value: method,
              child: Row(
                children: [
                  Icon(method.icon, color: Colors.yellow[700], size: 20),
                  SizedBox(width: 12),
                  Text(method.name),
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

  Widget _buildNumeroField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Numéro de retrait',
              style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.yellow[700]!.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _selectedCountry!.countryName,
                style: TextStyle(color: Colors.yellow[700], fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _numeroController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: '+${_selectedCountry!.phoneCode} XX XX XX XX',
            hintStyle: TextStyle(color: Colors.grey[600]),
            helperText: 'Format: ${_selectedCountry!.phoneCode} suivi de ${_selectedCountry!.phoneLength} chiffres',
            helperStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.yellow)),
            prefixIcon: Icon(Icons.phone_android, color: Colors.green),
            prefixText: '+',
            prefixStyle: TextStyle(color: Colors.green, fontSize: 16),
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
          },
          validator: (value) => _validatePhoneNumber(value),
        ),
      ],
    );
  }

  Widget _buildConditionsCheckbox() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow[700]!.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: _hasAcceptedConditions,
              onChanged: (value) => setState(() => _hasAcceptedConditions = value ?? false),
              activeColor: Colors.yellow[700],
              checkColor: Colors.black,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('J\'ai lu et j\'accepte les conditions', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: _showConditionsDetails,
                  child: Text('Cliquez ici pour lire les instructions importantes', style: TextStyle(color: Colors.yellow[700], fontSize: 12, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(UserAuthProvider authProvider) {
    final bool isFormValid = _selectedCountry != null &&
        _selectedMethod != null &&
        _hasAcceptedConditions &&
        _montantController.text.isNotEmpty &&
        _numeroController.text.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _submitRetrait(authProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFormValid ? Colors.yellow[700] : Colors.grey[600],
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.send, size: 20),
              SizedBox(width: 8),
              Text('SOUMETTRE LA DEMANDE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        if (!_hasAcceptedConditions) ...[
          SizedBox(height: 8),
          Text('Veuillez accepter les conditions pour continuer', style: TextStyle(color: Colors.orange, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildDetailedInfoContact() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.contact_support, color: Colors.yellow[700], size: 24),
            SizedBox(width: 8),
            Text('Procédure de Retrait', style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          SizedBox(height: 12),
          _buildStepItem('1', 'Sélectionnez votre pays'),
          _buildStepItem('2', 'Choisissez votre méthode de paiement'),
          _buildStepItem('3', 'Entrez votre numéro au format valide'),
          _buildStepItem('4', 'Soumettez votre demande de retrait'),
          _buildStepItem('5', 'Notez votre numéro de transaction'),
          _buildStepItem('6', 'Contactez notre service client'),
          _buildStepItem('7', 'Recevez votre paiement sous 24-48h'),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
            child: Row(children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Assurez-vous que votre numéro est correct. Les fonds seront envoyés sur ce numéro.', style: TextStyle(color: Colors.orange, fontSize: 12))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String step, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: Colors.yellow[700], shape: BoxShape.circle),
            child: Center(child: Text(step, style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
          ),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 13))),
        ],
      ),
    );
  }

  void _showConditionsDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(children: [
          Icon(Icons.security, color: Colors.yellow[700]),
          SizedBox(width: 8),
          Text('Instructions Importantes', style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pour finaliser votre retrait, vous devez :', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              SizedBox(height: 12),
              _buildConditionItem('📞 Contacter notre service client dans les 24h suivant votre demande'),
              _buildConditionItem('🔢 Fournir le numéro de transaction généré'),
              _buildConditionItem('⏰ Le traitement prend généralement 24 à 48 heures'),
              _buildConditionItem('💰 Vérifier que votre numéro de retrait est correct'),
              _buildConditionItem('🌍 Vérifier que le pays et la méthode sont corrects'),
              _buildConditionItem('❌ Les demandes non finalisées sous 7 jours seront annulées automatiquement'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
                child: Text('Important : Votre retrait ne sera traité qu\'après contact avec notre service client.', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('FERMER', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { setState(() => _hasAcceptedConditions = true); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700], foregroundColor: Colors.black),
            child: Text('J\'AI COMPRIS'),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 13))),
        ],
      ),
    );
  }

  void _showHorairesModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.yellow[700]!, width: 2)),
        title: Row(children: [
          Icon(Icons.access_time, color: Colors.yellow[700], size: 28),
          SizedBox(width: 12),
          Text('Horaires de retrait', style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 Lundi au Vendredi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('⏰ 8h00 - 17h00', style: TextStyle(color: Colors.grey[300])),
            SizedBox(height: 12),
            Text('📅 Samedi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('⏰ 8h00 - 14h00', style: TextStyle(color: Colors.grey[300])),
            SizedBox(height: 12),
            Text('📅 Dimanche', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('🚫 Fermé (aucun retrait)', style: TextStyle(color: Colors.red[400])),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blueGrey[800], borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.info, color: Colors.yellow[700], size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Les demandes hors de ces créneaux ne seront pas acceptées.', style: TextStyle(color: Colors.white70))),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer', style: TextStyle(color: Colors.grey[400]))),
          ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700], foregroundColor: Colors.black), child: Text('J\'ai compris')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez accepter les conditions de retrait'), backgroundColor: Colors.orange));
      return;
    }

    final montant = double.parse(_montantController.text);
    final userData = authProvider.loginUserData!;

    if (userData.votre_solde_principal! < montant) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solde insuffisant pour effectuer ce retrait'), backgroundColor: Colors.red));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Demande de retrait soumise avec succès !'), backgroundColor: Colors.green, duration: Duration(seconds: 4)));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UserRetraitListPage()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}