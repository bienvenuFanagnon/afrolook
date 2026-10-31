import 'package:afrotok/services/api/publications_api.dart';
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
    // Le compteur de clics et le « déjà dirigé vers ce réseau » sont tenus par le serveur (POST /home/social-clicks).
    PubApi.socialClick(network);
  }
  return opened;
}

Future<bool> openWhatsappChannel() => openSocial('whatsapp');
