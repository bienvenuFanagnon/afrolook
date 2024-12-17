
bool isInvite(List<String> invitationList, List<String> invitationOtherList, String userIdToCheck) {
  return invitationList.contains(userIdToCheck) || invitationOtherList.contains(userIdToCheck);
}