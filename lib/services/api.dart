class ApiConstantData {
  ApiConstantData();

  static String url="http://10.0.2.2:8000";
  //static String url="http://127.0.0.1:8000";

  //static String url = "https://app-api.assistup.africa";

  //static String url="https://app.ouellett.com";
  static String urlApi = url + "/api";
  static String login = urlApi + "/auth/login";
  static String register = urlApi + "/auth/register";
  static String listNumber = urlApi + "/user/phone/number/list";
  static String listPseudo = urlApi + "/user/pseudo/list";
  static String listUsers = urlApi + "/user/list";
  static String abonner = urlApi + "/user/abonne";
  static String lisUserTags = urlApi + "/user/global/tags/list";
  static String onlyUserByToken = urlApi + "/user/token";
  static String newInvitation = urlApi + "/user/invitation/new";
  static String listUserInvitation = urlApi + "/user/invitation/list";
  static String acceptInvitation = urlApi + "/user/invitation/accepter";


  static String newMessage = urlApi + "/user/message/new";
  static String getChat = urlApi + "/user/chat/users";


}