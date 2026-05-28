import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class FeexPayPaymentScreen extends StatefulWidget {
  final String token;
  final String shopId;
  final int amount;
  final String redirectUrl;
  final String transKey;
  final Map<String, dynamic> callbackInfo;
  final String depositNumber;

  const FeexPayPaymentScreen({
    Key? key,
    required this.token,
    required this.shopId,
    required this.amount,
    required this.redirectUrl,
    required this.transKey,
    required this.callbackInfo,
    required this.depositNumber,
  }) : super(key: key);

  @override
  State<FeexPayPaymentScreen> createState() => _FeexPayPaymentScreenState();
}

class _FeexPayPaymentScreenState extends State<FeexPayPaymentScreen> {
  String? _selectedCountry;
  String? _selectedOperator;
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _currentUserId;

  final Map<String, double> _feexpayFees = {
    'togocom_tg': 3.0,
    'moov_tg': 3.0,
    'mtn': 1.7,
    'moov': 1.7,
    'celtiis_bj': 1.7,
    'coris': 1.7,
    'mtn_ci': 2.0,
    'moov_ci': 2.0,
    'wave_ci': 2.0,
    'orange_ci': 2.0,
    'orange_sn': 2.0,
    'free_sn': 2.0,
    'wave_sn': 2.0,
    'mtn_cg': 3.0,
  };

  final Map<String, Map<String, String>> _operators = {
    'Bénin': {
      'MTN Bénin': 'mtn',
      'MOOV Bénin': 'moov',
      'CELTIIS Bénin': 'celtiis_bj',
      'CORIS Bénin': 'coris',
    },
    'Togo': {
      'TOGOCOM': 'togocom_tg',
      'MOOV Togo': 'moov_tg',
    },
    'Côte d\'Ivoire': {
      'MTN Côte d\'Ivoire': 'mtn_ci',
      'MOOV Côte d\'Ivoire': 'moov_ci',
      'WAVE Côte d\'Ivoire': 'wave_ci',
      'ORANGE Côte d\'Ivoire': 'orange_ci',
    },
    'Congo Brazzaville': {
      'MTN Congo': 'mtn_cg',
    },
    'Sénégal': {
      'ORANGE Sénégal': 'orange_sn',
      'WAVE Sénégal': 'wave_sn',
      'FREE Sénégal': 'free_sn',
    },
  };

  final Set<String> _operatorsNeedingReturnUrl = {
    'wave_sn', 'free_sn', 'wave_ci',
  };

  final Map<String, String> _phonePrefixes = {
    'Bénin': '229',
    'Togo': '228',
    'Côte d\'Ivoire': '225',
    'Congo Brazzaville': '242',
    'Sénégal': '221',
  };

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _getCurrentUser() {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Erreur', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message, VoidCallback onOk) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Succès', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onOk();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Session expirée', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
            SizedBox(height: 16),
            Text('Votre session a expiré. Veuillez vous reconnecter.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Get.offAllNamed('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Se reconnecter'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSessionExpiredDialog();
      return;
    }

    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showErrorDialog('Veuillez saisir votre numéro');
      return;
    }
    if (_selectedCountry == null || _selectedOperator == null) {
      _showErrorDialog('Sélectionnez un pays et un opérateur');
      return;
    }

    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final prefix = _phonePrefixes[_selectedCountry];
    if (!phone.startsWith(prefix!)) {
      phone = prefix + phone;
    }

    setState(() => _isLoading = true);

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('executeAfrolookFeexpayPayment');

      final operatorCode = _operators[_selectedCountry]![_selectedOperator];
      final needsReturnUrl = _operatorsNeedingReturnUrl.contains(operatorCode);
      final feexpayFeePercent = _feexpayFees[operatorCode] ?? 0;

      final userPays = widget.amount;
      final amountToSendToFeexPay = (userPays / (1 + feexpayFeePercent / 100)).ceil();

      print('=== CALCUL DES FRAIS AFROLOOK ===');
      print('Opérateur: $_selectedOperator ($operatorCode)');
      print('Frais FeexPay: $feexpayFeePercent%');
      print('Montant à payer: $userPays FCFA');
      print('Montant à envoyer: $amountToSendToFeexPay FCFA');

      // ✅ Gestion sécurisée de callback_info


      final params = {
        'token': widget.token,
        'shopId': widget.shopId,
        'amount': amountToSendToFeexPay,
        'phoneNumber': phone,
        'operatorCode': operatorCode,
        'operatorName': _selectedOperator,
        'country': _selectedCountry,
        // 'callbackInfo': widget.callbackInfo,  // ← Envoyer comme string
        'callbackInfo': jsonEncode(widget.callbackInfo),  // ← Envoyer comme string

        // 'callbackInfo': callbackInfoMap,  // ← Envoie le Map directement
      };

      if (needsReturnUrl) {
        params['returnUrl'] = widget.redirectUrl;
      }

      final result = await callable(params);

      if (result.data['success'] == true) {
        final reference = result.data['reference'];
        final paymentUrl = result.data['paymentUrl'];

        final transactionId = widget.callbackInfo['transactionId'];

        await FirebaseFirestore.instance
            .collection('pending_afrolook_feexpay_deposits')
            .doc(transactionId)
            .update({
          'reference': reference,
          'status': 'processing',
          'updatedAt': FieldValue.serverTimestamp(),
          'amountSentToFeexPay': amountToSendToFeexPay,
          'feexpayFeePercent': feexpayFeePercent,
          'operatorCode': operatorCode,
          'operatorName': _selectedOperator,
        });

        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          if (await canLaunchUrl(Uri.parse(paymentUrl))) {
            await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
          }
        }

        _showSuccessDialog('Paiement initié avec succès !', () {
          Navigator.pop(context);
          _showWaitingScreen(reference);
        });
      } else {
        _showErrorDialog(result.data['message'] ?? 'Échec du paiement');
      }
    } catch (e) {
      print('Erreur: $e');
      _showErrorDialog('Erreur technique. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _showWaitingScreen(String reference) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentWaitingScreen(
          reference: reference,
          transKey: widget.transKey,
          type: 'afrolook_deposit',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paiement FeexPay - Afrolook'),
        backgroundColor: Color(0xFFD8A868),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFD8A868).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Montant à payer', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  SizedBox(height: 8),
                  Text(
                    '${widget.amount} FCFA',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFD8A868)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'N° dépôt: ${widget.depositNumber}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            _buildDropdown(
              label: 'Pays',
              value: _selectedCountry,
              items: _operators.keys.toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value;
                  _selectedOperator = null;
                  _phoneController.clear();
                });
              },
            ),
            SizedBox(height: 20),
            if (_selectedCountry != null) ...[
              _buildDropdown(
                label: 'Opérateur',
                value: _selectedOperator,
                items: _operators[_selectedCountry]!.keys.toList(),
                onChanged: (value) => setState(() => _selectedOperator = value),
              ),
              SizedBox(height: 20),
              _buildPhoneField(),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFD8A868),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : Text('Payer ${widget.amount} FCFA', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Numéro de téléphone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Ex: ${_phonePrefixes[_selectedCountry]}XXXXXXXXX',
              prefixText: '+${_phonePrefixes[_selectedCountry]} ',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            hint: Text('Sélectionnez $label'),
            decoration: InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16)),
            items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ÉCRAN D'ATTENTE DE CONFIRMATION
// ============================================================

class PaymentWaitingScreen extends StatefulWidget {
  final String reference;
  final String transKey;
  final String type;

  const PaymentWaitingScreen({
    Key? key,
    required this.reference,
    required this.transKey,
    required this.type,
  }) : super(key: key);

  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen> {
  bool _isChecking = true;
  String _message = 'En attente de confirmation du paiement...';
  bool _isSuccess = false;
  int _checkCount = 0;
  final int _maxChecks = 12;
  String? _errorDetails;
  bool _isManualCheck = false;

  @override
  void initState() {
    super.initState();
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    Future.delayed(Duration(seconds: 3), _checkStatus);
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;

    _checkCount++;

    if (_checkCount > _maxChecks) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isSuccess = false;
          _message = '⏰ Délai dépassé. Vérifiez manuellement dans la liste des transactions.';
        });
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isSuccess = false;
          _message = '❌ Session expirée. Veuillez vous reconnecter.';
        });
      }
      return;
    }

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('checkAfrolookFeexpayTransactionStatus');

      final result = await callable({
        'reference': widget.reference,
        'transKey': widget.transKey,
      });

      final status = result.data['status'];
      final success = result.data['success'] == true;
      final pending = result.data['pending'] == true;
      final message = result.data['message'] ?? '';

      print('=== VÉRIFICATION #$_checkCount/$_maxChecks ===');
      print('Status: $status');
      print('Success: $success');
      print('Pending: $pending');

      if (status == 'completed' || success == true) {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _isSuccess = true;
            _message = '✅ Paiement confirmé avec succès !\n\nVotre compte a été crédité.';
          });
        }
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
        });
      } else if (status == 'failed') {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _isSuccess = false;
            _message = '❌ $message';
            _errorDetails = result.data['reason'];
          });
        }
      } else if (pending == true) {
        if (mounted) {
          setState(() {
            _message = '⏳ Paiement en attente... ($_checkCount/$_maxChecks)\nProchaine vérification dans 5 secondes';
          });
          Future.delayed(Duration(seconds: 5), _checkStatus);
        }
      } else {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _isSuccess = false;
            _message = '❌ $message';
          });
        }
      }
    } catch (e) {
      print('Erreur: $e');
      if (mounted && _checkCount < _maxChecks) {
        setState(() {
          _message = '⚠️ Erreur, réessai dans 10 secondes... ($_checkCount/$_maxChecks)';
        });
        Future.delayed(Duration(seconds: 10), _checkStatus);
      } else {
        setState(() {
          _isChecking = false;
          _isSuccess = false;
          _message = '❌ Erreur technique. Vérifiez manuellement.';
        });
      }
    }
  }

  Future<void> _manualCheck() async {
    setState(() {
      _isChecking = true;
      _message = 'Vérification manuelle en cours...';
      _errorDetails = null;
      _checkCount = 0;
    });
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Confirmation du paiement'),
        backgroundColor: Color(0xFFD8A868),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isChecking)
                Container(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(color: Color(0xFFD8A868), strokeWidth: 4),
                )
              else if (_isSuccess)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 50, color: Colors.white),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Icon(Icons.close, size: 50, color: Colors.white),
                ),
              SizedBox(height: 24),
              Text(_message, textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              if (_errorDetails != null && !_isSuccess && !_isChecking) ...[
                SizedBox(height: 12),
                Text(_errorDetails!, style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Text(widget.reference, style: TextStyle(fontSize: 12)),
              ),
              SizedBox(height: 32),
              if (!_isSuccess && !_isChecking)
                ElevatedButton(
                  onPressed: _manualCheck,
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFD8A868)),
                  child: Text('Vérifier à nouveau', style: TextStyle(color: Colors.white)),
                ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                child: Text('Retour à l\'accueil', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}