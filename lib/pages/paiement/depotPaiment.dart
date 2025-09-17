import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

class PaiementPage extends StatefulWidget {
  final double montant;
  final Function(bool) onSuccess;

  const PaiementPage({
    Key? key,
    required this.montant,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _PaiementPageState createState() => _PaiementPageState();
}

class _PaiementPageState extends State<PaiementPage> {
  bool _loading = false;

  Future<void> _initierPaiement() async {
    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non authentifié");

      final userRef = FirebaseFirestore.instance.collection("Users").doc(user.uid);
      final userDoc = await userRef.get();
      if (!userDoc.exists) throw Exception("Utilisateur non trouvé");

      // Montant et frais
      final amountInt = widget.montant.round();
      final fees = (amountInt * 0.056).round();
      final amountWithoutFees = amountInt - fees;

      // Créer transaction pending
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
      final depositNumber = "D-${transactionId}";
      final pendingRef = FirebaseFirestore.instance.collection("pending_afrolook_deposits").doc(transactionId);

      await pendingRef.set({
        "userId": user.uid,
        "amount": amountInt,
        "amountWithoutFees": amountWithoutFees,
        "fees": fees,
        "status": "pending",
        "depositNumber": depositNumber,
        "createdAt": FieldValue.serverTimestamp(),
        "type": "afrolook_deposit",
      });

      // Config CinetPay
      final apiKey = "102325650865f879a7b10492.83921456";
      final siteid = "5870078";
      final notifyUrl = "https://afrolookdepositcallback-jnai5yirmq-uc.a.run.app";
      final returnUrl = "https://epargneplus-bc22b.web.app/payment-success";

      // Construire signature
      final signatureString = "$siteid$transactionId${DateTime.now().toIso8601String()}${amountInt}XOF""SINGLEPAYMENT$returnUrl$notifyUrl${user.uid}Recharge portefeuille AfrolookfrV3";
      final signature = Hmac(sha256, utf8.encode(apiKey)).convert(utf8.encode(signatureString)).toString();

      // Appel API CinetPay
      final response = await http.post(
        Uri.parse("https://api-checkout.cinetpay.com/v2/payment"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "apikey": apiKey,
          "site_id": siteid,
          "transaction_id": transactionId,
          "amount": amountInt,
          "currency": "XOF",
          "description": "Recharge portefeuille Afrolook",
          "customer_id": user.uid,
          "return_url": returnUrl,
          "notify_url": notifyUrl,
          "channels": "ALL",
          "metadata": user.uid,
          "signature": signature,
        }),
      );

      final jsonResp = json.decode(response.body);
      final paymentUrl = jsonResp['data']?['payment_url'];
      if (paymentUrl == null) throw Exception("Lien de paiement introuvable");

      if (await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
      } else {
        throw Exception("Impossible d'ouvrir le lien de paiement");
      }

      widget.onSuccess(true);
      Navigator.pop(context);
    } catch (e) {
      // Mettre à jour transaction en failed si besoin
      print("Erreur paiement: $e");
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Erreur de paiement"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initierPaiement(); // lancer paiement à l'ouverture
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : const Text("Initialisation du paiement..."),
      ),
    );
  }
}
