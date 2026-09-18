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
      PaymentMethod(code: 'moov_tg',     name: 'MOOV TG',   icon: Icons.phone_android),
      PaymentMethod(code: 'togocom_tg', name: 'TOGOCOM',   icon: Icons.phone_iphone),
    ],
  );

  // Configuration pour le BÉNIN
  static PaymentConfig get benin => PaymentConfig(
    countryCode: 'BJ',
    countryName: 'Bénin',
    phoneCode: '229',
    phoneLength: 8,
    paymentMethods: [
      PaymentMethod(code: 'mtn',        name: 'MTN Bénin',     icon: Icons.phone_android),
      PaymentMethod(code: 'moov',       name: 'MOOV Bénin',    icon: Icons.phone_iphone),
      PaymentMethod(code: 'celtiis_bj', name: 'CELTIIS Bénin', icon: Icons.phone_android),
      PaymentMethod(code: 'coris',      name: 'CORIS Bénin',   icon: Icons.account_balance),
    ],
  );

  // Configuration pour la CÔTE D'IVOIRE
  static PaymentConfig get coteIvoire => PaymentConfig(
    countryCode: 'CI',
    countryName: 'Côte d\'Ivoire',
    phoneCode: '225',
    phoneLength: 10,
    paymentMethods: [
      PaymentMethod(code: 'mtn_ci',    name: 'MTN CI',    icon: Icons.phone_android),
      PaymentMethod(code: 'moov_ci',   name: 'MOOV CI',   icon: Icons.phone_iphone),
      PaymentMethod(code: 'wave_ci',   name: 'WAVE CI',   icon: Icons.waves),
      PaymentMethod(code: 'orange_ci', name: 'ORANGE CI', icon: Icons.phone_android),
    ],
  );

  // Configuration pour le CONGO BRAZZAVILLE
  static PaymentConfig get congo => PaymentConfig(
    countryCode: 'CG',
    countryName: 'Congo Brazzaville',
    phoneCode: '242',
    phoneLength: 9,
    paymentMethods: [
      PaymentMethod(code: 'mtn_cg', name: 'MTN Congo', icon: Icons.phone_android),
    ],
  );

  // Configuration pour le SÉNÉGAL
  static PaymentConfig get senegal => PaymentConfig(
    countryCode: 'SN',
    countryName: 'Sénégal',
    phoneCode: '221',
    phoneLength: 9,
    paymentMethods: [
      PaymentMethod(code: 'orange_sn', name: 'ORANGE SN', icon: Icons.phone_android),
      PaymentMethod(code: 'wave_sn',   name: 'WAVE SN',   icon: Icons.waves),
      PaymentMethod(code: 'free_sn',   name: 'FREE SN',   icon: Icons.phone_iphone),
    ],
  );

  // Configuration pour le BURKINA FASO
  static PaymentConfig get burkinaFaso => PaymentConfig(
    countryCode: 'BF',
    countryName: 'Burkina Faso',
    phoneCode: '226',
    phoneLength: 8,
    paymentMethods: [
      PaymentMethod(code: 'moov_bf',   name: 'Moov BF',   icon: Icons.phone_android),
      PaymentMethod(code: 'orange_bf', name: 'Orange BF', icon: Icons.phone_iphone),
      PaymentMethod(code: 'wave_bf',   name: 'Wave BF',   icon: Icons.waves),
    ],
  );

  // Configuration pour le MALI
  static PaymentConfig get mali => PaymentConfig(
    countryCode: 'ML',
    countryName: 'Mali',
    phoneCode: '223',
    phoneLength: 8,
    paymentMethods: [
      PaymentMethod(code: 'orange_ml',   name: 'Orange Mali',   icon: Icons.phone_android),
      PaymentMethod(code: 'mobicash_ml', name: 'Mobicash Mali', icon: Icons.phone_iphone),
    ],
  );

  // Liste de tous les pays actifs pour dépôt et retrait.
  // L'admin contrôle opérateur par opérateur ce qui est activé (isPayinEnabled / isPayoutEnabled).
  static List<PaymentConfig> get activeCountries => [
    togo,
    burkinaFaso,
    mali,
    benin,
    coteIvoire,
    congo,
    senegal,
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