
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

// bool isInvite(UserData otherUser, UserData userIdToCheck) {
//   printVm('invittion: ${ userIdToCheck.mesInvitationsEnvoyerId! .contains(otherUser.id) || userIdToCheck .autreInvitationsEnvoyerId!.contains(otherUser.id)|| otherUser.mesInvitationsEnvoyerId! .contains(userIdToCheck.id) || otherUser.autreInvitationsEnvoyerId!.contains(userIdToCheck.id)|| otherUser.friendsIds!.contains(userIdToCheck.id) || userIdToCheck.friendsIds!.contains(otherUser.id)
//   }');
//   return userIdToCheck.mesInvitationsEnvoyerId! .contains(otherUser.id) || userIdToCheck .autreInvitationsEnvoyerId!.contains(otherUser.id)|| otherUser.mesInvitationsEnvoyerId! .contains(userIdToCheck.id) || otherUser.autreInvitationsEnvoyerId!.contains(userIdToCheck.id)|| otherUser.friendsIds!.contains(userIdToCheck.id) || userIdToCheck.friendsIds!.contains(otherUser.id);
// }
//
// bool isMyFriend(UserData otherUser, UserData userIdToCheck) {
//   printVm("On est amis: ${otherUser.friendsIds!.contains(userIdToCheck.id) || userIdToCheck.friendsIds!.contains(otherUser.id)}");
//   return otherUser.friendsIds!.contains(userIdToCheck.id) || userIdToCheck.friendsIds!.contains(otherUser.id);
// }


bool isMyFriend(UserData otherUser, UserData userIdToCheck) {
  // Vérifie si les deux utilisateurs sont amis
  bool areFriends = otherUser.friendsIds!.contains(userIdToCheck.id) ||
      userIdToCheck.friendsIds!.contains(otherUser.id);

  // Debug: Affiche les états pour le débogage
  printVm("On est amis: $areFriends");

  return areFriends;
}

bool isInvite(UserData otherUser, UserData userIdToCheck) {
  // Variables intermédiaires pour une meilleure lisibilité
  bool hasSentInvite = userIdToCheck.mesInvitationsEnvoyerId!.contains(otherUser.id) ||
      userIdToCheck.autreInvitationsEnvoyerId!.contains(otherUser.id);

  bool hasReceivedInvite = otherUser.mesInvitationsEnvoyerId!.contains(userIdToCheck.id) ||
      otherUser.autreInvitationsEnvoyerId!.contains(userIdToCheck.id);

  bool areFriends = otherUser.friendsIds!.contains(userIdToCheck.id) ||
      userIdToCheck.friendsIds!.contains(otherUser.id);

  // Debug: Affiche les états pour le débogage
  printVm('Invitation: ${hasSentInvite || hasReceivedInvite || areFriends}');

  // Retourne le résultat final
  return hasSentInvite || hasReceivedInvite || areFriends;
}
