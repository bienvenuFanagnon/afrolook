// models/payment_config.dart
import 'package:flutter/material.dart';

class PaymentConfig {
  final String countryCode;
  final String countryName;
  final String phoneCode; // ex: "228" pour Togo
  final int phoneLength; // nombre de chiffres après l'indicatif
  final List<PaymentMethod> paymentMethods;
  final bool isActive;

  PaymentConfig({
    required this.countryCode,
    required this.countryName,
    required this.phoneCode,
    required this.phoneLength,
    required this.paymentMethods,
    this.isActive = true,
  });

  // Configuration pour le TOGO
  static PaymentConfig get togo => PaymentConfig(
    countryCode: 'TG',
    countryName: 'Togo',
    phoneCode: '228',
    phoneLength: 8,
    paymentMethods: [
      PaymentMethod(code: 'MOOV_TG', name: 'MOOV TG', icon: Icons.phone_android),
      PaymentMethod(code: 'TMONEY_TG', name: 'TMONEY TG', icon: Icons.phone_iphone),
    ],
  );

  // Configuration pour la CÔTE D'IVOIRE (exemple)
  static PaymentConfig get coteIvoire => PaymentConfig(
    countryCode: 'CI',
    countryName: 'Côte d\'Ivoire',
    phoneCode: '225',
    phoneLength: 8,
    paymentMethods: [
      PaymentMethod(code: 'ORANGE_MONEY_CI', name: 'Orange Money CI', icon: Icons.phone_android),
      PaymentMethod(code: 'MTN_MONEY_CI', name: 'MTN Money CI', icon: Icons.phone_iphone),
      PaymentMethod(code: 'WAVE_CI', name: 'Wave CI', icon: Icons.waves),
    ],
  );

  // Configuration pour le SÉNÉGAL (exemple)
  static PaymentConfig get senegal => PaymentConfig(
    countryCode: 'SN',
    countryName: 'Sénégal',
    phoneCode: '221',
    phoneLength: 9,
    paymentMethods: [
      PaymentMethod(code: 'ORANGE_MONEY_SN', name: 'Orange Money SN', icon: Icons.phone_android),
      PaymentMethod(code: 'FREE_MONEY_SN', name: 'Free Money SN', icon: Icons.phone_iphone),
      PaymentMethod(code: 'WAVE_SN', name: 'Wave SN', icon: Icons.waves),
    ],
  );

  // Configuration pour le CAMEROUN (exemple)
  static PaymentConfig get cameroun => PaymentConfig(
    countryCode: 'CM',
    countryName: 'Cameroun',
    phoneCode: '237',
    phoneLength: 9,
    paymentMethods: [
      PaymentMethod(code: 'ORANGE_MONEY_CM', name: 'Orange Money CM', icon: Icons.phone_android),
      PaymentMethod(code: 'MTN_MONEY_CM', name: 'MTN Money CM', icon: Icons.phone_iphone),
    ],
  );

  // Liste de tous les pays actifs
  static List<PaymentConfig> get activeCountries => [
    togo,
    // Décommentez pour activer d'autres pays
    // coteIvoire,
    // senegal,
    // cameroun,
  ];

  // Validation du numéro selon le pays
  String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro de retrait';
    }

    // Nettoyer le numéro
    String cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Si le numéro commence déjà par l'indicatif
    if (cleaned.startsWith(phoneCode)) {
      if (cleaned.length == phoneCode.length + phoneLength &&
          RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
        return null;
      }
      return 'Numéro invalide. Format: $phoneCode suivi de $phoneLength chiffres';
    }

    // Si l'utilisateur a saisi sans indicatif
    if (cleaned.length == phoneLength && RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
      return null; // Sera auto-complété
    }

    return 'Format invalide. Utilisez $phoneCode suivi de $phoneLength chiffres';
  }

  String formatPhoneNumber(String number) {
    String cleaned = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!cleaned.startsWith(phoneCode) && cleaned.length == phoneLength) {
      return '$phoneCode$cleaned';
    }
    return cleaned;
  }
}

class PaymentMethod {
  final String code;
  final String name;
  final IconData icon;

  PaymentMethod({
    required this.code,
    required this.name,
    required this.icon,
  });
}