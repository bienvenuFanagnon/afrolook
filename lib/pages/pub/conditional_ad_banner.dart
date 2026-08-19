import 'package:flutter/material.dart';

import 'afrolook_inline_ad.dart';

/// Délégue à AfrolookInlineAd qui gère déjà la condition Premium/Admin
/// et affiche nos propres posts pub (pas Appodeal).
class ConditionalAdBanner extends StatelessWidget {
  const ConditionalAdBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AfrolookInlineAd();
  }
}
