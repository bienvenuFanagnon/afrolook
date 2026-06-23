import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:app_links/app_links.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/model_data.dart';

import '../pages/chronique/chroniquedetails.dart';

import '../pages/chronique/chroniquehome.dart';

import '../pages/chat/myChat.dart';

import '../pages/postDetails.dart';

import '../pages/postDetailsVideo.dart';

import '../pages/user/amis/pageMesInvitations.dart';

import '../pages/user/amis/ami.dart';

import '../pages/mes_notifications.dart';

import '../pages/user/monetisation.dart';

import '../pages/home/homeScreen.dart';

import '../models/chatmodels/message.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Callbacks pour le splash
  Function(String postId, String postType)? onPostNotification;
  Function(String chatId, String sendUserId)? onMessageNotification;
  Function(String postId)? onChroniqueNotification;
  Function()? onInvitationNotification;
  Function()? onAcceptInvitationNotification;
  Function()? onParrainageNotification;
  Function()? onArticleNotification;

  // Variables pour stocker les paramètres en attente
  String? _pendingPostId;
  String? _pendingPostType;
  String? _pendingChatId;
  String? _pendingSendUserId;
  String? _pendingChroniqueId;
  String? _pendingType;
  bool _hasPending = false;

  void initialize() {
    _initOneSignal();
    _initDeepLinks();
  }

  void _initOneSignal() {
    if (kIsWeb) return;

    OneSignal.Notifications.addClickListener((event) async {
      printVm("📱 [NAVIGATION_SERVICE] Notification cliquée");

      await Future.delayed(const Duration(milliseconds: 300));

      final additionalData = event.notification.additionalData;
      if (additionalData == null) return;

      final typeNotif = additionalData['type_notif'] as String?;
      final postType = additionalData['post_type'] as String? ?? '';
      final postId = additionalData['post_id'] as String?;
      final chatId = additionalData['chat_id'] as String?;
      final sendUserId = additionalData['send_user_id'] as String?;

      printVm("📱 [NAVIGATION_SERVICE] type: $typeNotif, postId: $postId");

      // Chronique
      if (postType == 'CHRONIQUE' ||
          typeNotif == 'CHRONIQUE' ||
          (typeNotif == 'LIKE' && postType == 'CHRONIQUE') ||
          (typeNotif == 'COMMENT' && postType == 'CHRONIQUE') ||
          (typeNotif == 'COMMENT_LIKE')) {

        if (onChroniqueNotification != null) {
          onChroniqueNotification!(postId ?? '');
        } else {
          _pendingChroniqueId = postId;
          _pendingType = 'chronique';
          _hasPending = true;
        }
        return;
      }

      // Message
      if (typeNotif == NotificationType.MESSAGE.name) {
        if (chatId != null && sendUserId != null) {
          if (onMessageNotification != null) {
            onMessageNotification!(chatId, sendUserId);
          } else {
            _pendingChatId = chatId;
            _pendingSendUserId = sendUserId;
            _pendingType = 'message';
            _hasPending = true;
          }
        }
        return;
      }

      // Invitation
      if (typeNotif == NotificationType.INVITATION.name) {
        if (onInvitationNotification != null) {
          onInvitationNotification!();
        } else {
          _pendingType = 'invitation';
          _hasPending = true;
        }
        return;
      }

      // Acceptation invitation
      if (typeNotif == NotificationType.ACCEPTINVITATION.name) {
        if (onAcceptInvitationNotification != null) {
          onAcceptInvitationNotification!();
        } else {
          _pendingType = 'acceptInvitation';
          _hasPending = true;
        }
        return;
      }

      // Parrainage
      if (typeNotif == NotificationType.PARRAINAGE.name) {
        if (onParrainageNotification != null) {
          onParrainageNotification!();
        } else {
          _pendingType = 'parrainage';
          _hasPending = true;
        }
        return;
      }

      // Article
      if (typeNotif == NotificationType.ARTICLE.name) {
        if (onArticleNotification != null) {
          onArticleNotification!();
        } else {
          _pendingType = 'article';
          _hasPending = true;
        }
        return;
      }

      // Post (VIDEO / IMAGE / FAVORI)
      if (typeNotif == NotificationType.POST.name || typeNotif == NotificationType.FAVORITE.name) {
        if (postId != null && postId.isNotEmpty) {
          if (onPostNotification != null) {
            onPostNotification!(postId, postType);
          } else {
            _pendingPostId = postId;
            _pendingPostType = postType;
            _pendingType = 'post';
            _hasPending = true;
          }
        }
        return;
      }
    });
  }

  void _initDeepLinks() {
    AppLinks().uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        final segments = uri.pathSegments;
        if (segments.length >= 3 && segments[0] == 'share') {
          String rawId = segments[2];
          final cleanId = rawId.split('?')[0].split('#')[0];
          final typeStr = segments[1];

          printVm("🔗 [NAVIGATION_SERVICE] Deep link: type=$typeStr, id=$cleanId");

          if (typeStr.toLowerCase() == 'chronique') {
            if (onChroniqueNotification != null) {
              onChroniqueNotification!(cleanId);
            } else {
              _pendingChroniqueId = cleanId;
              _pendingType = 'chronique';
              _hasPending = true;
            }
          } else {
            String postType = typeStr.toLowerCase() == 'video' ? 'VIDEO' : 'IMAGE';
            if (onPostNotification != null) {
              onPostNotification!(cleanId, postType);
            } else {
              _pendingPostId = cleanId;
              _pendingPostType = postType;
              _pendingType = 'post';
              _hasPending = true;
            }
          }
        }
      }
    });
  }

  // Récupérer les paramètres en attente
  Map<String, dynamic>? getPendingParams() {
    if (!_hasPending) return null;

    _hasPending = false;

    switch (_pendingType) {
      case 'post':
        return {'type': 'post', 'postId': _pendingPostId, 'postType': _pendingPostType};
      case 'message':
        return {'type': 'message', 'chatId': _pendingChatId, 'sendUserId': _pendingSendUserId};
      case 'chronique':
        return {'type': 'chronique', 'chroniqueId': _pendingChroniqueId};
      case 'invitation':
        return {'type': 'invitation'};
      case 'acceptInvitation':
        return {'type': 'acceptInvitation'};
      case 'parrainage':
        return {'type': 'parrainage'};
      case 'article':
        return {'type': 'article'};
      default:
        return null;
    }
  }

  // Navigation directe pour MyHomePage (app déjà ouverte)
  Future<void> navigateToPost(BuildContext context, String postId, String postType) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post non trouvé')),
        );
        return;
      }

      final post = Post.fromJson(postDoc.data() as Map<String, dynamic>);
      post.id = postDoc.id;

      Navigator.pop(context);

      if (post.dataType == PostDataType.VIDEO.name) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoYoutubePageDetails(initialPost: post),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsPost(post: post),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      printVm("Erreur navigation post: $e");
    }
  }

  Future<void> navigateToChat(BuildContext context, String chatId, String sendUserId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('Chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        Navigator.pop(context);
        return;
      }

      final chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);

      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(sendUserId)
          .get();

      if (userDoc.exists) {
        chat.chatFriend = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
        chat.receiver = chat.chatFriend;
      }

      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('Messages')
          .where('chat_id', isEqualTo: chatId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      chat.messages = messagesSnapshot.docs
          .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MyChat(title: 'mon chat', chat: chat)),
      );
    } catch (e) {
      Navigator.pop(context);
      printVm("Erreur navigation chat: $e");
    }
  }
}