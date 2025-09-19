import 'dart:convert';
import 'dart:io';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/models/chatmodels/models.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constant/constColors.dart';
import '../../constant/sizeText.dart';
import '../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../user/detailsOtherUser.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/models/chatmodels/models.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../constant/constColors.dart';
import '../../constant/sizeText.dart';
import '../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../user/detailsOtherUser.dart';

class MyChat extends StatefulWidget {
  final String title;
  final Chat chat;

  MyChat({Key? key, required this.title, required this.chat}) : super(key: key);

  @override
  _MyChatState createState() => _MyChatState();
}

class _MyChatState extends State<MyChat> with WidgetsBindingObserver, TickerProviderStateMixin {
  // Variables d'état
  late bool replying = false;
  late String replyingTo = '';
  late TextEditingController _textController = TextEditingController();
  Map<String, AudioPlayer> audioPlayers = {};
  Map<String, Duration> audioDurations = {};
  Map<String, Duration> audioPositions = {};
  Map<String, bool> audioPlayingStates = {};
  Map<String, bool> audioLoadingStates = {};
  Map<String, bool> audioPauseStates = {};

  bool fileDownloading = false;
  bool sendMessageTap = false;
  ScrollController _controller = ScrollController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  File? _image;
  final _picker = ImagePicker();
  FocusNode _focusNode = FocusNode();
  bool _isRecording = false;
  AudioRecorder? _audioRecorder;
  String? _audioPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Providers
  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);

    // Initialiser le contrôleur
    _controller = ScrollController();

    // Initialiser l'enregistreur audio
    _audioRecorder = AudioRecorder();

    // Initialiser le chat
    _initializeChat();
  }

  void _initializeChat() {
    if (widget.chat.senderId != authProvider.loginUserData.id!) {
      widget.chat.your_msg_not_read = 0;
    } else {
      widget.chat.my_msg_not_read = 0;
    }

    firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateChatStatusOnDispose();

    // Arrêter tous les lecteurs audio
    audioPlayers.forEach((key, player) {
      player.dispose();
    });

    // Arrêter l'enregistrement s'il est en cours
    if (_isRecording) {
      _stopRecording(cancel: true);
    }

    // Annuler le timer d'enregistrement
    _recordingTimer?.cancel();

    super.dispose();
  }

  void _updateChatStatusOnDispose() {
    if (widget.chat.senderId == authProvider.loginUserData.id!) {
      widget.chat.send_sending = IsSendMessage.NOTSENDING.name;
    } else {
      widget.chat.receiver_sending = IsSendMessage.NOTSENDING.name;
    }

    firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
  }

  // Méthodes utilitaires
  String formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return "${(number / 1000).toStringAsFixed(1)} k";
    if (number < 1000000000) return "${(number / 1000000).toStringAsFixed(1)} m";
    return "${(number / 1000000000).toStringAsFixed(1)} b";
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) return "il y a quelques secondes";
        return "il y a ${difference.inMinutes} minutes";
      }
      return "il y a ${difference.inHours} heures";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} jours plus tôt";
    }
    return DateFormat('dd MMMM yyyy').format(dateTime);
  }

  // Stream des messages
  Stream<List<Message>> getMessageData() async* {
    var messagesStream = FirebaseFirestore.instance
        .collection('Messages')
        .where('chat_id', isEqualTo: widget.chat.docId!)
        .where('is_valide', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots();

    await for (var snapshot in messagesStream) {
      List<Message> messages = snapshot.docs
          .map((doc) => Message.fromJson(doc.data()))
          .toList();

      userProvider.chat.messages = messages;

      // Scroll vers le bas après avoir reçu les messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.jumpTo(_controller.position.maxScrollExtent);
        }
      });

      yield messages;
    }
  }

  // Gestion des images
  Future getImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  String? getStringImage(File? file) {
    if (file == null) return null;
    return base64Encode(file.readAsBytesSync());
  }

  // Affichage des détails utilisateur
  void _showUserDetailsModalDialog(UserData user, double w, double h) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: DetailsOtherUser(user: user, w: w, h: h),
        );
      },
    );
  }

  // Gestion audio
  void _changeSeek(String messageId, double value) {
    setState(() {
      audioPlayers[messageId]?.seek(Duration(seconds: value.toInt()));
    });
  }

  void _playAudio(String messageId, String url) async {
    // Initialiser le lecteur audio pour ce message s'il n'existe pas
    if (!audioPlayers.containsKey(messageId)) {
      audioPlayers[messageId] = AudioPlayer();
      audioPlayingStates[messageId] = false;
      audioLoadingStates[messageId] = false;
      audioPauseStates[messageId] = false;
      audioDurations[messageId] = Duration();
      audioPositions[messageId] = Duration();

      // Écouter les changements de durée
      audioPlayers[messageId]!.onDurationChanged.listen((Duration d) {
        setState(() {
          audioDurations[messageId] = d;
          audioLoadingStates[messageId] = false;
        });
      });

      // Écouter les changements de position
      audioPlayers[messageId]!.onPositionChanged.listen((Duration p) {
        setState(() {
          audioPositions[messageId] = p;
        });
      });

      // Écouter la fin de la lecture
      audioPlayers[messageId]!.onPlayerComplete.listen((event) {
        setState(() {
          audioPlayingStates[messageId] = false;
          audioPauseStates[messageId] = false;
          audioDurations[messageId] = Duration();
          audioPositions[messageId] = Duration();
        });
      });
    }

    final player = audioPlayers[messageId]!;
    final isPause = audioPauseStates[messageId] ?? false;
    final isPlaying = audioPlayingStates[messageId] ?? false;

    if (isPause) {
      await player.resume();
      setState(() {
        audioPlayingStates[messageId] = true;
        audioPauseStates[messageId] = false;
      });
    } else if (isPlaying) {
      await player.pause();
      setState(() {
        audioPlayingStates[messageId] = false;
        audioPauseStates[messageId] = true;
      });
    } else {
      setState(() => audioLoadingStates[messageId] = true);
      await player.play(UrlSource(url));
      setState(() {
        audioPlayingStates[messageId] = true;
        audioLoadingStates[messageId] = false;
      });
    }
  }

  // Enregistrement audio
  Future<void> _startRecording() async {
    try {
      // Demander la permission
      if (await Permission.microphone.request().isGranted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });

        // Démarrer le timer pour la durée d'enregistrement
        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration = timer.tick;
          });
        });

        // Chemin pour sauvegarder l'audio
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Configurer et démarrer l'enregistrement
        await _audioRecorder!.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _audioPath = path;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission microphone refusée'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de l'enregistrement: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du démarrage de l\'enregistrement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    try {
      _recordingTimer?.cancel();

      if (_audioRecorder != null) {
        await _audioRecorder!.stop();
      }

      if (cancel) {
        // Supprimer le fichier temporaire si annulation
        if (_audioPath != null && File(_audioPath!).existsSync()) {
          await File(_audioPath!).delete();
        }
      } else if (_audioPath != null) {
        // Envoyer l'audio enregistré
        await _sendAudioMessage(_audioPath!);
      }

      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
        _audioPath = null;
      });
    } catch (e) {
      print("Erreur lors de l'arrêt de l'enregistrement: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'arrêt de l\'enregistrement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Envoi de message
  Future<void> _sendMessage() async {
    if (sendMessageTap) return;

    setState(() => sendMessageTap = true);

    try {
      if (_image != null) {
        await _sendImageMessage();
      } else if (_textController.text.isNotEmpty) {
        await _sendTextMessage();
      }
    } catch (error) {
      print("Erreur d'envoi: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Erreur lors de l'envoi du message",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)
          ),
        ),
      );
    } finally {
      setState(() => sendMessageTap = false);
    }
  }

  Future<void> _sendImageMessage() async {
    setState(() => fileDownloading = true);

    try {
      Reference storageReference = FirebaseStorage.instance.ref().child(
          'chat_images/${Path.basename(_image!.path)}_${DateTime.now().millisecondsSinceEpoch}'
      );

      UploadTask uploadTask = storageReference.putFile(_image!);
      await uploadTask.whenComplete(() async {
        String fileURL = await storageReference.getDownloadURL();

        ReplyMessage reply = ReplyMessage(
            message: replyingTo,
            messageType: MessageType.text.name
        );

        Message msg = Message(
          id: '',
          createdAt: DateTime.now(),
          message: fileURL,
          sendBy: authProvider.loginUserData.id!,
          replyMessage: reply,
          messageType: MessageType.image.name,
          chat_id: widget.chat.docId!,
          create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
          message_state: MessageState.NONLU.name,
          receiverBy: widget.chat.senderId == authProvider.loginUserData.id!
              ? widget.chat.receiverId!
              : widget.chat.senderId!,
          is_valide: true,
        );

        _updateChatCounters("📷 Image");

        String msgid = firestore.collection('Messages').doc().id;
        msg.id = msgid;

        await firestore.collection('Messages').doc(msgid).set(msg.toJson());
        await _sendNotification("📷 Image");
        await _resetChatAfterMessage();
      });
    } catch (e) {
      print("Erreur lors de l'envoi de l'image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Erreur lors de l'envoi de l'image",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)
          ),
        ),
      );
    } finally {
      setState(() {
        fileDownloading = false;
        _image = null;
      });
    }
  }

  Future<void> _sendTextMessage() async {
    ReplyMessage reply = ReplyMessage(
        message: replyingTo,
        messageType: MessageType.text.name
    );

    Message msg = Message(
      id: '',
      createdAt: DateTime.now(),
      message: _textController.text,
      sendBy: authProvider.loginUserData.id!,
      replyMessage: reply,
      messageType: MessageType.text.name,
      chat_id: widget.chat.docId!,
      create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
      message_state: MessageState.NONLU.name,
      receiverBy: widget.chat.senderId == authProvider.loginUserData.id!
          ? widget.chat.receiverId!
          : widget.chat.senderId!,
      is_valide: true,
    );

    _updateChatCounters(_textController.text);
    _textController.clear();

    String msgid = firestore.collection('Messages').doc().id;
    msg.id = msgid;

    await firestore.collection('Messages').doc(msgid).set(msg.toJson());
    await _sendNotification(_textController.text);
    await _resetChatAfterMessage();
  }

  Future<void> _sendAudioMessage(String audioPath) async {
    setState(() => fileDownloading = true);

    try {
      // Uploader l'audio vers Firebase Storage
      Reference storageReference = FirebaseStorage.instance.ref().child(
          'chat_audio/audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
      );

      UploadTask uploadTask = storageReference.putFile(File(audioPath));
      await uploadTask.whenComplete(() async {
        String fileURL = await storageReference.getDownloadURL();

        ReplyMessage reply = ReplyMessage(
            message: replyingTo,
            messageType: MessageType.text.name
        );

        Message msg = Message(
          id: '',
          createdAt: DateTime.now(),
          message: fileURL,
          sendBy: authProvider.loginUserData.id!,
          replyMessage: reply,
          messageType: MessageType.voice.name,
          chat_id: widget.chat.docId!,
          create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
          message_state: MessageState.NONLU.name,
          receiverBy: widget.chat.senderId == authProvider.loginUserData.id!
              ? widget.chat.receiverId!
              : widget.chat.senderId!,
          is_valide: true,
        );

        _updateChatCounters("🎤 Message audio");

        String msgid = firestore.collection('Messages').doc().id;
        msg.id = msgid;

        await firestore.collection('Messages').doc(msgid).set(msg.toJson());
        await _sendNotification("🎤 Message audio");
        await _resetChatAfterMessage();
      });
    } catch (e) {
      print("Erreur lors de l'envoi de l'audio: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Erreur lors de l'envoi de l'audio",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)
          ),
        ),
      );
    } finally {
      setState(() {
        fileDownloading = false;
        _isRecording = false;
      });
    }
  }

  void _updateChatCounters(String lastMessage) {
    widget.chat.lastMessage = lastMessage;
    widget.chat.updatedAt = DateTime.now().millisecondsSinceEpoch;

    if (widget.chat.senderId == authProvider.loginUserData.id!) {
      widget.chat.your_msg_not_read = (widget.chat.your_msg_not_read ?? 0) + 1;
    } else {
      widget.chat.my_msg_not_read = (widget.chat.my_msg_not_read ?? 0) + 1;
    }
  }

  Future<void> _sendNotification(String messageContent) async {
    final receiverId = widget.chat.senderId == authProvider.loginUserData.id!
        ? widget.chat.receiverId!
        : widget.chat.senderId!;

    final users = await authProvider.getUserById(receiverId);

    if (users.isNotEmpty && users.first.oneIgnalUserid != null &&
        users.first.oneIgnalUserid!.length > 5) {
      await authProvider.sendNotification(
        userIds: [users.first.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: receiverId,
        message: "🗨️ @${authProvider.loginUserData.pseudo!} vous a envoyé un message",
        type_notif: NotificationType.MESSAGE.name,
        post_id: "",
        post_type: "",
        chat_id: widget.chat.id!,
      );
    }
  }

  Future<void> _resetChatAfterMessage() async {
    // Réinitialiser l'état d'écriture
    if (widget.chat.senderId == authProvider.loginUserData.id!) {
      widget.chat.send_sending = IsSendMessage.NOTSENDING.name;
    } else {
      widget.chat.receiver_sending = IsSendMessage.NOTSENDING.name;
    }

    await firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());

    // Scroll vers le bas
    if (_controller.hasClients) {
      _controller.animateTo(
        _controller.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Réinitialiser les états
    setState(() {
      replyingTo = "";
      replying = false;
    });
  }

  // Widget pour l'image URL
  Widget _imageUrl(String url) {
    return Container(
      constraints: BoxConstraints(minHeight: 100, minWidth: 100, maxWidth: 200, maxHeight: 200),
      child: CachedNetworkImage(
        imageUrl: url,
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            Container(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(value: downloadProgress.progress, color: Colors.green),
            ),
        errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
        fit: BoxFit.cover,
      ),
    );
  }

  // Widget pour les bulles de message
  Widget _buildMessageBubble(Message message, bool isLastItem) {
    final isMe = message.sendBy == authProvider.loginUserData.id!;

    Widget messageContent;

    switch (message.messageType) {
      case 'text':
        messageContent = _buildTextMessage(message, isMe);
        break;
      case 'image':
        messageContent = _buildImageMessage(message, isMe);
        break;
      case 'voice':
        messageContent = _buildVoiceMessage(message, isMe);
        break;
      default:
        messageContent = _buildTextMessage(message, isMe);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (message.replyMessage.message.isNotEmpty)
          _buildReplyIndicator(message.replyMessage.message),
        messageContent,
        _buildMessageStatus(message, isMe),
        SizedBox(height: isLastItem ? 100 : 10),
      ],
    );
  }

  Widget _buildTextMessage(Message message, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: BubbleSpecialOne(
        text: message.message,
        isSender: isMe,
        color: isMe ? Colors.green[800]! : Colors.grey[300]!,
        textStyle: TextStyle(
          fontSize: 16,
          color: isMe ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildImageMessage(Message message, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isMe ? "Vous avez envoyé une image" : "a envoyé une image",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          SizedBox(height: 4),
          BubbleNormalImage(
            id: message.id!,
            image: _imageUrl(message.message),
            color: isMe ? Colors.green[800]! : Colors.grey[300]!,
            tail: true,
            isSender: isMe,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessage(Message message, bool isMe) {
    final messageId = message.id!;
    final isPlaying = audioPlayingStates[messageId] ?? false;
    final isLoading = audioLoadingStates[messageId] ?? false;
    final isPause = audioPauseStates[messageId] ?? false;
    final duration = audioDurations[messageId] ?? Duration();
    final position = audioPositions[messageId] ?? Duration();

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          isMe ? "Vous avez envoyé un audio" : "a envoyé un audio",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SizedBox(height: 4),
        BubbleNormalAudio(
          color: isMe ? Colors.green[800]! : Colors.grey[300]!,
          duration: duration.inSeconds.toDouble(),
          position: position.inSeconds.toDouble(),
          isPlaying: isPlaying,
          isLoading: isLoading,
          isPause: isPause,
          onSeekChanged: (value) => _changeSeek(messageId, value),
          onPlayPauseButtonClick: () => _playAudio(messageId, message.message),
          isSender: isMe,
        ),
      ],
    );
  }

  Widget _buildReplyIndicator(String replyText) {
    return BubbleNormal(
      text: 'Re: $replyText',
      isSender: false,
      color: Colors.yellow[100]!,
      textStyle: TextStyle(fontSize: 12, color: Colors.black87),
    );
  }

  Widget _buildMessageStatus(Message message, bool isMe) {
    return Padding(
      padding: isMe
          ? EdgeInsets.only(right: 16.0, bottom: 8, top: 4)
          : EdgeInsets.only(left: 16.0, bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Icon(
            MaterialCommunityIcons.check_all,
            size: 16,
            color: message.message_state == MessageState.LU.name
                ? Colors.green
                : Colors.grey,
          ),
          SizedBox(width: 4),
          Text(
            formaterDateTime(message.createdAt),
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.2,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.sendBy == authProvider.loginUserData.id!)
                  ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Supprimer', style: TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _deleteMessage(message);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.reply, color: Colors.blue),
                  title: Text('Répondre', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      replying = true;
                      replyingTo = message.message;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteMessage(Message message) async {
    message.is_valide = false;
    bool success = await userProvider.updateMessage(message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? Colors.green : Colors.red,
        content: Text(
          success ? 'Message supprimé' : 'Erreur de suppression',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // Barre d'envoi de message
  Widget _buildMessageInput() {
    return Container(
      color: Colors.grey[900],
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          if (replying) _buildReplyIndicatorBar(),
          if (_image != null) _buildImagePreview(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMediaButtons(),
              _buildMessageTextField(),
              _buildSendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicatorBar() {
    return Container(
      color: Colors.yellow[100]!.withOpacity(0.3),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.reply, color: Colors.yellow[700], size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Re : $replyingTo',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.yellow[700]),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                replyingTo = "";
                replying = false;
              });
            },
            child: Icon(Icons.close, color: Colors.yellow[700], size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(_image!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _image = null;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButtons() {
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: getImage,
            child: Icon(Icons.camera_alt, color: Colors.green, size: 28),
          ),
        ),
        // Padding(
        //   padding: EdgeInsets.only(right: 8),
        //   child: InkWell(
        //     onTap: () {
        //       if (_isRecording) {
        //         _stopRecording();
        //       } else {
        //         _startRecording();
        //       }
        //     },
        //     child: Icon(
        //       _isRecording ? Icons.stop : Icons.mic,
        //       color: _isRecording ? Colors.red : Colors.green,
        //       size: 28,
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildMessageTextField() {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                onChanged: (text) {
                  _updateTypingStatus(text.isNotEmpty);
                },
                onTap: () {
                  if (_controller.hasClients) {
                    _controller.animateTo(
                      _controller.position.maxScrollExtent,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _isRecording ? "Enregistrement en cours... ($_recordingDuration s)" : "Écrivez un message...",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTypingStatus(bool isTyping) {
    final status = isTyping ? IsSendMessage.SENDING.name : IsSendMessage.NOTSENDING.name;

    if (widget.chat.senderId == authProvider.loginUserData.id!) {
      widget.chat.send_sending = status;
    } else {
      widget.chat.receiver_sending = status;
    }

    firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
  }

  Widget _buildSendButton() {
    return InkWell(
      onTap: _sendMessage,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.send, color: Colors.white, size: 24),
      ),
    );
  }

  // AppBar personnalisée
  PreferredSizeWidget _buildAppBar(double width, double height) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Row(
        children: [
          _buildUserAvatar(width),
          SizedBox(width: 12),
          _buildUserInfo(),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            if (_controller.hasClients) {
              _controller.animateTo(
                _controller.position.maxScrollExtent,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
          icon: Icon(Icons.arrow_downward, color: Colors.green),
        ),
      ],
      iconTheme: IconThemeData(color: Colors.green),
    );
  }

  Widget _buildUserAvatar(double width) {
    return StreamBuilder<UserData>(
      stream: userProvider.getStreamUser(widget.chat.receiver!.id!),
      builder: (context, snapshot) {
        final user = snapshot.hasData ? snapshot.data! : widget.chat.receiver!;

        return GestureDetector(
          onTap: () => _showUserDetailsModalDialog(user, width, MediaQuery.of(context).size.height),
          child: Stack(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(user.imageUrl!),
                radius: 20,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: user.state == UserState.OFFLINE.name
                        ? Colors.grey
                        : Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserInfo() {
    return StreamBuilder<Chat>(
      stream: userProvider.getStreamChat(widget.chat.id!),
      builder: (context, snapshot) {
        final chat = snapshot.hasData ? snapshot.data! : widget.chat;
        final isTyping = _isUserTyping(chat);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "@${widget.chat.receiver!.pseudo}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (widget.chat.receiver!.isVerify!)
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.verified, color: Colors.green, size: 16),
                  ),
              ],
            ),
            Text(
              isTyping ? "écrit..." : "${formatNumber(widget.chat.receiver!.userAbonnesIds!.length!)} abonné(s)",
              style: TextStyle(
                fontSize: 12,
                color: isTyping ? Colors.green : Colors.grey[400],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isUserTyping(Chat chat) {
    if (authProvider.loginUserData.id == chat.senderId) {
      return chat.receiver_sending == IsSendMessage.SENDING.name;
    } else if (authProvider.loginUserData.id == chat.receiverId) {
      return chat.send_sending == IsSendMessage.SENDING.name;
    }
    return false;
  }

  Widget _buildLoadingMessages() {
    return ListView.builder(
      controller: _controller,
      itemCount: userProvider.chat.messages?.length ?? 0,
      itemBuilder: (context, index) {
        final message = userProvider.chat.messages![index];
        final isLastItem = index == (userProvider.chat.messages!.length - 1);
        return _buildMessageBubble(message, isLastItem);
      },
    );
  }

  Widget _buildMessageList(List<Message> messages) {
    return ListView.builder(
      controller: _controller,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isLastItem = index == messages.length - 1;

        // Marquer comme lu si nécessaire
        if (authProvider.loginUserData.id != message.sendBy &&
            message.message_state != MessageState.LU.name) {
          message.message_state = MessageState.LU.name;
          firestore.collection('Messages').doc(message.id).update(message.toJson());
        }

        return _buildMessageBubble(message, isLastItem);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(width, height),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: getMessageData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingMessages();
                } else if (snapshot.hasError) {
                  printVm('Erreur : ${snapshot.error.toString()}');
                  return Center(
                    child: Text(
                        "Erreur de chargement",
                        style: TextStyle(color: Colors.white)
                    ),
                  );
                } else if (snapshot.hasData) {
                  return _buildMessageList(snapshot.data!);
                }
                return Center(
                  child: CircularProgressIndicator(color: Colors.green),
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}