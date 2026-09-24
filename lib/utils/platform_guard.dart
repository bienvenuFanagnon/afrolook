import 'dart:io';
import 'package:flutter/foundation.dart';

/// true sur iOS — masque tout ce qui n'est pas In-App Purchase (Apple Store rules).
/// Mobile Money, dépôts, Afrolove, carte bancaire sont cachés quand c'est true.
bool get kIsAppleStore => !kIsWeb && Platform.isIOS;
