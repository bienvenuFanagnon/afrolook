// pages/retrait/user_retrait_page.dart
import 'package:afrotok/pages/user/UserRetrait/userRetraitListe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../services/retraitService.dart';

class UserRetraitPage extends StatefulWidget {
  @override
  _UserRetraitPageState createState() => _UserRetraitPageState();
}

class _UserRetraitPageState extends State<UserRetraitPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montantController = TextEditingController();
  String _selectedMethod = 'Paiement via Service Client';
  final TextEditingController _numeroController = TextEditingController();
  bool _isLoading = false;
  bool _hasAcceptedConditions = false;

  final List<String> _paymentMethods = [
    'Paiement via Service Client'
  ];

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
            // Carte solde
            _buildSoldeCard(userData!),
            SizedBox(height: 20),

            // Formulaire de retrait
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildMontantField(),
                      SizedBox(height: 16),
                      _buildMethodDropdown(),
                      SizedBox(height: 16),
                      _buildNumeroField(),
                      SizedBox(height: 16),
                      _buildConditionsCheckbox(),
                      SizedBox(height: 24),
                      _buildSubmitButton(authProvider),
                      SizedBox(height: 20),
                      _buildDetailedInfoContact(),
                    ],
                  ),
                ),
              ),
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
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${userData.votre_solde_principal?.toStringAsFixed(2) ?? '0.00'} FCFA',
            style: TextStyle(
              color: Colors.yellow[700],
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Solde minimum de retrait: 1 000 FCFA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMontantField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant à retirer',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _montantController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Entrez le montant en FCFA',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.yellow),
            ),
            prefixIcon: Icon(Icons.money, color: Colors.green),
            suffixText: 'FCFA',
            suffixStyle: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer un montant';
            }
            final montant = double.tryParse(value);
            if (montant == null || montant < 1000) {
              return 'Le montant minimum est de 1 000 FCFA';
            }
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
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedMethod,
          dropdownColor: Colors.grey[900],
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Sélectionnez une méthode',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.yellow),
            ),
            prefixIcon: Icon(Icons.payment, color: Colors.green),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: _paymentMethods.map((method) {
            return DropdownMenuItem(
              value: method,
              child: Text(method, style: TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedMethod = value!;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez sélectionner une méthode';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNumeroField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votre numéro de compte',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _numeroController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Ex: +228 90 12 34 56',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.yellow),
            ),
            prefixIcon: Icon(Icons.phone_android, color: Colors.green),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre numéro';
            }
            if (value.length < 8) {
              return 'Numéro invalide';
            }
            return null;
          },
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
              onChanged: (value) {
                setState(() {
                  _hasAcceptedConditions = value ?? false;
                });
              },
              activeColor: Colors.yellow[700],
              checkColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'J\'ai lu et j\'accepte les conditions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: _showConditionsDetails,
                  child: Text(
                    'Cliquez ici pour lire les instructions importantes',
                    style: TextStyle(
                      color: Colors.yellow[700],
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(UserAuthProvider authProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _submitRetrait(authProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasAcceptedConditions ? Colors.yellow[700] : Colors.grey[600],
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: _hasAcceptedConditions ? Colors.yellow[700]!.withOpacity(0.5) : Colors.grey,
            ),
            child: _isLoading
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 2,
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send, size: 20),
                SizedBox(width: 8),
                Text(
                  'SOUMETTRE LA DEMANDE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_hasAcceptedConditions) ...[
          SizedBox(height: 8),
          Text(
            'Veuillez accepter les conditions pour continuer',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
            ),
          ),
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
          Row(
            children: [
              Icon(Icons.contact_support, color: Colors.yellow[700], size: 24),
              SizedBox(width: 8),
              Text(
                'Procédure de Retrait',
                style: TextStyle(
                  color: Colors.yellow[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildStepItem('1', 'Soumettez votre demande de retrait'),
          _buildStepItem('2', 'Notez votre numéro de transaction'),
          _buildStepItem('3', 'Contactez notre service client'),
          _buildStepItem('4', 'Fournissez votre numéro de transaction'),
          _buildStepItem('5', 'Recevez votre paiement sous 24-48h'),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sans contact avec notre service, votre retrait ne sera pas traité',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
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
            decoration: BoxDecoration(
              color: Colors.yellow[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConditionsDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.yellow[700]),
            SizedBox(width: 8),
            Text(
              'Instructions Importantes',
              style: TextStyle(
                color: Colors.yellow[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pour finaliser votre retrait, vous devez :',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              _buildConditionItem('📞 Contacter notre service client dans les 24h suivant votre demande'),
              _buildConditionItem('🔢 Fournir le numéro de transaction généré'),
              _buildConditionItem('⏰ Le traitement prend généralement 24 à 48 heures'),
              _buildConditionItem('💰 Vérifier que votre numéro de compte est correct'),
              _buildConditionItem('❌ Les demandes non finalisées sous 7 jours seront annulées automatiquement'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  'Important : Votre retrait ne sera traité qu\'après contact avec notre service client.',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'FERMER',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasAcceptedConditions = true;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow[700],
              foregroundColor: Colors.black,
            ),
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
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRetrait(UserAuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasAcceptedConditions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez accepter les conditions de retrait'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final montant = double.parse(_montantController.text);
    final userData = authProvider.loginUserData!;

    if (userData.votre_solde_principal! < montant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solde insuffisant pour effectuer ce retrait'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await RetraitService.demanderRetrait(
        userId: userData.id!,
        montant: montant,
        methodPaiement: _selectedMethod,
        numeroCompte: _numeroController.text,
        userData: userData,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Demande de retrait soumise avec succès !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => UserRetraitListPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}