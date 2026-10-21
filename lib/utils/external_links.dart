import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/feed/sections/social_follow_card.dart';

/// Pages officielles d'Afrolook. WhatsApp = la CHAÎNE (https://whatsapp.com/channel/…), et non le numéro de contact (wa.me/…).
const Map<String, String> kSocialUrls = {
  'whatsapp': SocialFollowCard.whatsappUrl,
  'facebook': SocialFollowCard.facebookUrl,
  'tiktok': SocialFollowCard.tiktokUrl,
};

/// Ouvre la page du réseau (« whatsapp », « facebook » ou « tiktok ») dans l'application correspondante (ou le navigateur à défaut), compte le clic côté
/// serveur et retient que la personne a été dirigée vers ce réseau : le serveur ne lui redemande plus de nous suivre (`Users.<réseau>Followed`).
Future<bool> openSocial(String network) async {
  final url = kSocialUrls[network];
  if (url == null) return false;
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (opened) {
    FirebaseFunctions.instance.httpsCallable('recordSocialClick').call({'network': network}).ignore();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('Users').doc(uid).update({'${network}Followed': true}).catchError((_) {});
    }
  }
  return opened;
}

Future<bool> openWhatsappChannel() => openSocial('whatsapp');
