import 'dart:convert';
import 'dart:io';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/models/chatmodels/models.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
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

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../userPosts/postWidgets/postUserWidget.dart';

class MyChat extends StatefulWidget {
  final String title;
  final Chat chat;

  MyChat({Key? key, required this.title, required this.chat}) : super(key: key);

  @override
  _MyChatState createState() => _MyChatState();
}

class _MyChatState extends State<MyChat> with WidgetsBindingObserver {
  // Variables d'état
  bool _replying = false;
  Message? _replyingToMessage;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Gestion des fichiers
  File? _image;
  final ImagePicker _picker = ImagePicker();

  // États d'envoi
  bool _isSendingImage = false;
  bool _isSendingAudio = false;
  bool _isRecording = false;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentPlayingMessageId;
  Duration _currentAudioDuration = Duration.zero;
  Duration _currentAudioPosition = Duration.zero;
  bool _isAudioPlaying = false;
  bool _isAudioLoading = false;

  // Enregistrement
  AudioRecorder? _audioRecorder;
  String? _audioPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Providers
  late UserAuthProvider _authProvider;
  late UserProvider _userProvider;

  // Streams et données
  Stream<List<Message>>? _messagesStream;
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _hasNewMessage = false;

  // Pour éviter les reconstructions inutiles
  final _messageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);

    _audioRecorder = AudioRecorder();
    _initializeChat();
    _setupAudioListener();
    _loadMessages();

    // Scroll vers le bas après initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  void _initializeChat() {
    if (widget.chat.senderId != _authProvider.loginUserData.id!) {
      widget.chat.your_msg_not_read = 0;
    } else {
      widget.chat.my_msg_not_read = 0;
    }
    _firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
  }

  void _loadMessages() {
    _messagesStream = _firestore
        .collection('Messages')
        .where('chat_id', isEqualTo: widget.chat.docId!)
        .where('is_valide', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList();
    });

    setState(() {
      _isLoading = false;
    });
  }

  void _setupAudioListener() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _currentAudioDuration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentAudioPosition = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _currentAudioPosition = Duration.zero;
          _currentPlayingMessageId = null;
        });
      }
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _audioRecorder?.dispose();
    _recordingTimer?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Méthodes utilitaires
  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) return "À l'instant";
        return "il y a ${difference.inMinutes} min";
      }
      return "il y a ${difference.inHours} h";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} j";
    }
    return DateFormat('dd/MM/yy').format(dateTime);
  }

  bool _isImageUrl(String url) {
    return url.startsWith('http') &&
        (url.contains('firebasestorage.googleapis.com') ||
            url.contains('.jpg') ||
            url.contains('.jpeg') ||
            url.contains('.png') ||
            url.contains('.gif'));
  }

  // Gestion des images
  Future<void> _getImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de la sélection de l'image");
    }
  }

  // Widget Audio compact
  Widget _buildCompactAudioPlayer(Message message, bool isMe) {
    final isCurrentPlaying = _currentPlayingMessageId == message.id;
    final duration = isCurrentPlaying ? _currentAudioDuration : Duration(seconds: 0);
    final position = isCurrentPlaying ? _currentAudioPosition : Duration(seconds: 0);
    final isPlaying = isCurrentPlaying && _isAudioPlaying;
    final isLoading = isCurrentPlaying && _isAudioLoading;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        constraints: BoxConstraints(maxWidth: 180),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[800] : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _toggleAudio(message),
              child: Container(
                padding: EdgeInsets.all(4),
                child: isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isMe ? Colors.white : Colors.black,
                  ),
                )
                    : Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: isMe ? Colors.white : Colors.black,
                  size: 16,
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Slider(
                    value: position.inSeconds.toDouble(),
                    min: 0,
                    max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
                    onChanged: isCurrentPlaying ? (value) {
                      _seekAudio(value);
                    } : null,
                    activeColor: isMe ? Colors.white : Colors.green,
                    inactiveColor: isMe ? Colors.white54 : Colors.grey,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Text(
              _formatTime(position),
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAudio(Message message) async {
    final messageId = message.id!;

    try {
      if (_currentPlayingMessageId != messageId) {
        if (_currentPlayingMessageId != null) {
          await _audioPlayer.stop();
        }

        setState(() {
          _currentPlayingMessageId = messageId;
          _isAudioLoading = true;
        });

        await _audioPlayer.play(UrlSource(message.message));
        setState(() {
          _isAudioPlaying = true;
          _isAudioLoading = false;
        });
      } else {
        if (_isAudioPlaying) {
          await _audioPlayer.pause();
          setState(() {
            _isAudioPlaying = false;
          });
        } else {
          setState(() {
            _isAudioLoading = true;
          });
          await _audioPlayer.resume();
          setState(() {
            _isAudioPlaying = true;
            _isAudioLoading = false;
          });
        }
      }
    } catch (e) {
      print("Erreur audio: $e");
      _showErrorSnackbar("Erreur lors de la lecture audio");
      setState(() {
        _isAudioLoading = false;
      });
    }
  }

  void _seekAudio(double value) {
    _audioPlayer.seek(Duration(seconds: value.toInt()));
  }

  // Enregistrement audio
  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });

        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration = timer.tick;
            });
          }
        });

        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder!.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _audioPath = path;
        });
      } else {
        _showErrorSnackbar("Permission microphone refusée");
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'enregistrement");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder?.stop();

      if (!cancel && _audioPath != null) {
        _sendAudioMessage(_audioPath!);
      } else if (_audioPath != null) {
        await File(_audioPath!).delete();
      }

      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
        _audioPath = null;
      });
    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'envoi de l'audio");
      setState(() => _isRecording = false);
    }
  }

  // Envoi des messages
  Future<void> _sendImageMessage() async {
    if (_image == null) return;

    setState(() => _isSendingImage = true);

    try {
      Reference storageReference = FirebaseStorage.instance.ref().child(
          'chat_images/${Path.basename(_image!.path)}_${DateTime.now().millisecondsSinceEpoch}'
      );

      UploadTask uploadTask = storageReference.putFile(_image!);
      TaskSnapshot snapshot = await uploadTask;
      String fileURL = await snapshot.ref.getDownloadURL();

      final imageText = _textController.text.trim();

      ReplyMessage reply = ReplyMessage(
        message: _replyingToMessage != null ? _getReplyMessageText(_replyingToMessage!) : '',
        messageType: _replyingToMessage?.messageType ?? '',
        messageId: _replyingToMessage?.id ?? '',
      );

      Message msg = Message(
        id: '',
        createdAt: DateTime.now(),
        message: fileURL,
        sendBy: _authProvider.loginUserData.id!,
        replyMessage: reply,
        messageType: MessageType.image.name,
        chat_id: widget.chat.docId!,
        create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
        message_state: MessageState.NONLU.name,
        receiverBy: widget.chat.senderId == _authProvider.loginUserData.id!
            ? widget.chat.receiverId!
            : widget.chat.senderId!,
        is_valide: true,
        imageText: imageText.isNotEmpty ? imageText : null,
      );

      _updateChatCounters("📷 Image");

      String msgid = _firestore.collection('Messages').doc().id;
      msg.id = msgid;

      await _firestore.collection('Messages').doc(msgid).set(msg.toJson());
      await _sendNotification("📷 Image");
      await _resetAfterMessage();

    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'envoi de l'image");
    } finally {
      if (mounted) {
        setState(() {
          _isSendingImage = false;
          _image = null;
        });
      }
    }
  }

  String _getReplyMessageText(Message message) {
    switch (message.messageType) {
      case 'text':
        return message.message;
      case 'image':
        return '📷 Image';
      case 'voice':
        return '🎤 Message audio';
      default:
        return message.message;
    }
  }

  Future<void> _sendAudioMessage(String audioPath) async {
    setState(() => _isSendingAudio = true);

    try {
      Reference storageReference = FirebaseStorage.instance.ref().child(
          'chat_audio/audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
      );

      UploadTask uploadTask = storageReference.putFile(File(audioPath));
      TaskSnapshot snapshot = await uploadTask;
      String fileURL = await snapshot.ref.getDownloadURL();

      ReplyMessage reply = ReplyMessage(
        message: _replyingToMessage != null ? _getReplyMessageText(_replyingToMessage!) : '',
        messageType: _replyingToMessage?.messageType ?? '',
        messageId: _replyingToMessage?.id ?? '',
      );

      Message msg = Message(
        id: '',
        createdAt: DateTime.now(),
        message: fileURL,
        sendBy: _authProvider.loginUserData.id!,
        replyMessage: reply,
        messageType: MessageType.voice.name,
        chat_id: widget.chat.docId!,
        create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
        message_state: MessageState.NONLU.name,
        receiverBy: widget.chat.senderId == _authProvider.loginUserData.id!
            ? widget.chat.receiverId!
            : widget.chat.senderId!,
        is_valide: true,
      );

      _updateChatCounters("🎤 Message audio");

      String msgid = _firestore.collection('Messages').doc().id;
      msg.id = msgid;

      await _firestore.collection('Messages').doc(msgid).set(msg.toJson());
      await _sendNotification("🎤 Message audio");
      await _resetAfterMessage();

    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'envoi de l'audio");
    } finally {
      if (mounted) {
        setState(() => _isSendingAudio = false);
      }
    }
  }

  Future<void> _sendTextMessage() async {
    final messageText = _textController.text.trim();
    if (messageText.isEmpty) return;

    try {
      ReplyMessage reply = ReplyMessage(
        message: _replyingToMessage != null ? _getReplyMessageText(_replyingToMessage!) : '',
        messageType: _replyingToMessage?.messageType ?? '',
        messageId: _replyingToMessage?.id ?? '',
      );

      Message msg = Message(
        id: '',
        createdAt: DateTime.now(),
        message: messageText,
        sendBy: _authProvider.loginUserData.id!,
        replyMessage: reply,
        messageType: MessageType.text.name,
        chat_id: widget.chat.docId!,
        create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
        message_state: MessageState.NONLU.name,
        receiverBy: widget.chat.senderId == _authProvider.loginUserData.id!
            ? widget.chat.receiverId!
            : widget.chat.senderId!,
        is_valide: true,
      );

      _updateChatCounters(messageText);
      _textController.clear();

      String msgid = _firestore.collection('Messages').doc().id;
      msg.id = msgid;

      await _firestore.collection('Messages').doc(msgid).set(msg.toJson());
      await _sendNotification(messageText);
      await _resetAfterMessage();

    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'envoi du message");
    }
  }

  void _sendMessage() {
    if (_isSendingImage || _isSendingAudio) return;

    if (_image != null) {
      _sendImageMessage();
    } else if (_isRecording) {
      _stopRecording();
    } else if (_textController.text.trim().isNotEmpty) {
      _sendTextMessage();
    }
  }

  void _updateChatCounters(String lastMessage) {
    widget.chat.lastMessage = lastMessage;
    widget.chat.updatedAt = DateTime.now().millisecondsSinceEpoch;

    if (widget.chat.senderId == _authProvider.loginUserData.id!) {
      widget.chat.your_msg_not_read = (widget.chat.your_msg_not_read ?? 0) + 1;
    } else {
      widget.chat.my_msg_not_read = (widget.chat.my_msg_not_read ?? 0) + 1;
    }
  }

  Future<void> _sendNotification(String messageContent) async {
    try {
      final receiverId = widget.chat.senderId == _authProvider.loginUserData.id!
          ? widget.chat.receiverId!
          : widget.chat.senderId!;

      final users = await _authProvider.getUserById(receiverId);

      if (users.isNotEmpty && users.first.oneIgnalUserid != null &&
          users.first.oneIgnalUserid!.length > 5) {
        await _authProvider.sendNotification(
          userIds: [users.first.oneIgnalUserid!],
          smallImage: _authProvider.loginUserData.imageUrl!,
          send_user_id: _authProvider.loginUserData.id!,
          recever_user_id: receiverId,
          message: "🗨️ @${_authProvider.loginUserData.pseudo!} vous a envoyé un message",
          type_notif: NotificationType.MESSAGE.name,
          post_id: "",
          post_type: "",
          chat_id: widget.chat.id!,
        );
      }
    } catch (e) {
      print("Erreur notification: $e");
    }
  }

  Future<void> _resetAfterMessage() async {
    if (widget.chat.senderId == _authProvider.loginUserData.id!) {
      widget.chat.send_sending = IsSendMessage.NOTSENDING.name;
    } else {
      widget.chat.receiver_sending = IsSendMessage.NOTSENDING.name;
    }

    await _firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());

    // Scroll vers le bas après l'envoi
    _scrollToBottom();

    if (mounted) {
      setState(() {
        _replying = false;
        _replyingToMessage = null;
        _textController.clear();
      });
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message, textAlign: TextAlign.center),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.all(20),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    ),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widgets d'affichage des messages
  Widget _buildMessageBubble(Message message, bool isLastItem, List<Message> messages) {
    final isMe = message.sendBy == _authProvider.loginUserData.id!;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          if (message.replyMessage.message.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _buildReplyIndicator(message),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe)
                Container(
                  width: 28,
                  height: 28,
                  margin: EdgeInsets.only(right: 8, bottom: 16),
                  child: _buildUserAvatar(message.sendBy),
                ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(message, isMe),
                      _buildMessageStatus(message, isMe),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLastItem ? 80 : 4),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(Message message) {
    final reply = message.replyMessage;

    Widget replyContent;

    if (reply.messageType == MessageType.image.name && _isImageUrl(reply.message)) {
      replyContent = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          image: DecorationImage(
            image: CachedNetworkImageProvider(reply.message),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (reply.messageType == MessageType.voice.name) {
      replyContent = Icon(Icons.audiotrack, size: 16, color: Colors.green);
    } else {
      replyContent = Text(
        reply.message.length > 25
            ? '${reply.message.substring(0, 25)}...'
            : reply.message,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white70,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey[800]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[600]!),
      ),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
      child: Row(
        children: [
          Icon(Icons.reply, color: Colors.green, size: 14),
          SizedBox(width: 6),
          Expanded(child: replyContent),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String userId) {
    return FutureBuilder<UserData>(
      future: _authProvider.getUserById(userId).then((users) => users.first),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final user = snapshot.data!;
          return CircleAvatar(
            backgroundImage: NetworkImage(user.imageUrl!),
          );
        }
        return CircleAvatar(
          backgroundColor: Colors.grey,
        );
      },
    );
  }

  Widget _buildMessageContent(Message message, bool isMe) {
    switch (message.messageType) {
      case 'text':
        return _buildTextMessage(message, isMe);
      case 'image':
        return _buildImageMessage(message, isMe);
      case 'voice':
        return _buildCompactAudioPlayer(message, isMe);
      default:
        return _buildTextMessage(message, isMe);
    }
  }

  Widget _buildTextMessage(Message message, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: BubbleSpecialOne(
        text: message.message,
        isSender: isMe,
        color: isMe ? Colors.green[800]! : Colors.grey[300]!,
        textStyle: TextStyle(
          fontSize: 14,
          color: isMe ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildImageMessage(Message message, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      onTap: () => _showImageFullScreen(message.message),
      child: Container(
        constraints: BoxConstraints(maxWidth: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 150,
                width: 200,
                child: CachedNetworkImage(
                  imageUrl: message.message,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: Center(child: CircularProgressIndicator(color: Colors.green)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (message.imageText != null && message.imageText!.isNotEmpty)
              Container(
                width: 200,
                padding: EdgeInsets.all(6),
                child: Text(
                  message.imageText!,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatus(Message message, bool isMe) {
    return Padding(
      padding: EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            MaterialCommunityIcons.check_all,
            size: 12,
            color: message.message_state == MessageState.LU.name
                ? Colors.green
                : Colors.grey,
          ),
          SizedBox(width: 4),
          Text(
            _formatDateTime(message.createdAt),
            style: TextStyle(fontSize: 9, color: Colors.grey),
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
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.sendBy == _authProvider.loginUserData.id!)
                  ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Supprimer', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(message);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.reply, color: Colors.blue),
                  title: Text('Répondre', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _replying = true;
                      _replyingToMessage = message;
                    });
                    _focusNode.requestFocus();
                  },
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      message.is_valide = false;
      bool success = await _userProvider.updateMessage(message);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? Colors.green : Colors.red,
          content: Text(
            success ? 'Message supprimé' : 'Erreur de suppression',
            textAlign: TextAlign.center,
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showErrorSnackbar("Erreur lors de la suppression");
    }
  }

  // Barre d'envoi de message
  Widget _buildMessageInput() {
    return Container(
      color: Colors.grey[900],
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        children: [
          if (_replying) _buildReplyIndicatorBar(),
          if (_image != null) _buildImagePreview(),
          Row(
            children: [
              _buildMediaButtons(),
              Expanded(child: _buildMessageTextField()),
              _buildSendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicatorBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: Colors.green, size: 16),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Répondre à:',
                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 1),
                Text(
                  _getReplyMessageText(_replyingToMessage!).length > 35
                      ? '${_getReplyMessageText(_replyingToMessage!).substring(0, 35)}...'
                      : _getReplyMessageText(_replyingToMessage!),
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16),
            color: Colors.grey,
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _replying = false;
                _replyingToMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(_image!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (_isSendingImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black54,
                ),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.green),
                ),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 14),
              ),
              onPressed: () {
                setState(() {
                  _image = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButtons() {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.camera_alt, color: Colors.green, size: 22),
          onPressed: _getImage,
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: Icon(
            _isRecording ? Icons.stop : Icons.mic,
            color: _isRecording ? Colors.red : Colors.green,
            size: 22,
          ),
          onPressed: () {
            if (_isRecording) {
              _stopRecording();
            } else {
              _startRecording();
            }
          },
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildMessageTextField() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() {
                   canSend = _textController.text.trim().isNotEmpty || _image != null || _isRecording;

                });

              },
              controller: _textController,
              focusNode: _focusNode,
              maxLines: null,
              style: TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _isRecording ? "Enregistrement... ($_recordingDuration s)" : "Message...",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
  bool canSend =false;
  Widget _buildSendButton() {
    if (_isSendingImage || _isSendingAudio) {
      return Container(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2),
        ),
      );
    }

     canSend = _textController.text.trim().isNotEmpty || _image != null || _isRecording;

    return IconButton(
      icon: Icon(
        Icons.send,
        color: canSend ? Colors.green : Colors.grey,
        size: 20,
      ),
      onPressed: canSend ? _sendMessage : null,
      padding: EdgeInsets.zero,
    );
  }

  // AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.green),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          _buildAppBarUserAvatar(),
          SizedBox(width: 8),
          _buildAppBarUserInfo(),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.arrow_downward, color: Colors.green, size: 20),
          onPressed: _scrollToBottom,
        ),
      ],
    );
  }

  Widget _buildAppBarUserAvatar() {
    return StreamBuilder<UserData>(
      stream: _userProvider.getStreamUser(widget.chat.receiver!.id!),
      builder: (context, snapshot) {
        final user = snapshot.hasData ? snapshot.data! : widget.chat.receiver!;

        return GestureDetector(
          onTap: () => showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context),
          child: Stack(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(user.imageUrl!),
                radius: 18,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: user.state == UserState.ONLINE.name ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUserDetails(UserData user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: DetailsOtherUser(
            user: user,
            w: MediaQuery.of(context).size.width * 0.9,
            h: MediaQuery.of(context).size.height * 0.7,
          ),
        );
      },
    );
  }

  Widget _buildAppBarUserInfo() {
    return StreamBuilder<Chat>(
      stream: _userProvider.getStreamChat(widget.chat.id!),
      builder: (context, snapshot) {
        final chat = snapshot.hasData ? snapshot.data! : widget.chat;
        final isTyping = _isUserTyping(chat);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "@${widget.chat.receiver!.pseudo}",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
                            isTyping ? "en train d'écrire..." : "${formatNumber(widget.chat.receiver!.userAbonnesIds!.length!)} abonné(s)",

              style: TextStyle(
                fontSize: 11,
                color: isTyping ? Colors.green : Colors.grey[400],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isUserTyping(Chat chat) {
    if (_authProvider.loginUserData.id == chat.senderId) {
      return chat.receiver_sending == IsSendMessage.SENDING.name;
    } else if (_authProvider.loginUserData.id == chat.receiverId) {
      return chat.send_sending == IsSendMessage.SENDING.name;
    }
    return false;
  }

  Widget _buildMessageList(List<Message> messages) {
    return ListView.builder(
      key: _messageKey,
      controller: _scrollController,
      itemCount: messages.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final message = messages[index];
        final isLastItem = index == messages.length - 1;

        // Marquer comme lu si nécessaire
        if (_authProvider.loginUserData.id != message.sendBy &&
            message.message_state != MessageState.LU.name) {
          message.message_state = MessageState.LU.name;
          _firestore.collection('Messages').doc(message.id).update(message.toJson());
        }

        return _buildMessageBubble(message, isLastItem, messages);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.green))
                : StreamBuilder<List<Message>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Erreur de chargement",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      "Aucun message",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                } else if (snapshot.hasData) {
                  final messages = snapshot.data!;

                  // Scroll vers le bas si nouveaux messages
                  if (messages.length > _messages.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  }

                  _messages = messages;

                  return _buildMessageList(messages);
                }
                return Center(child: CircularProgressIndicator(color: Colors.green));
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}

// class MyChat extends StatefulWidget {
//   final String title;
//   final Chat chat;
//
//   MyChat({Key? key, required this.title, required this.chat}) : super(key: key);
//
//   @override
//   _MyChatState createState() => _MyChatState();
// }
//
// class _MyChatState extends State<MyChat> with WidgetsBindingObserver, TickerProviderStateMixin {
//   // Variables d'état
//   late bool replying = false;
//   late String replyingTo = '';
//   late String replyingToMessageId = '';
//   late String replyingToMessageType = '';
//   late TextEditingController _textController = TextEditingController();
//   Map<String, AudioPlayer> audioPlayers = {};
//   Map<String, Duration> audioDurations = {};
//   Map<String, Duration> audioPositions = {};
//   Map<String, bool> audioPlayingStates = {};
//   Map<String, bool> audioLoadingStates = {};
//   Map<String, bool> audioPauseStates = {};
//
//   bool fileDownloading = false;
//   bool sendMessageTap = false;
//   ScrollController _controller = ScrollController();
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   File? _image;
//   final _picker = ImagePicker();
//   FocusNode _focusNode = FocusNode();
//   bool _isRecording = false;
//   AudioRecorder? _audioRecorder;
//   String? _audioPath;
//   Timer? _recordingTimer;
//   int _recordingDuration = 0;
//   final Set<String> _highlightedMessages = {};
//
//   // Providers
//   late UserAuthProvider authProvider;
//   late UserProvider userProvider;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     userProvider = Provider.of<UserProvider>(context, listen: false);
//
//     // Initialiser le contrôleur
//     _controller = ScrollController();
//
//     // Initialiser l'enregistreur audio
//     _audioRecorder = AudioRecorder();
//
//     // Initialiser le chat
//     _initializeChat();
//   }
//
//   void _initializeChat() {
//     if (widget.chat.senderId != authProvider.loginUserData.id!) {
//       widget.chat.your_msg_not_read = 0;
//     } else {
//       widget.chat.my_msg_not_read = 0;
//     }
//
//     firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _updateChatStatusOnDispose();
//
//     // Arrêter tous les lecteurs audio
//     audioPlayers.forEach((key, player) {
//       player.dispose();
//     });
//
//     // Arrêter l'enregistrement s'il est en cours
//     if (_isRecording) {
//       _stopRecording(cancel: true);
//     }
//
//     // Annuler le timer d'enregistrement
//     _recordingTimer?.cancel();
//
//     super.dispose();
//   }
//
//   void _updateChatStatusOnDispose() {
//     if (widget.chat.senderId == authProvider.loginUserData.id!) {
//       widget.chat.send_sending = IsSendMessage.NOTSENDING.name;
//     } else {
//       widget.chat.receiver_sending = IsSendMessage.NOTSENDING.name;
//     }
//
//     firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
//   }
//
//   // Méthodes utilitaires
//   String formatNumber(int number) {
//     if (number < 1000) return number.toString();
//     if (number < 1000000) return "${(number / 1000).toStringAsFixed(1)} k";
//     if (number < 1000000000) return "${(number / 1000000).toStringAsFixed(1)} m";
//     return "${(number / 1000000000).toStringAsFixed(1)} b";
//   }
//
//   String formaterDateTime(DateTime dateTime) {
//     final now = DateTime.now();
//     final difference = now.difference(dateTime);
//
//     if (difference.inDays < 1) {
//       if (difference.inHours < 1) {
//         if (difference.inMinutes < 1) return "il y a quelques secondes";
//         return "il y a ${difference.inMinutes} minutes";
//       }
//       return "il y a ${difference.inHours} heures";
//     } else if (difference.inDays < 7) {
//       return "${difference.inDays} jours plus tôt";
//     }
//     return DateFormat('dd MMMM yyyy').format(dateTime);
//   }
//
//   // Stream des messages
//   Stream<List<Message>> getMessageData() async* {
//     var messagesStream = FirebaseFirestore.instance
//         .collection('Messages')
//         .where('chat_id', isEqualTo: widget.chat.docId!)
//         .where('is_valide', isEqualTo: true)
//         .orderBy('createdAt', descending: false)
//         .snapshots();
//
//     await for (var snapshot in messagesStream) {
//       List<Message> messages = snapshot.docs
//           .map((doc) => Message.fromJson(doc.data()))
//           .toList();
//
//       userProvider.chat.messages = messages;
//
//       // Scroll vers le bas après avoir reçu les messages
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (_controller.hasClients) {
//           _controller.jumpTo(_controller.position.maxScrollExtent);
//         }
//       });
//
//       yield messages;
//     }
//   }
//
//   // Gestion des images
//   Future getImage() async {
//     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//       });
//     }
//   }
//
//   String? getStringImage(File? file) {
//     if (file == null) return null;
//     return base64Encode(file.readAsBytesSync());
//   }
//
//   // Affichage des détails utilisateur
//   void _showUserDetailsModalDialog(UserData user, double w, double h) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           child: DetailsOtherUser(user: user, w: w, h: h),
//         );
//       },
//     );
//   }
//
//   // Gestion audio
//   void _changeSeek(String messageId, double value) {
//     setState(() {
//       audioPlayers[messageId]?.seek(Duration(seconds: value.toInt()));
//     });
//   }
//
//   void _playAudio(String messageId, String url) async {
//     // Initialiser le lecteur audio pour ce message s'il n'existe pas
//     if (!audioPlayers.containsKey(messageId)) {
//       audioPlayers[messageId] = AudioPlayer();
//       audioPlayingStates[messageId] = false;
//       audioLoadingStates[messageId] = false;
//       audioPauseStates[messageId] = false;
//       audioDurations[messageId] = Duration();
//       audioPositions[messageId] = Duration();
//
//       // Écouter les changements de durée
//       audioPlayers[messageId]!.onDurationChanged.listen((Duration d) {
//         setState(() {
//           audioDurations[messageId] = d;
//           audioLoadingStates[messageId] = false;
//         });
//       });
//
//       // Écouter les changements de position
//       audioPlayers[messageId]!.onPositionChanged.listen((Duration p) {
//         setState(() {
//           audioPositions[messageId] = p;
//         });
//       });
//
//       // Écouter la fin de la lecture
//       audioPlayers[messageId]!.onPlayerComplete.listen((event) {
//         setState(() {
//           audioPlayingStates[messageId] = false;
//           audioPauseStates[messageId] = false;
//           audioDurations[messageId] = Duration();
//           audioPositions[messageId] = Duration();
//         });
//       });
//     }
//
//     final player = audioPlayers[messageId]!;
//     final isPause = audioPauseStates[messageId] ?? false;
//     final isPlaying = audioPlayingStates[messageId] ?? false;
//
//     if (isPause) {
//       await player.resume();
//       setState(() {
//         audioPlayingStates[messageId] = true;
//         audioPauseStates[messageId] = false;
//       });
//     } else if (isPlaying) {
//       await player.pause();
//       setState(() {
//         audioPlayingStates[messageId] = false;
//         audioPauseStates[messageId] = true;
//       });
//     } else {
//       setState(() => audioLoadingStates[messageId] = true);
//       await player.play(UrlSource(url));
//       setState(() {
//         audioPlayingStates[messageId] = true;
//         audioLoadingStates[messageId] = false;
//       });
//     }
//   }
//
//   // Enregistrement audio
//   Future<void> _startRecording() async {
//     try {
//       // Demander la permission
//       if (await Permission.microphone.request().isGranted) {
//         setState(() {
//           _isRecording = true;
//           _recordingDuration = 0;
//         });
//
//         // Démarrer le timer pour la durée d'enregistrement
//         _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
//           setState(() {
//             _recordingDuration = timer.tick;
//           });
//         });
//
//         // Chemin pour sauvegarder l'audio
//         final directory = await getTemporaryDirectory();
//         final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
//
//         // Configurer et démarrer l'enregistrement
//         await _audioRecorder!.start(
//           const RecordConfig(encoder: AudioEncoder.aacLc),
//           path: path,
//         );
//
//         setState(() {
//           _audioPath = path;
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Permission microphone refusée'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       print("Erreur lors de l'enregistrement: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Erreur lors du démarrage de l\'enregistrement'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<void> _stopRecording({bool cancel = false}) async {
//     try {
//       _recordingTimer?.cancel();
//
//       if (_audioRecorder != null) {
//         await _audioRecorder!.stop();
//       }
//
//       if (cancel) {
//         // Supprimer le fichier temporaire si annulation
//         if (_audioPath != null && File(_audioPath!).existsSync()) {
//           await File(_audioPath!).delete();
//         }
//       } else if (_audioPath != null) {
//         // Envoyer l'audio enregistré
//         await _sendAudioMessage(_audioPath!);
//       }
//
//       setState(() {
//         _isRecording = false;
//         _recordingDuration = 0;
//         _audioPath = null;
//       });
//     } catch (e) {
//       print("Erreur lors de l'arrêt de l'enregistrement: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Erreur lors de l\'arrêt de l\'enregistrement'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   // Envoi de message
//   Future<void> _sendMessage() async {
//     if (sendMessageTap) return;
//
//     setState(() => sendMessageTap = true);
//
//     try {
//       if (_image != null) {
//         await _sendImageMessage();
//       } else if (_textController.text.isNotEmpty) {
//         await _sendTextMessage();
//       }
//     } catch (error) {
//       print("Erreur d'envoi: $error");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text("Erreur lors de l'envoi du message",
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.white)
//           ),
//         ),
//       );
//     } finally {
//       setState(() => sendMessageTap = false);
//     }
//   }
//
//   Future<void> _sendImageMessage() async {
//     setState(() => fileDownloading = true);
//
//     try {
//       Reference storageReference = FirebaseStorage.instance.ref().child(
//           'chat_images/${Path.basename(_image!.path)}_${DateTime.now().millisecondsSinceEpoch}'
//       );
//
//       UploadTask uploadTask = storageReference.putFile(_image!);
//       await uploadTask.whenComplete(() async {
//         String fileURL = await storageReference.getDownloadURL();
//
//         ReplyMessage reply = ReplyMessage(
//           message: replyingTo,
//           messageType: replyingToMessageType.isEmpty ? MessageType.text.name : replyingToMessageType,
//           messageId: replyingToMessageId,
//         );
//
//         Message msg = Message(
//           id: '',
//           createdAt: DateTime.now(),
//           message: fileURL,
//           sendBy: authProvider.loginUserData.id!,
//           replyMessage: reply,
//           messageType: MessageType.image.name,
//           chat_id: widget.chat.docId!,
//           create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
//           message_state: MessageState.NONLU.name,
//           receiverBy: widget.chat.senderId == authProvider.loginUserData.id!
//               ? widget.chat.receiverId!
//               : widget.chat.senderId!,
//           is_valide: true,
//           imageText: _textController.text.isNotEmpty ? _textController.text : null,
//         );
//
//         _updateChatCounters("📷 Image");
//
//         String msgid = firestore.collection('Messages').doc().id;
//         msg.id = msgid;
//
//         await firestore.collection('Messages').doc(msgid).set(msg.toJson());
//         await _sendNotification("📷 Image");
//         await _resetChatAfterMessage();
//       });
//     } catch (e) {
//       print("Erreur lors de l'envoi de l'image: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text("Erreur lors de l'envoi de l'image",
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.white)
//           ),
//         ),
//       );
//     } finally {
//       setState(() {
//         fileDownloading = false;
//         _image = null;
//       });
//     }
//   }
//
//   Future<void> _sendTextMessage() async {
//     ReplyMessage reply = ReplyMessage(
//       message: replyingTo,
//       messageType: replyingToMessageType.isEmpty ? MessageType.text.name : replyingToMessageType,
//       messageId: replyingToMessageId,
//     );
//
//     Message msg = Message(
//       id: '',
//       createdAt: DateTime.now(),
//       message: _textController.text,
//       sendBy: authProvider.loginUserData.id!,
//       replyMessage: reply,
//       messageType: MessageType.text.name,
//       chat_id: widget.chat.docId!,
//       create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
//       message_state: MessageState.NONLU.name,
//       receiverBy: widget.chat.senderId == authProvider.loginUserData.id!
//           ? widget.chat.receiverId!
//           : widget.chat.senderId!,
//       is_valide: true,
//     );
//
//     _updateChatCounters(_textController.text);
//     _textController.clear();
//
//     String msgid = firestore.collection('Messages').doc().id;
//     msg.id = msgid;
//
//     await firestore.collection('Messages').doc(msgid).set(msg.toJson());
//     await _sendNotification(_textController.text);
//     await _resetChatAfterMessage();
//   }
//
//   Future<void> _sendAudioMessage(String audioPath) async {
//     setState(() => fileDownloading = true);
//
//     try {
//       // Uploader l'audio vers Firebase Storage
//       Reference storageReference = FirebaseStorage.instance.ref().child(
//           'chat_audio/audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
//       );
//
//       UploadTask uploadTask = storageReference.putFile(File(audioPath));
//       await uploadTask.whenComplete(() async {
//         String fileURL = await storageReference.getDownloadURL();
//
//         ReplyMessage reply = ReplyMessage(
//           message: replyingTo,
//           messageType: replyingToMessageType.isEmpty ? MessageType.text.name : replyingToMessageType,
//           messageId: replyingToMessageId,
//         );
//
//         Message msg = Message(
//           id: '',
//           createdAt: DateTime.now(),
//           message: fileURL,
//           sendBy: authProvider.loginUserData.id!,
//           replyMessage: reply,
//           messageType: MessageType.voice.name,
//           chat_id: widget.chat.docId!,
//           create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
//           message_state: MessageState.NONLU.name,
//           receiverBy: widget.chat.senderId == authProvider.loginUserData.id!
//               ? widget.chat.receiverId!
//               : widget.chat.senderId!,
//           is_valide: true,
//         );
//
//         _updateChatCounters("🎤 Message audio");
//
//         String msgid = firestore.collection('Messages').doc().id;
//         msg.id = msgid;
//
//         await firestore.collection('Messages').doc(msgid).set(msg.toJson());
//         await _sendNotification("🎤 Message audio");
//         await _resetChatAfterMessage();
//       });
//     } catch (e) {
//       print("Erreur lors de l'envoi de l'audio: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text("Erreur lors de l'envoi de l'audio",
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.white)
//           ),
//         ),
//       );
//     } finally {
//       setState(() {
//         fileDownloading = false;
//         _isRecording = false;
//       });
//     }
//   }
//
//   void _updateChatCounters(String lastMessage) {
//     widget.chat.lastMessage = lastMessage;
//     widget.chat.updatedAt = DateTime.now().millisecondsSinceEpoch;
//
//     if (widget.chat.senderId == authProvider.loginUserData.id!) {
//       widget.chat.your_msg_not_read = (widget.chat.your_msg_not_read ?? 0) + 1;
//     } else {
//       widget.chat.my_msg_not_read = (widget.chat.my_msg_not_read ?? 0) + 1;
//     }
//   }
//
//   Future<void> _sendNotification(String messageContent) async {
//     final receiverId = widget.chat.senderId == authProvider.loginUserData.id!
//         ? widget.chat.receiverId!
//         : widget.chat.senderId!;
//
//     final users = await authProvider.getUserById(receiverId);
//
//     if (users.isNotEmpty && users.first.oneIgnalUserid != null &&
//         users.first.oneIgnalUserid!.length > 5) {
//       await authProvider.sendNotification(
//         userIds: [users.first.oneIgnalUserid!],
//         smallImage: authProvider.loginUserData.imageUrl!,
//         send_user_id: authProvider.loginUserData.id!,
//         recever_user_id: receiverId,
//         message: "🗨️ @${authProvider.loginUserData.pseudo!} vous a envoyé un message",
//         type_notif: NotificationType.MESSAGE.name,
//         post_id: "",
//         post_type: "",
//         chat_id: widget.chat.id!,
//       );
//     }
//   }
//
//   Future<void> _resetChatAfterMessage() async {
//     // Réinitialiser l'état d'écriture
//     if (widget.chat.senderId == authProvider.loginUserData.id!) {
//       widget.chat.send_sending = IsSendMessage.NOTSENDING.name;
//     } else {
//       widget.chat.receiver_sending = IsSendMessage.NOTSENDING.name;
//     }
//
//     await firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
//
//     // Scroll vers le bas
//     if (_controller.hasClients) {
//       _controller.animateTo(
//         _controller.position.maxScrollExtent,
//         duration: Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     }
//
//     // Réinitialiser les états
//     setState(() {
//       replyingTo = "";
//       replying = false;
//       replyingToMessageId = "";
//       replyingToMessageType = "";
//       _textController.clear();
//     });
//   }
//
//   // Widget pour l'image URL
//   Widget _imageUrl(String url, {double? width, double? height}) {
//     return Container(
//       constraints: BoxConstraints(
//         minHeight: height ?? 100,
//         minWidth: width ?? 100,
//         maxWidth: width ?? 200,
//         maxHeight: height ?? 200,
//       ),
//       child: CachedNetworkImage(
//         imageUrl: url,
//         progressIndicatorBuilder: (context, url, downloadProgress) =>
//             Container(
//               padding: EdgeInsets.all(20),
//               child: CircularProgressIndicator(value: downloadProgress.progress, color: Colors.green),
//             ),
//         errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
//         fit: BoxFit.cover,
//       ),
//     );
//   }
//
//   // Méthode pour afficher l'image en plein écran
//   void _showImageFullScreen(String imageUrl) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           insetPadding: EdgeInsets.all(20),
//           child: Stack(
//             children: [
//               // Image en plein écran
//               Container(
//                 width: double.infinity,
//                 height: double.infinity,
//                 child: InteractiveViewer(
//                   panEnabled: true,
//                   minScale: 0.5,
//                   maxScale: 3.0,
//                   child: CachedNetworkImage(
//                     imageUrl: imageUrl,
//                     fit: BoxFit.contain,
//                     placeholder: (context, url) => Center(
//                       child: CircularProgressIndicator(color: Colors.green),
//                     ),
//                     errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
//                   ),
//                 ),
//               ),
//
//               // Bouton de fermeture
//               Positioned(
//                 top: 40,
//                 right: 20,
//                 child: GestureDetector(
//                   onTap: () => Navigator.of(context).pop(),
//                   child: Container(
//                     padding: EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.black54,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(Icons.close, color: Colors.white, size: 24),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   // Navigation vers les messages originaux
//   void _scrollToRepliedMessage(String messageId, List<Message> messages) {
//     if (messageId.isEmpty) return;
//
//     int targetIndex = -1;
//     for (int i = 0; i < messages.length; i++) {
//       if (messages[i].id == messageId) {
//         targetIndex = i;
//         break;
//       }
//     }
//
//     if (targetIndex != -1 && _controller.hasClients) {
//       // Calculer la position approximative
//       final itemHeight = 120.0;
//       final targetPosition = targetIndex * itemHeight;
//
//       _controller.animateTo(
//         targetPosition.clamp(0.0, _controller.position.maxScrollExtent),
//         duration: Duration(milliseconds: 500),
//         curve: Curves.easeInOut,
//       );
//
//       // Marquer visuellement le message cible
//       _highlightMessage(messageId);
//     }
//   }
//
//   void _highlightMessage(String messageId) {
//     setState(() {
//       _highlightedMessages.add(messageId);
//     });
//
//     Future.delayed(Duration(seconds: 3), () {
//       if (mounted) {
//         setState(() {
//           _highlightedMessages.remove(messageId);
//         });
//       }
//     });
//   }
//
//   // Widget pour les bulles de message
//   Widget _buildMessageBubble(Message message, bool isLastItem, List<Message> messages) {
//     final isMe = message.sendBy == authProvider.loginUserData.id!;
//     final isHighlighted = _highlightedMessages.contains(message.id);
//
//     Widget messageContent;
//
//     switch (message.messageType) {
//       case 'text':
//         messageContent = _buildTextMessage(message, isMe);
//         break;
//       case 'image':
//         messageContent = _buildImageMessage(message, isMe);
//         break;
//       case 'voice':
//         messageContent = _buildVoiceMessage(message, isMe);
//         break;
//       default:
//         messageContent = _buildTextMessage(message, isMe);
//     }
//
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(8),
//         border: isHighlighted
//             ? Border.all(color: Colors.yellow, width: 2)
//             : null,
//         color: isHighlighted
//             ? Colors.yellow.withOpacity(0.1)
//             : Colors.transparent,
//       ),
//       margin: EdgeInsets.symmetric(vertical: 2),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//         children: [
//           if (message.replyMessage.message.isNotEmpty)
//             _buildReplyIndicator(message, messages),
//           messageContent,
//           _buildMessageStatus(message, isMe),
//           SizedBox(height: isLastItem ? 100 : 10),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTextMessage(Message message, bool isMe) {
//     return GestureDetector(
//       onLongPress: () => _showMessageOptions(message),
//       child: BubbleSpecialOne(
//         text: message.message,
//         isSender: isMe,
//         color: isMe ? Colors.green[800]! : Colors.grey[300]!,
//         textStyle: TextStyle(
//           fontSize: 16,
//           color: isMe ? Colors.white : Colors.black,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildImageMessage(Message message, bool isMe) {
//     return GestureDetector(
//       onLongPress: () => _showMessageOptions(message),
//       child: Column(
//         crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//         children: [
//           Text(
//             isMe ? "Vous avez envoyé une image" : "a envoyé une image",
//             style: TextStyle(fontSize: 12, color: Colors.grey),
//           ),
//           SizedBox(height: 4),
//
//           // Conteneur de l'image avec effet de clic
//           Container(
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey.withOpacity(0.3)),
//             ),
//             child: Column(
//               children: [
//                 // Image cliquable
//                 GestureDetector(
//                   onTap: () => _showImageFullScreen(message.message),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(12),
//                       topRight: Radius.circular(12),
//                     ),
//                     child: Container(
//                       constraints: BoxConstraints(
//                         minHeight: 150,
//                         minWidth: 150,
//                         maxWidth: 250,
//                         maxHeight: 250,
//                       ),
//                       child: CachedNetworkImage(
//                         imageUrl: message.message,
//                         progressIndicatorBuilder: (context, url, downloadProgress) =>
//                             Container(
//                               padding: EdgeInsets.all(20),
//                               child: CircularProgressIndicator(
//                                   value: downloadProgress.progress,
//                                   color: Colors.green
//                               ),
//                             ),
//                         errorWidget: (context, url, error) =>
//                             Icon(Icons.error, color: Colors.red),
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   ),
//                 ),
//
//                 // Texte sous l'image (si existant)
//                 if (message.imageText != null && message.imageText!.isNotEmpty)
//                   Container(
//                     width: double.infinity,
//                     padding: EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.grey[850],
//                       borderRadius: BorderRadius.only(
//                         bottomLeft: Radius.circular(12),
//                         bottomRight: Radius.circular(12),
//                       ),
//                     ),
//                     child: Text(
//                       message.imageText!,
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildVoiceMessage(Message message, bool isMe) {
//     final messageId = message.id!;
//     final isPlaying = audioPlayingStates[messageId] ?? false;
//     final isLoading = audioLoadingStates[messageId] ?? false;
//     final isPause = audioPauseStates[messageId] ?? false;
//     final duration = audioDurations[messageId] ?? Duration();
//     final position = audioPositions[messageId] ?? Duration();
//
//     return Column(
//       crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//       children: [
//         Text(
//           isMe ? "Vous avez envoyé un audio" : "a envoyé un audio",
//           style: TextStyle(fontSize: 12, color: Colors.grey),
//         ),
//         SizedBox(height: 4),
//         BubbleNormalAudio(
//           color: isMe ? Colors.green[800]! : Colors.grey[300]!,
//           duration: duration.inSeconds.toDouble(),
//           position: position.inSeconds.toDouble(),
//           isPlaying: isPlaying,
//           isLoading: isLoading,
//           isPause: isPause,
//           onSeekChanged: (value) => _changeSeek(messageId, value),
//           onPlayPauseButtonClick: () => _playAudio(messageId, message.message),
//           isSender: isMe,
//         ),
//       ],
//     );
//   }
//
//   Widget _buildReplyIndicator(Message message, List<Message> messages) {
//     final reply = message.replyMessage;
//
//     return GestureDetector(
//       onTap: () => _scrollToRepliedMessage(reply.messageId, messages),
//       child: Container(
//         margin: EdgeInsets.only(bottom: 8),
//         padding: EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: Colors.yellow[100]!.withOpacity(0.3),
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.yellow[700]!.withOpacity(0.5)),
//         ),
//         child: Row(
//           children: [
//             Icon(Icons.reply, color: Colors.yellow[700], size: 16),
//             SizedBox(width: 8),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Réponse à:',
//                     style: TextStyle(
//                       fontSize: 10,
//                       color: Colors.yellow[700],
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(height: 4),
//                   // Afficher l'image miniature si c'est une image
//                   if (reply.messageType == MessageType.image.name)
//                     Column(
//                       children: [
//                         Container(
//                           width: 40,
//                           height: 40,
//                           child: CachedNetworkImage(
//                             imageUrl: reply.message,
//                             fit: BoxFit.cover,
//                             placeholder: (context, url) =>
//                                 Container(color: Colors.grey[300]),
//                             errorWidget: (context, url, error) =>
//                                 Icon(Icons.error, size: 20),
//                           ),
//                         ),
//                         SizedBox(height: 4),
//                       ],
//                     ),
//                   // Afficher le texte (tronqué si c'est trop long)
//                   Text(
//                     reply.message.length > 50
//                         ? '${reply.message.substring(0, 50)}...'
//                         : reply.message,
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.yellow[700],
//                     ),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMessageStatus(Message message, bool isMe) {
//     return Padding(
//       padding: isMe
//           ? EdgeInsets.only(right: 16.0, bottom: 8, top: 4)
//           : EdgeInsets.only(left: 16.0, bottom: 8, top: 4),
//       child: Row(
//         mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
//         children: [
//           Icon(
//             MaterialCommunityIcons.check_all,
//             size: 16,
//             color: message.message_state == MessageState.LU.name
//                 ? Colors.green
//                 : Colors.grey,
//           ),
//           SizedBox(width: 4),
//           Text(
//             formaterDateTime(message.createdAt),
//             style: TextStyle(fontSize: 10, color: Colors.grey),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showMessageOptions(Message message) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext context) {
//         return Container(
//           height: MediaQuery.of(context).size.height * 0.2,
//           decoration: BoxDecoration(
//             color: Colors.grey[900],
//             borderRadius: BorderRadius.only(
//               topLeft: Radius.circular(15),
//               topRight: Radius.circular(15),
//             ),
//           ),
//           child: Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 if (message.sendBy == authProvider.loginUserData.id!)
//                   ListTile(
//                     leading: Icon(Icons.delete, color: Colors.red),
//                     title: Text('Supprimer', style: TextStyle(color: Colors.white)),
//                     onTap: () async {
//                       Navigator.pop(context);
//                       await _deleteMessage(message);
//                     },
//                   ),
//                 ListTile(
//                   leading: Icon(Icons.reply, color: Colors.blue),
//                   title: Text('Répondre', style: TextStyle(color: Colors.white)),
//                   onTap: () {
//                     Navigator.pop(context);
//                     setState(() {
//                       replying = true;
//                       replyingTo = message.message;
//                       replyingToMessageId = message.id!;
//                       replyingToMessageType = message.messageType;
//                     });
//                     _focusNode.requestFocus();
//                   },
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Future<void> _deleteMessage(Message message) async {
//     message.is_valide = false;
//     bool success = await userProvider.updateMessage(message);
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: success ? Colors.green : Colors.red,
//         content: Text(
//           success ? 'Message supprimé' : 'Erreur de suppression',
//           textAlign: TextAlign.center,
//           style: TextStyle(color: Colors.white),
//         ),
//       ),
//     );
//   }
//
//   // Barre d'envoi de message
//   Widget _buildMessageInput() {
//     return Container(
//       color: Colors.grey[900],
//       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: Column(
//         children: [
//           if (replying) _buildReplyIndicatorBar(),
//           if (_image != null) _buildImagePreview(),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               _buildMediaButtons(),
//               _buildMessageTextField(),
//               _buildSendButton(),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildReplyIndicatorBar() {
//     return Container(
//       color: Colors.yellow[100]!.withOpacity(0.3),
//       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: Row(
//         children: [
//           Icon(Icons.reply, color: Colors.yellow[700], size: 20),
//           SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               'Re : $replyingTo',
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(color: Colors.yellow[700]),
//             ),
//           ),
//           InkWell(
//             onTap: () {
//               setState(() {
//                 replyingTo = "";
//                 replying = false;
//                 replyingToMessageId = "";
//                 replyingToMessageType = "";
//               });
//             },
//             child: Icon(Icons.close, color: Colors.yellow[700], size: 20),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildImagePreview() {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 8),
//       child: Stack(
//         children: [
//           Container(
//             height: 100,
//             width: 100,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(8),
//               image: DecorationImage(
//                 image: FileImage(_image!),
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//           Positioned(
//             top: 0,
//             right: 0,
//             child: GestureDetector(
//               onTap: () {
//                 setState(() {
//                   _image = null;
//                 });
//               },
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.red,
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(Icons.close, color: Colors.white, size: 20),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMediaButtons() {
//     return Row(
//       children: [
//         Padding(
//           padding: EdgeInsets.only(right: 8),
//           child: InkWell(
//             onTap: getImage,
//             child: Icon(Icons.camera_alt, color: Colors.green, size: 28),
//           ),
//         ),
//         Padding(
//           padding: EdgeInsets.only(right: 8),
//           child: InkWell(
//             onTap: () {
//               if (_isRecording) {
//                 _stopRecording();
//               } else {
//                 _startRecording();
//               }
//             },
//             child: Icon(
//               _isRecording ? Icons.stop : Icons.mic,
//               color: _isRecording ? Colors.red : Colors.green,
//               size: 28,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildMessageTextField() {
//     return Expanded(
//       child: Container(
//         margin: EdgeInsets.symmetric(horizontal: 8),
//         decoration: BoxDecoration(
//           color: Colors.grey[800],
//           borderRadius: BorderRadius.circular(30),
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: TextField(
//                 controller: _textController,
//                 focusNode: _focusNode,
//                 maxLines: null,
//                 onChanged: (text) {
//                   _updateTypingStatus(text.isNotEmpty);
//                 },
//                 onTap: () {
//                   if (_controller.hasClients) {
//                     _controller.animateTo(
//                       _controller.position.maxScrollExtent,
//                       duration: Duration(milliseconds: 300),
//                       curve: Curves.easeOut,
//                     );
//                   }
//                 },
//                 style: TextStyle(color: Colors.white),
//                 decoration: InputDecoration(
//                   hintText: _isRecording ? "Enregistrement en cours... ($_recordingDuration s)" : "Écrivez un message...",
//                   hintStyle: TextStyle(color: Colors.grey[400]),
//                   border: InputBorder.none,
//                   contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _updateTypingStatus(bool isTyping) {
//     final status = isTyping ? IsSendMessage.SENDING.name : IsSendMessage.NOTSENDING.name;
//
//     if (widget.chat.senderId == authProvider.loginUserData.id!) {
//       widget.chat.send_sending = status;
//     } else {
//       widget.chat.receiver_sending = status;
//     }
//
//     firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
//   }
//
//   Widget _buildSendButton() {
//     return InkWell(
//       onTap: _sendMessage,
//       child: Container(
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.green,
//           shape: BoxShape.circle,
//         ),
//         child: Icon(Icons.send, color: Colors.white, size: 24),
//       ),
//     );
//   }
//
//   // AppBar personnalisée
//   PreferredSizeWidget _buildAppBar(double width, double height) {
//     return AppBar(
//       backgroundColor: Colors.black,
//       elevation: 0,
//       title: Row(
//         children: [
//           _buildUserAvatar(width),
//           SizedBox(width: 12),
//           _buildUserInfo(),
//         ],
//       ),
//       actions: [
//         IconButton(
//           onPressed: () {
//             if (_controller.hasClients) {
//               _controller.animateTo(
//                 _controller.position.maxScrollExtent,
//                 duration: Duration(milliseconds: 300),
//                 curve: Curves.easeOut,
//               );
//             }
//           },
//           icon: Icon(Icons.arrow_downward, color: Colors.green),
//         ),
//       ],
//       iconTheme: IconThemeData(color: Colors.green),
//     );
//   }
//
//   Widget _buildUserAvatar(double width) {
//     return StreamBuilder<UserData>(
//       stream: userProvider.getStreamUser(widget.chat.receiver!.id!),
//       builder: (context, snapshot) {
//         final user = snapshot.hasData ? snapshot.data! : widget.chat.receiver!;
//
//         return GestureDetector(
//           onTap: () => _showUserDetailsModalDialog(user, width, MediaQuery.of(context).size.height),
//           child: Stack(
//             children: [
//               CircleAvatar(
//                 backgroundImage: NetworkImage(user.imageUrl!),
//                 radius: 20,
//               ),
//               Positioned(
//                 bottom: 0,
//                 right: 0,
//                 child: Container(
//                   width: 12,
//                   height: 12,
//                   decoration: BoxDecoration(
//                     color: user.state == UserState.OFFLINE.name
//                         ? Colors.grey
//                         : Colors.green,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.black, width: 2),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildUserInfo() {
//     return StreamBuilder<Chat>(
//       stream: userProvider.getStreamChat(widget.chat.id!),
//       builder: (context, snapshot) {
//         final chat = snapshot.hasData ? snapshot.data! : widget.chat;
//         final isTyping = _isUserTyping(chat);
//
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Text(
//                   "@${widget.chat.receiver!.pseudo}",
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 if (widget.chat.receiver!.isVerify!)
//                   Padding(
//                     padding: EdgeInsets.only(left: 4),
//                     child: Icon(Icons.verified, color: Colors.green, size: 16),
//                   ),
//               ],
//             ),
//             Text(
//               isTyping ? "écrit..." : "${formatNumber(widget.chat.receiver!.userAbonnesIds!.length!)} abonné(s)",
//               style: TextStyle(
//                 fontSize: 12,
//                 color: isTyping ? Colors.green : Colors.grey[400],
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   bool _isUserTyping(Chat chat) {
//     if (authProvider.loginUserData.id == chat.senderId) {
//       return chat.receiver_sending == IsSendMessage.SENDING.name;
//     } else if (authProvider.loginUserData.id == chat.receiverId) {
//       return chat.send_sending == IsSendMessage.SENDING.name;
//     }
//     return false;
//   }
//
//   Widget _buildLoadingMessages() {
//     return ListView.builder(
//       controller: _controller,
//       itemCount: userProvider.chat.messages?.length ?? 0,
//       itemBuilder: (context, index) {
//         final message = userProvider.chat.messages![index];
//         final isLastItem = index == (userProvider.chat.messages!.length - 1);
//         return _buildMessageBubble(message, isLastItem, userProvider.chat.messages ?? []);
//       },
//     );
//   }
//
//   Widget _buildMessageList(List<Message> messages) {
//     return ListView.builder(
//       controller: _controller,
//       itemCount: messages.length,
//       itemBuilder: (context, index) {
//         final message = messages[index];
//         final isLastItem = index == messages.length - 1;
//
//         // Marquer comme lu si nécessaire
//         if (authProvider.loginUserData.id != message.sendBy &&
//             message.message_state != MessageState.LU.name) {
//           message.message_state = MessageState.LU.name;
//           firestore.collection('Messages').doc(message.id).update(message.toJson());
//         }
//
//         return _buildMessageBubble(message, isLastItem, messages);
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: _buildAppBar(width, height),
//       body: Column(
//         children: [
//           Expanded(
//             child: StreamBuilder<List<Message>>(
//               stream: getMessageData(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return _buildLoadingMessages();
//                 } else if (snapshot.hasError) {
//                   printVm('Erreur : ${snapshot.error.toString()}');
//                   return Center(
//                     child: Text(
//                         "Erreur de chargement",
//                         style: TextStyle(color: Colors.white)
//                     ),
//                   );
//                 } else if (snapshot.hasData) {
//                   return _buildMessageList(snapshot.data!);
//                 }
//                 return Center(
//                   child: CircularProgressIndicator(color: Colors.green),
//                 );
//               },
//             ),
//           ),
//           _buildMessageInput(),
//         ],
//       ),
//     );
//   }
// }
