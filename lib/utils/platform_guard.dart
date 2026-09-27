import 'dart:io';
import 'package:flutter/foundation.dart';

/// true sur iOS — masque tout ce qui n'est pas In-App Purchase (Apple Store rules).
/// Mobile Money, dépôts, Afrolove, carte bancaire sont cachés quand c'est true.
bool get kIsAppleStore => !kIsWeb && Platform.isIOS;

/// Tous les achats de l'app se paient en pièces, sur Android comme sur iPhone
/// (décision 2026-09-27), sauf les contenus payants qui restent en FCFA.
const bool kPayInCoins = true;
