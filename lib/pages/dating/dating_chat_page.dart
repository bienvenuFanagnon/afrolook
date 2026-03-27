// lib/pages/dating/dating_chat_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'dating_profile_detail_page.dart';

class DatingChatPage extends StatefulWidget {
  final String connectionId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final String? conversationId;

  const DatingChatPage({
    Key? key,
    required this.connectionId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    this.conversationId,
  }) : super(key: key);

  @override
  State<DatingChatPage> createState() => _DatingChatPageState();
}

class _DatingChatPageState extends State<DatingChatPage>
    with WidgetsBindingObserver {
  // Controllers
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Données
  String? _conversationId;
  List<DatingMessage> _messages = [];
  bool _isLoading = true;
  String? _currentUserId;
  DatingProfile? _otherDatingProfile;

  // Réponse
  bool _isReplying = false;
  DatingMessage? _replyingToMessage;

  // Images (web + mobile)
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _isSendingImage = false;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentPlayingMessageId;
  Duration _currentAudioDuration = Duration.zero;
  Duration _currentAudioPosition = Duration.zero;
  bool _isAudioPlaying = false;
  bool _isAudioLoading = false;
  AudioRecorder? _audioRecorder;
  String? _audioPath;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  bool _isSendingAudio = false;

  // Emoji
  bool _showEmojiPicker = false;

  // Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Couleurs
  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color secondaryGrey = const Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentUserId = authProvider.loginUserData.id;
    _initAudioRecorder();
    _loadOtherDatingProfile();
    _initConversation();

    // Écouteurs pour la lecture audio
    _audioPlayer.onPositionChanged.listen((Duration p) {
      if (mounted) setState(() => _currentAudioPosition = p);
    });
    _audioPlayer.onDurationChanged.listen((Duration d) {
      if (mounted) setState(() => _currentAudioDuration = d);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _currentPlayingMessageId = null;
          _currentAudioPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _audioRecorder?.dispose();
    _recordingTimer?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initAudioRecorder() async {
    _audioRecorder = AudioRecorder();
  }

  Future<void> _loadOtherDatingProfile() async {
    final snapshot = await _firestore
        .collection('dating_profiles')
        .where('userId', isEqualTo: widget.otherUserId)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _otherDatingProfile = DatingProfile.fromJson(snapshot.docs.first.data());
      });
    }
  }

  Future<void> _initConversation() async {
    if (widget.conversationId != null) {
      setState(() {
        _conversationId = widget.conversationId;
        _isLoading = false;
      });
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('dating_conversations')
          .where('connectionId', isEqualTo: widget.connectionId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _conversationId = snapshot.docs.first.id;
          _isLoading = false;
        });
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        final newConversationId = _firestore.collection('dating_conversations').doc().id;

        final conversation = DatingConversation(
          id: newConversationId,
          connectionId: widget.connectionId,
          userId1: _currentUserId!,
          userId2: widget.otherUserId,
          unreadCountUser1: 0,
          unreadCountUser2: 0,
          createdAt: now,
          updatedAt: now,
        );

        await _firestore
            .collection('dating_conversations')
            .doc(newConversationId)
            .set(conversation.toJson());

        setState(() {
          _conversationId = newConversationId;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Erreur lors de l\'initialisation', Colors.red);
    }
  }

  // ----------------------------------------------------------------------
  // Envoi de messages
  // ----------------------------------------------------------------------
  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final messageId = _firestore.collection('dating_messages').doc().id;

      final message = DatingMessage(
        id: messageId,
        conversationId: _conversationId!,
        senderUserId: _currentUserId!,
        receiverUserId: widget.otherUserId,
        type: MessageType.text,
        text: text,
        isRead: false,
        createdAt: now,
        updatedAt: now,
        replyToMessageId: _replyingToMessage?.id,
        replyToMessageText: _replyingToMessage?.text,
        replyToMessageType: _replyingToMessage?.type.name,
      );

      await _firestore
          .collection('dating_messages')
          .doc(messageId)
          .set(message.toJson());

      _updateConversationLastMessage(text, now);
      _textController.clear();
      _clearReplying();
      _scrollToBottom();
      _sendNotification('Nouveau message');
    } catch (e) {
      _showSnackBar('Erreur envoi message', Colors.red);
    }
  }

  Future<void> _sendImageMessage() async {
    if ((_selectedImageFile == null && _selectedImageBytes == null)) return;

    setState(() => _isSendingImage = true);

    try {
      String imageUrl;
      final now = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance.ref().child(
          'dating_chat_images/${now}.jpg');

      if (kIsWeb && _selectedImageBytes != null) {
        await storageRef.putData(_selectedImageBytes!);
      } else if (_selectedImageFile != null) {
        await storageRef.putFile(_selectedImageFile!);
      } else {
        throw Exception('Aucune image sélectionnée');
      }
      imageUrl = await storageRef.getDownloadURL();

      final messageId = _firestore.collection('dating_messages').doc().id;
      final message = DatingMessage(
        id: messageId,
        conversationId: _conversationId!,
        senderUserId: _currentUserId!,
        receiverUserId: widget.otherUserId,
        type: MessageType.image,
        mediaUrl: imageUrl,
        text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
        isRead: false,
        createdAt: now,
        updatedAt: now,
        replyToMessageId: _replyingToMessage?.id,
        replyToMessageText: _replyingToMessage?.text,
        replyToMessageType: _replyingToMessage?.type.name,
      );

      await _firestore
          .collection('dating_messages')
          .doc(messageId)
          .set(message.toJson());

      _updateConversationLastMessage('📷 Image', now);
      _textController.clear();
      _selectedImageFile = null;
      _selectedImageBytes = null;
      _clearReplying();
      _scrollToBottom();
      _sendNotification('Image');
    } catch (e) {
      _showSnackBar('Erreur envoi image', Colors.red);
    } finally {
      setState(() => _isSendingImage = false);
    }
  }

  Future<void> _sendAudioMessage(String audioPath) async {
    setState(() => _isSendingAudio = true);

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
          'dating_chat_audio/audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await storageRef.putFile(File(audioPath));
      final audioUrl = await storageRef.getDownloadURL();

      final now = DateTime.now().millisecondsSinceEpoch;
      final messageId = _firestore.collection('dating_messages').doc().id;

      final message = DatingMessage(
        id: messageId,
        conversationId: _conversationId!,
        senderUserId: _currentUserId!,
        receiverUserId: widget.otherUserId,
        type: MessageType.audio,
        mediaUrl: audioUrl,
        isRead: false,
        createdAt: now,
        updatedAt: now,
        replyToMessageId: _replyingToMessage?.id,
        replyToMessageText: _replyingToMessage?.text,
        replyToMessageType: _replyingToMessage?.type.name,
      );

      await _firestore
          .collection('dating_messages')
          .doc(messageId)
          .set(message.toJson());

      _updateConversationLastMessage('🎤 Audio', now);
      _scrollToBottom();
      _sendNotification('Message audio');
    } catch (e) {
      _showSnackBar('Erreur envoi audio', Colors.red);
    } finally {
      setState(() => _isSendingAudio = false);
    }
  }

  void _sendMessage() {
    if (_isSendingImage || _isSendingAudio) return;

    if (_isRecording) {
      _stopRecording(cancel: false);
      return;
    }

    if (_selectedImageFile != null || _selectedImageBytes != null) {
      _sendImageMessage();
    } else if (_textController.text.trim().isNotEmpty) {
      _sendTextMessage();
    }
  }

  void _updateConversationLastMessage(String lastMessage, int timestamp) {
    _firestore
        .collection('dating_conversations')
        .doc(_conversationId)
        .update({
      'lastMessage': lastMessage,
      'lastMessageAt': timestamp,
      'updatedAt': timestamp,
    });
  }

  // ----------------------------------------------------------------------
  // Audio recording
  // ----------------------------------------------------------------------
  Future<void> _startRecording() async {
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
      setState(() => _audioPath = path);
    } else {
      _showSnackBar('Permission microphone refusée', Colors.red);
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
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
  }

  // ----------------------------------------------------------------------
  // Audio playback
  // ----------------------------------------------------------------------
  Future<void> _toggleAudio(DatingMessage message) async {
    final messageId = message.id;
    try {
      if (_currentPlayingMessageId != messageId) {
        if (_currentPlayingMessageId != null) {
          await _audioPlayer.stop();
        }
        setState(() {
          _currentPlayingMessageId = messageId;
          _isAudioLoading = true;
        });
        await _audioPlayer.play(UrlSource(message.mediaUrl!));
        setState(() {
          _isAudioPlaying = true;
          _isAudioLoading = false;
        });
      } else {
        if (_isAudioPlaying) {
          await _audioPlayer.pause();
          setState(() => _isAudioPlaying = false);
        } else {
          setState(() => _isAudioLoading = true);
          await _audioPlayer.resume();
          setState(() {
            _isAudioPlaying = true;
            _isAudioLoading = false;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Erreur lecture audio', Colors.red);
      setState(() => _isAudioLoading = false);
    }
  }

  void _seekAudio(double value) {
    _audioPlayer.seek(Duration(seconds: value.toInt()));
  }

  // ----------------------------------------------------------------------
  // Gestion des messages
  // ----------------------------------------------------------------------
  void _markMessagesAsRead() {
    for (var message in _messages) {
      if (message.receiverUserId == _currentUserId && !message.isRead) {
        _firestore
            .collection('dating_messages')
            .doc(message.id)
            .update({'isRead': true});
      }
    }
  }

  void _deleteMessage(DatingMessage message) async {
    try {
      await _firestore.collection('dating_messages').doc(message.id).delete();
      _showSnackBar('Message supprimé', Colors.green);
    } catch (e) {
      _showSnackBar('Erreur suppression', Colors.red);
    }
  }

  void _setReplying(DatingMessage message) {
    setState(() {
      _isReplying = true;
      _replyingToMessage = message;
    });
    _focusNode.requestFocus();
  }

  void _clearReplying() {
    setState(() {
      _isReplying = false;
      _replyingToMessage = null;
    });
  }

  // ----------------------------------------------------------------------
  // Notifications
  // ----------------------------------------------------------------------
  Future<void> _sendNotification(String message) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final toUserDoc = await _firestore.collection('Users').doc(widget.otherUserId).get();
    final toUser = UserData.fromJson(toUserDoc.data() ?? {});

    if (toUser.oneIgnalUserid != null && toUser.oneIgnalUserid!.isNotEmpty) {
      await authProvider.sendNotification(
        userIds: [toUser.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl ?? '',
        send_user_id: _currentUserId!,
        recever_user_id: widget.otherUserId,
        message: 'Afrolove❤️: 💬 @${authProvider.loginUserData.pseudo} vous a envoyé un message',
        type_notif: 'DATING_MESSAGE',
        post_id: '',
        post_type: '',
        chat_id: '',
      );
    }
  }

  // ----------------------------------------------------------------------
  // UI Helpers
  // ----------------------------------------------------------------------
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showImageFullscreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                child: CachedNetworkImage(imageUrl: imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFile = null;
        });
      } else {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          _selectedImageBytes = null;
        });
      }
    }
  }

  void _goToProfile() {
    if (_otherDatingProfile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DatingProfileDetailPage(profile: _otherDatingProfile!),
        ),
      );
    }
  }

  void _showProfileOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person, color: primaryRed),
              title: Text('Voir le profil'),
              onTap: () {
                Navigator.pop(context);
                _goToProfile();
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: primaryRed),
              title: Text('Bloquer'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            ListTile(
              leading: Icon(Icons.flag, color: primaryRed),
              title: Text('Signaler'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bloquer ${widget.otherUserName}'),
        content: Text(
          'Êtes-vous sûr de vouloir bloquer cet utilisateur ? '
              'Vous ne pourrez plus voir son profil ni recevoir ses messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockUser();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
            child: Text('Bloquer'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      final blockId = _firestore.collection('dating_blocks').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _firestore.collection('dating_blocks').doc(blockId).set({
        'id': blockId,
        'blockerUserId': _currentUserId,
        'blockedUserId': widget.otherUserId,
        'createdAt': now,
      });

      _showSnackBar('${widget.otherUserName} a été bloqué', Colors.red);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Erreur lors du blocage', Colors.red);
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Signaler ${widget.otherUserName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pourquoi signalez-vous cette conversation ?'),
            SizedBox(height: 16),
            ...['Message inapproprié', 'Harcèlement', 'Spam', 'Contenu offensant', 'Autre']
                .map((reason) => ListTile(
              title: Text(reason),
              onTap: () {
                Navigator.pop(context);
                _submitReport(reason);
              },
            ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      final reportId = _firestore.collection('dating_reports').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _firestore.collection('dating_reports').doc(reportId).set({
        'id': reportId,
        'reporterUserId': _currentUserId,
        'targetUserId': widget.otherUserId,
        'reason': reason,
        'description': '',
        'createdAt': now,
      });

      _showSnackBar('Signalement envoyé', Colors.green);
    } catch (e) {
      _showSnackBar('Erreur lors du signalement', Colors.red);
    }
  }

  // ----------------------------------------------------------------------
  // Widgets
  // ----------------------------------------------------------------------
  Widget _buildMessageBubble(DatingMessage message, bool isMe) {
    final time = DateTime.fromMillisecondsSinceEpoch(message.createdAt);
    final timeStr = DateFormat('HH:mm').format(time);

    return GestureDetector(
      onLongPress: () {
        if (message.senderUserId == _currentUserId) {
          showModalBottomSheet(
            context: context,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            backgroundColor: secondaryGrey,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Supprimer', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(message);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.reply, color: primaryYellow),
                    title: Text('Répondre', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _setReplying(message);
                    },
                  ),
                ],
              ),
            ),
          );
        } else {
          showModalBottomSheet(
            context: context,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            backgroundColor: secondaryGrey,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.reply, color: primaryYellow),
                    title: Text('Répondre', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _setReplying(message);
                    },
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: isMe ? 50 : 0, right: isMe ? 0 : 50),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.replyToMessageId != null && message.replyToMessageText != null)
              _buildReplyPreview(message),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? primaryRed : secondaryGrey,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                  bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == MessageType.text && message.text != null)
                    Text(
                      message.text!,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  if (message.type == MessageType.image && message.mediaUrl != null)
                    GestureDetector(
                      onTap: () => _showImageFullscreen(message.mediaUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: message.mediaUrl!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[800],
                            child: Center(child: CircularProgressIndicator(color: primaryRed)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[800],
                            child: Icon(Icons.broken_image, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  if (message.type == MessageType.audio && message.mediaUrl != null)
                    _AudioMessageWidget(audioUrl: message.mediaUrl!, isMe: isMe),
                ],
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                if (isMe && message.isRead) ...[
                  SizedBox(width: 4),
                  Icon(Icons.done_all, size: 12, color: Colors.blue),
                ] else if (isMe && !message.isRead) ...[
                  SizedBox(width: 4),
                  Icon(Icons.done, size: 12, color: Colors.grey.shade500),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(DatingMessage message) {
    String previewText = '';
    if (message.replyToMessageType == MessageType.text.name) {
      previewText = message.replyToMessageText ?? '';
    } else if (message.replyToMessageType == MessageType.image.name) {
      previewText = '📷 Image';
    } else if (message.replyToMessageType == MessageType.audio.name) {
      previewText = '🎤 Audio';
    } else {
      previewText = 'Message';
    }
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply, size: 12, color: primaryYellow),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              previewText.length > 40 ? '${previewText.substring(0, 40)}...' : previewText,
              style: TextStyle(color: Colors.white70, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(DatingMessage message, bool isMe) {
    final isCurrentPlaying = _currentPlayingMessageId == message.id;
    final duration = isCurrentPlaying ? _currentAudioDuration : Duration.zero;
    final position = isCurrentPlaying ? _currentAudioPosition : Duration.zero;
    final isPlaying = isCurrentPlaying && _isAudioPlaying;
    final isLoading = isCurrentPlaying && _isAudioLoading;

    return Container(
      width: 200,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleAudio(message),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white24 : Colors.grey[700],
                    shape: BoxShape.circle,
                  ),
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
                    size: 20,
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: position.inSeconds.toDouble(),
                  min: 0,
                  max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
                  onChanged: isCurrentPlaying ? (value) => _seekAudio(value) : null,
                  activeColor: isMe ? Colors.white : primaryRed,
                  inactiveColor: isMe ? Colors.white54 : Colors.grey,
                ),
              ),
              SizedBox(width: 8),
              Text(
                _formatDuration(position),
                style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryRed),
              SizedBox(height: 16),
              Text('Chargement...', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: _goToProfile,
              child: CircleAvatar(
                radius: 20,
                backgroundImage: _otherDatingProfile != null
                    ? NetworkImage(_otherDatingProfile!.imageUrl)
                    : NetworkImage(widget.otherUserImage),
                child: (widget.otherUserImage.isEmpty &&
                    _otherDatingProfile?.imageUrl.isEmpty == true)
                    ? Icon(Icons.person, size: 20)
                    : null,
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: _goToProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'En ligne',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showProfileOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('dating_messages')
                  .where('conversationId', isEqualTo: _conversationId)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final newMessages = docs
                    .map((doc) => DatingMessage.fromJson(doc.data() as Map<String, dynamic>))
                    .toList();

                if (newMessages.length != _messages.length) {
                  _messages = newMessages;
                  _markMessagesAsRead();
                  _scrollToBottom();
                }

                if (_messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade400),
                        SizedBox(height: 16),
                        Text('Aucun message', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                        SizedBox(height: 8),
                        Text('Envoyez un message pour commencer la conversation',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message.senderUserId == _currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _ChatInputWidget(
            controller: _textController,
            focusNode: _focusNode,
            onSend: _sendMessage,
            onPickImage: _pickImage,
            onStartRecording: _startRecording,
            onStopRecording: () => _stopRecording(cancel: true),
            isRecording: _isRecording,
            recordingDuration: _recordingDuration,
            isSending: _isSendingImage || _isSendingAudio,
            selectedImageFile: _selectedImageFile,
            selectedImageBytes: _selectedImageBytes,
            onClearImage: () => setState(() {
              _selectedImageFile = null;
              _selectedImageBytes = null;
            }),
            isReplying: _isReplying,
            replyingToMessage: _replyingToMessage,
            onClearReply: _clearReplying,
            onEmojiPickerToggle: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
            showEmojiPicker: _showEmojiPicker,
            onEmojiSelected: (emoji) => _textController.text += emoji.emoji,
            onCloseEmojiPicker: () => setState(() => _showEmojiPicker = false),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Widget de saisie optimisé (sans rebuild global)
// ----------------------------------------------------------------------
class _ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final bool isRecording;
  final int recordingDuration;
  final bool isSending;
  final File? selectedImageFile;
  final Uint8List? selectedImageBytes;
  final VoidCallback onClearImage;
  final bool isReplying;
  final DatingMessage? replyingToMessage;
  final VoidCallback onClearReply;
  final VoidCallback onEmojiPickerToggle;
  final bool showEmojiPicker;
  final Function(dynamic) onEmojiSelected;
  final VoidCallback onCloseEmojiPicker;

  const _ChatInputWidget({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onPickImage,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.isRecording,
    required this.recordingDuration,
    required this.isSending,
    required this.selectedImageFile,
    required this.selectedImageBytes,
    required this.onClearImage,
    required this.isReplying,
    required this.replyingToMessage,
    required this.onClearReply,
    required this.onEmojiPickerToggle,
    required this.showEmojiPicker,
    required this.onEmojiSelected,
    required this.onCloseEmojiPicker,
  });

  @override
  State<_ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<_ChatInputWidget> {
  bool get _canSend {
    return (widget.controller.text.trim().isNotEmpty ||
        widget.selectedImageFile != null ||
        widget.selectedImageBytes != null ||
        widget.isRecording) &&
        !widget.isSending;
  }

  @override
  Widget build(BuildContext context) {
    final primaryRed = const Color(0xFFE63946);
    final secondaryGrey = const Color(0xFF2C2C2C);
    final primaryYellow = const Color(0xFFFFD700);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        children: [
          if (widget.isReplying && widget.replyingToMessage != null) _buildReplyingBar(),
          if (widget.selectedImageFile != null || widget.selectedImageBytes != null)
            _buildImagePreview(),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.emoji_emotions, color: Colors.grey[600]),
                onPressed: widget.onEmojiPickerToggle,
              ),
              IconButton(
                icon: Icon(Icons.photo, color: Colors.grey[600]),
                onPressed: widget.onPickImage,
              ),
              IconButton(
                icon: Icon(
                  widget.isRecording ? Icons.stop : Icons.mic,
                  color: widget.isRecording ? Colors.red : Colors.grey[600],
                ),
                onPressed: widget.isRecording ? widget.onStopRecording : widget.onStartRecording,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: null,
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: widget.isRecording
                          ? "Enregistrement... (${widget.recordingDuration} s)"
                          : "Écrire un message...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: _canSend ? primaryRed : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _canSend ? widget.onSend : null,
                    ),
                  );
                },
              ),
            ],
          ),
          if (widget.showEmojiPicker)
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      widget.onEmojiSelected(emoji);
                    },
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
                      onPressed: widget.onCloseEmojiPicker,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyingBar() {
    final primaryYellow = const Color(0xFFFFD700);
    final secondaryGrey = const Color(0xFF2C2C2C);
    String previewText = '';
    if (widget.replyingToMessage!.type == MessageType.text) {
      previewText = widget.replyingToMessage!.text ?? '';
    } else if (widget.replyingToMessage!.type == MessageType.image) {
      previewText = '📷 Image';
    } else if (widget.replyingToMessage!.type == MessageType.audio) {
      previewText = '🎤 Audio';
    } else {
      previewText = 'Message';
    }
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: secondaryGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: primaryYellow, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              previewText.length > 40 ? '${previewText.substring(0, 40)}...' : previewText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: Colors.white70),
            onPressed: widget.onClearReply,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    ImageProvider image;
    if (kIsWeb && widget.selectedImageBytes != null) {
      image = MemoryImage(widget.selectedImageBytes!);
    } else if (widget.selectedImageFile != null) {
      image = FileImage(widget.selectedImageFile!);
    } else {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(image: image, height: 100, width: 100, fit: BoxFit.cover),
          ),
          IconButton(
            icon: Container(
              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
            onPressed: widget.onClearImage,
          ),
        ],
      ),
    );
  }
}
// Widget audio indépendant
class _AudioMessageWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const _AudioMessageWidget({
    Key? key,
    required this.audioUrl,
    required this.isMe,
  }) : super(key: key);

  @override
  State<_AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<_AudioMessageWidget> {
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isLoading = true);
      try {
        await _player.play(UrlSource(widget.audioUrl));
        setState(() {
          _isPlaying = true;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lecture audio'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _seek(double value) {
    _player.seek(Duration(seconds: value.toInt()));
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final primaryRed = const Color(0xFFE63946);

    return Container(
      width: 200,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isMe ? Colors.white24 : Colors.grey[700],
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isMe ? Colors.white : Colors.black,
                ),
              )
                  : Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 20,
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: _position.inSeconds.toDouble(),
              min: 0,
              max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
              onChanged: _seek,
              activeColor: isMe ? Colors.white : primaryRed,
              inactiveColor: isMe ? Colors.white54 : Colors.grey,
            ),
          ),
          SizedBox(width: 8),
          Text(
            _formatDuration(_position),
            style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.white70),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

// // lib/pages/dating/dating_chat_page.dart
// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:record/record.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
// import '../../models/dating_data.dart';
// import '../../models/enums.dart';
// import '../../models/model_data.dart';
// import '../../providers/authProvider.dart';
// import 'dating_profile_detail_page.dart';
//
// class DatingChatPage extends StatefulWidget {
//   final String connectionId;
//   final String otherUserId;
//   final String otherUserName;
//   final String otherUserImage;
//   final String? conversationId;
//
//   const DatingChatPage({
//     Key? key,
//     required this.connectionId,
//     required this.otherUserId,
//     required this.otherUserName,
//     required this.otherUserImage,
//     this.conversationId,
//   }) : super(key: key);
//
//   @override
//   State<DatingChatPage> createState() => _DatingChatPageState();
// }
//
// class _DatingChatPageState extends State<DatingChatPage>
//     with WidgetsBindingObserver {
//   // Controllers
//   final TextEditingController _textController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final FocusNode _focusNode = FocusNode();
//
//   // Données
//   String? _conversationId;
//   List<DatingMessage> _messages = [];
//   bool _isLoading = true;
//   String? _currentUserId;
//   DatingProfile? _otherDatingProfile; // Profil dating de l'autre utilisateur
//
//   // Réponse
//   bool _isReplying = false;
//   DatingMessage? _replyingToMessage;
//
//   // Images (web + mobile)
//   File? _selectedImageFile;
//   Uint8List? _selectedImageBytes;
//   bool _isSendingImage = false;
//
//   // Audio
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   String? _currentPlayingMessageId;
//   Duration _currentAudioDuration = Duration.zero;
//   Duration _currentAudioPosition = Duration.zero;
//   bool _isAudioPlaying = false;
//   bool _isAudioLoading = false;
//   AudioRecorder? _audioRecorder;
//   String? _audioPath;
//   bool _isRecording = false;
//   int _recordingDuration = 0;
//   Timer? _recordingTimer;
//   bool _isSendingAudio = false;
//
//   // Emoji
//   bool _showEmojiPicker = false;
//
//   // Firestore
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   // Couleurs
//   final Color primaryRed = const Color(0xFFE63946);
//   final Color primaryYellow = const Color(0xFFFFD700);
//   final Color secondaryGrey = const Color(0xFF2C2C2C);
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     _currentUserId = authProvider.loginUserData.id;
//     _initAudioRecorder();
//     _loadOtherDatingProfile();
//     _initConversation();
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _audioPlayer.dispose();
//     _audioRecorder?.dispose();
//     _recordingTimer?.cancel();
//     _scrollController.dispose();
//     _textController.dispose();
//     _focusNode.dispose();
//     super.dispose();
//   }
//
//   void _initAudioRecorder() async {
//     _audioRecorder = AudioRecorder();
//   }
//
//   Future<void> _loadOtherDatingProfile() async {
//     final snapshot = await _firestore
//         .collection('dating_profiles')
//         .where('userId', isEqualTo: widget.otherUserId)
//         .limit(1)
//         .get();
//     if (snapshot.docs.isNotEmpty) {
//       setState(() {
//         _otherDatingProfile = DatingProfile.fromJson(snapshot.docs.first.data());
//       });
//     }
//   }
//
//   Future<void> _initConversation() async {
//     if (widget.conversationId != null) {
//       setState(() {
//         _conversationId = widget.conversationId;
//         _isLoading = false;
//       });
//       return;
//     }
//
//     try {
//       final snapshot = await _firestore
//           .collection('dating_conversations')
//           .where('connectionId', isEqualTo: widget.connectionId)
//           .limit(1)
//           .get();
//
//       if (snapshot.docs.isNotEmpty) {
//         setState(() {
//           _conversationId = snapshot.docs.first.id;
//           _isLoading = false;
//         });
//       } else {
//         final now = DateTime.now().millisecondsSinceEpoch;
//         final newConversationId = _firestore.collection('dating_conversations').doc().id;
//
//         final conversation = DatingConversation(
//           id: newConversationId,
//           connectionId: widget.connectionId,
//           userId1: _currentUserId!,
//           userId2: widget.otherUserId,
//           unreadCountUser1: 0,
//           unreadCountUser2: 0,
//           createdAt: now,
//           updatedAt: now,
//         );
//
//         await _firestore
//             .collection('dating_conversations')
//             .doc(newConversationId)
//             .set(conversation.toJson());
//
//         setState(() {
//           _conversationId = newConversationId;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() => _isLoading = false);
//       _showSnackBar('Erreur lors de l\'initialisation', Colors.red);
//     }
//   }
//
//   // ----------------------------------------------------------------------
//   // Envoi de messages
//   // ----------------------------------------------------------------------
//   Future<void> _sendTextMessage() async {
//     final text = _textController.text.trim();
//     if (text.isEmpty) return;
//
//     try {
//       final now = DateTime.now().millisecondsSinceEpoch;
//       final messageId = _firestore.collection('dating_messages').doc().id;
//
//       final message = DatingMessage(
//         id: messageId,
//         conversationId: _conversationId!,
//         senderUserId: _currentUserId!,
//         receiverUserId: widget.otherUserId,
//         type: MessageType.text,
//         text: text,
//         isRead: false,
//         createdAt: now,
//         updatedAt: now,
//         replyToMessageId: _replyingToMessage?.id,
//         replyToMessageText: _replyingToMessage?.text,
//         replyToMessageType: _replyingToMessage?.type.name,
//       );
//
//       await _firestore
//           .collection('dating_messages')
//           .doc(messageId)
//           .set(message.toJson());
//
//       _updateConversationLastMessage(text, now);
//       _textController.clear();
//       _clearReplying();
//       _scrollToBottom();
//       _sendNotification('Nouveau message');
//     } catch (e) {
//       _showSnackBar('Erreur envoi message', Colors.red);
//     }
//   }
//
//   Future<void> _sendImageMessage() async {
//     if ((_selectedImageFile == null && _selectedImageBytes == null)) return;
//
//     setState(() => _isSendingImage = true);
//
//     try {
//       String imageUrl;
//       final now = DateTime.now().millisecondsSinceEpoch;
//       final storageRef = FirebaseStorage.instance.ref().child(
//           'dating_chat_images/${now}.jpg');
//
//       if (kIsWeb && _selectedImageBytes != null) {
//         await storageRef.putData(_selectedImageBytes!);
//       } else if (_selectedImageFile != null) {
//         await storageRef.putFile(_selectedImageFile!);
//       } else {
//         throw Exception('Aucune image sélectionnée');
//       }
//       imageUrl = await storageRef.getDownloadURL();
//
//       final messageId = _firestore.collection('dating_messages').doc().id;
//       final message = DatingMessage(
//         id: messageId,
//         conversationId: _conversationId!,
//         senderUserId: _currentUserId!,
//         receiverUserId: widget.otherUserId,
//         type: MessageType.image,
//         mediaUrl: imageUrl,
//         text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
//         isRead: false,
//         createdAt: now,
//         updatedAt: now,
//         replyToMessageId: _replyingToMessage?.id,
//         replyToMessageText: _replyingToMessage?.text,
//         replyToMessageType: _replyingToMessage?.type.name,
//       );
//
//       await _firestore
//           .collection('dating_messages')
//           .doc(messageId)
//           .set(message.toJson());
//
//       _updateConversationLastMessage('📷 Image', now);
//       _textController.clear();
//       _selectedImageFile = null;
//       _selectedImageBytes = null;
//       _clearReplying();
//       _scrollToBottom();
//       _sendNotification('Image');
//     } catch (e) {
//       _showSnackBar('Erreur envoi image', Colors.red);
//     } finally {
//       setState(() => _isSendingImage = false);
//     }
//   }
//
//   Future<void> _sendAudioMessage(String audioPath) async {
//     setState(() => _isSendingAudio = true);
//
//     try {
//       final storageRef = FirebaseStorage.instance.ref().child(
//           'dating_chat_audio/audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
//       await storageRef.putFile(File(audioPath));
//       final audioUrl = await storageRef.getDownloadURL();
//
//       final now = DateTime.now().millisecondsSinceEpoch;
//       final messageId = _firestore.collection('dating_messages').doc().id;
//
//       final message = DatingMessage(
//         id: messageId,
//         conversationId: _conversationId!,
//         senderUserId: _currentUserId!,
//         receiverUserId: widget.otherUserId,
//         type: MessageType.audio,
//         mediaUrl: audioUrl,
//         isRead: false,
//         createdAt: now,
//         updatedAt: now,
//         replyToMessageId: _replyingToMessage?.id,
//         replyToMessageText: _replyingToMessage?.text,
//         replyToMessageType: _replyingToMessage?.type.name,
//       );
//
//       await _firestore
//           .collection('dating_messages')
//           .doc(messageId)
//           .set(message.toJson());
//
//       _updateConversationLastMessage('🎤 Audio', now);
//       _scrollToBottom();
//       _sendNotification('Message audio');
//     } catch (e) {
//       _showSnackBar('Erreur envoi audio', Colors.red);
//     } finally {
//       setState(() => _isSendingAudio = false);
//     }
//   }
//
//   void _sendMessage() {
//     if (_isSendingImage || _isSendingAudio) return;
//
//     if (_isRecording) {
//       // Arrêter l'enregistrement et envoyer
//       _stopRecording(cancel: false);
//       return;
//     }
//
//     if (_selectedImageFile != null || _selectedImageBytes != null) {
//       _sendImageMessage();
//     } else if (_textController.text.trim().isNotEmpty) {
//       _sendTextMessage();
//     }
//   }
//
//   void _updateConversationLastMessage(String lastMessage, int timestamp) {
//     _firestore
//         .collection('dating_conversations')
//         .doc(_conversationId)
//         .update({
//       'lastMessage': lastMessage,
//       'lastMessageAt': timestamp,
//       'updatedAt': timestamp,
//     });
//   }
//
//   // ----------------------------------------------------------------------
//   // Audio recording
//   // ----------------------------------------------------------------------
//   Future<void> _startRecording() async {
//     if (await Permission.microphone.request().isGranted) {
//       setState(() {
//         _isRecording = true;
//         _recordingDuration = 0;
//       });
//
//       _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
//         if (mounted) {
//           setState(() {
//             _recordingDuration = timer.tick;
//           });
//         }
//       });
//
//       final directory = await getTemporaryDirectory();
//       final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
//
//       await _audioRecorder!.start(
//         const RecordConfig(encoder: AudioEncoder.aacLc),
//         path: path,
//       );
//       setState(() => _audioPath = path);
//     } else {
//       _showSnackBar('Permission microphone refusée', Colors.red);
//     }
//   }
//
//   Future<void> _stopRecording({bool cancel = false}) async {
//     _recordingTimer?.cancel();
//     await _audioRecorder?.stop();
//
//     if (!cancel && _audioPath != null) {
//       _sendAudioMessage(_audioPath!);
//     } else if (_audioPath != null) {
//       await File(_audioPath!).delete();
//     }
//
//     setState(() {
//       _isRecording = false;
//       _recordingDuration = 0;
//       _audioPath = null;
//     });
//   }
//
//   // ----------------------------------------------------------------------
//   // Audio playback
//   // ----------------------------------------------------------------------
//   Future<void> _toggleAudio(DatingMessage message) async {
//     final messageId = message.id;
//     try {
//       if (_currentPlayingMessageId != messageId) {
//         if (_currentPlayingMessageId != null) {
//           await _audioPlayer.stop();
//         }
//         setState(() {
//           _currentPlayingMessageId = messageId;
//           _isAudioLoading = true;
//         });
//         await _audioPlayer.play(UrlSource(message.mediaUrl!));
//         setState(() {
//           _isAudioPlaying = true;
//           _isAudioLoading = false;
//         });
//       } else {
//         if (_isAudioPlaying) {
//           await _audioPlayer.pause();
//           setState(() => _isAudioPlaying = false);
//         } else {
//           setState(() => _isAudioLoading = true);
//           await _audioPlayer.resume();
//           setState(() {
//             _isAudioPlaying = true;
//             _isAudioLoading = false;
//           });
//         }
//       }
//     } catch (e) {
//       _showSnackBar('Erreur lecture audio', Colors.red);
//       setState(() => _isAudioLoading = false);
//     }
//   }
//
//   void _seekAudio(double value) {
//     _audioPlayer.seek(Duration(seconds: value.toInt()));
//   }
//
//   // ----------------------------------------------------------------------
//   // Gestion des messages
//   // ----------------------------------------------------------------------
//   void _markMessagesAsRead() {
//     for (var message in _messages) {
//       if (message.receiverUserId == _currentUserId && !message.isRead) {
//         _firestore
//             .collection('dating_messages')
//             .doc(message.id)
//             .update({'isRead': true});
//       }
//     }
//   }
//
//   void _deleteMessage(DatingMessage message) async {
//     try {
//       await _firestore.collection('dating_messages').doc(message.id).delete();
//       _showSnackBar('Message supprimé', Colors.green);
//     } catch (e) {
//       _showSnackBar('Erreur suppression', Colors.red);
//     }
//   }
//
//   void _setReplying(DatingMessage message) {
//     setState(() {
//       _isReplying = true;
//       _replyingToMessage = message;
//     });
//     _focusNode.requestFocus();
//   }
//
//   void _clearReplying() {
//     setState(() {
//       _isReplying = false;
//       _replyingToMessage = null;
//     });
//   }
//
//   // ----------------------------------------------------------------------
//   // Notifications
//   // ----------------------------------------------------------------------
//   Future<void> _sendNotification(String message) async {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final toUserDoc = await _firestore.collection('Users').doc(widget.otherUserId).get();
//     final toUser = UserData.fromJson(toUserDoc.data() ?? {});
//
//     if (toUser.oneIgnalUserid != null && toUser.oneIgnalUserid!.isNotEmpty) {
//       await authProvider.sendNotification(
//         userIds: [toUser.oneIgnalUserid!],
//         smallImage: authProvider.loginUserData.imageUrl ?? '',
//         send_user_id: _currentUserId!,
//         recever_user_id: widget.otherUserId,
//         message: '💬 @${authProvider.loginUserData.pseudo} vous a envoyé un message',
//         type_notif: 'DATING_MESSAGE',
//         post_id: '',
//         post_type: '',
//         chat_id: '',
//       );
//     }
//   }
//
//   // ----------------------------------------------------------------------
//   // UI Helpers
//   // ----------------------------------------------------------------------
//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   void _showSnackBar(String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: TextStyle(color: Colors.white)),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }
//
//   void _showImageFullscreen(String imageUrl) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => Scaffold(
//           backgroundColor: Colors.black,
//           appBar: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             iconTheme: IconThemeData(color: Colors.white),
//           ),
//           body: Center(
//             child: GestureDetector(
//               onTap: () => Navigator.pop(context),
//               child: InteractiveViewer(
//                 child: CachedNetworkImage(imageUrl: imageUrl),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _pickImage() async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       if (kIsWeb) {
//         final bytes = await pickedFile.readAsBytes();
//         setState(() {
//           _selectedImageBytes = bytes;
//           _selectedImageFile = null;
//         });
//       } else {
//         setState(() {
//           _selectedImageFile = File(pickedFile.path);
//           _selectedImageBytes = null;
//         });
//       }
//     }
//   }
//
//   void _goToProfile() {
//     if (_otherDatingProfile != null) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => DatingProfileDetailPage(profile: _otherDatingProfile!),
//         ),
//       );
//     }
//   }
//
//   // ----------------------------------------------------------------------
//   // Widgets
//   // ----------------------------------------------------------------------
//   Widget _buildMessageBubble(DatingMessage message, bool isMe) {
//     final time = DateTime.fromMillisecondsSinceEpoch(message.createdAt);
//     final timeStr = DateFormat('HH:mm').format(time);
//
//     return GestureDetector(
//       onLongPress: () {
//         if (message.senderUserId == _currentUserId) {
//           showModalBottomSheet(
//             context: context,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//             ),
//             backgroundColor: secondaryGrey,
//             builder: (context) => SafeArea(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   ListTile(
//                     leading: Icon(Icons.delete, color: Colors.red),
//                     title: Text('Supprimer', style: TextStyle(color: Colors.white)),
//                     onTap: () {
//                       Navigator.pop(context);
//                       _deleteMessage(message);
//                     },
//                   ),
//                   ListTile(
//                     leading: Icon(Icons.reply, color: primaryYellow),
//                     title: Text('Répondre', style: TextStyle(color: Colors.white)),
//                     onTap: () {
//                       Navigator.pop(context);
//                       _setReplying(message);
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           );
//         } else {
//           showModalBottomSheet(
//             context: context,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//             ),
//             backgroundColor: secondaryGrey,
//             builder: (context) => SafeArea(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   ListTile(
//                     leading: Icon(Icons.reply, color: primaryYellow),
//                     title: Text('Répondre', style: TextStyle(color: Colors.white)),
//                     onTap: () {
//                       Navigator.pop(context);
//                       _setReplying(message);
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }
//       },
//       child: Container(
//         margin: EdgeInsets.only(bottom: 8, left: isMe ? 50 : 0, right: isMe ? 0 : 50),
//         child: Column(
//           crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//           children: [
//             // Aperçu du message original si c'est une réponse
//             if (message.replyToMessageId != null && message.replyToMessageText != null)
//               _buildReplyPreview(message),
//             // Contenu principal
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               decoration: BoxDecoration(
//                 color: isMe ? primaryRed : secondaryGrey,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(16),
//                   topRight: Radius.circular(16),
//                   bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
//                   bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
//                 ),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 4,
//                     offset: Offset(0, 1),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (message.type == MessageType.text && message.text != null)
//                     Text(
//                       message.text!,
//                       style: TextStyle(
//                         color: isMe ? Colors.white : Colors.white,
//                         fontSize: 14,
//                       ),
//                     ),
//                   if (message.type == MessageType.image && message.mediaUrl != null)
//                     GestureDetector(
//                       onTap: () => _showImageFullscreen(message.mediaUrl!),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(12),
//                         child: CachedNetworkImage(
//                           imageUrl: message.mediaUrl!,
//                           width: 200,
//                           height: 200,
//                           fit: BoxFit.cover,
//                           placeholder: (context, url) => Container(
//                             width: 200,
//                             height: 200,
//                             color: Colors.grey[800],
//                             child: Center(
//                               child: CircularProgressIndicator(color: primaryRed),
//                             ),
//                           ),
//                           errorWidget: (context, url, error) => Container(
//                             width: 200,
//                             height: 200,
//                             color: Colors.grey[800],
//                             child: Icon(Icons.broken_image, color: Colors.white),
//                           ),
//                         ),
//                       ),
//                     ),
//                   if (message.type == MessageType.audio && message.mediaUrl != null)
//                     _buildAudioPlayer(message, isMe),
//                 ],
//               ),
//             ),
//             SizedBox(height: 4),
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   timeStr,
//                   style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
//                 ),
//                 if (isMe && message.isRead) ...[
//                   SizedBox(width: 4),
//                   Icon(Icons.done_all, size: 12, color: Colors.blue),
//                 ] else if (isMe && !message.isRead) ...[
//                   SizedBox(width: 4),
//                   Icon(Icons.done, size: 12, color: Colors.grey.shade500),
//                 ],
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildReplyPreview(DatingMessage message) {
//     String previewText = '';
//     if (message.replyToMessageType == MessageType.text.name) {
//       previewText = message.replyToMessageText ?? '';
//     } else if (message.replyToMessageType == MessageType.image.name) {
//       previewText = '📷 Image';
//     } else if (message.replyToMessageType == MessageType.audio.name) {
//       previewText = '🎤 Audio';
//     } else {
//       previewText = 'Message';
//     }
//     return Container(
//       margin: EdgeInsets.only(bottom: 4),
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: Colors.grey[800],
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[600]!),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.reply, size: 12, color: primaryYellow),
//           SizedBox(width: 4),
//           Expanded(
//             child: Text(
//               previewText.length > 40
//                   ? '${previewText.substring(0, 40)}...'
//                   : previewText,
//               style: TextStyle(color: Colors.white70, fontSize: 10),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAudioPlayer(DatingMessage message, bool isMe) {
//     final isCurrentPlaying = _currentPlayingMessageId == message.id;
//     final duration = isCurrentPlaying ? _currentAudioDuration : Duration.zero;
//     final position = isCurrentPlaying ? _currentAudioPosition : Duration.zero;
//     final isPlaying = isCurrentPlaying && _isAudioPlaying;
//     final isLoading = isCurrentPlaying && _isAudioLoading;
//
//     return Container(
//       width: 200,
//       child: Column(
//         children: [
//           Row(
//             children: [
//               GestureDetector(
//                 onTap: () => _toggleAudio(message),
//                 child: Container(
//                   padding: EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     color: isMe ? Colors.white24 : Colors.grey[700],
//                     shape: BoxShape.circle,
//                   ),
//                   child: isLoading
//                       ? SizedBox(
//                     width: 16,
//                     height: 16,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: isMe ? Colors.white : Colors.black,
//                     ),
//                   )
//                       : Icon(
//                     isPlaying ? Icons.pause : Icons.play_arrow,
//                     size: 20,
//                     color: isMe ? Colors.white : Colors.black,
//                   ),
//                 ),
//               ),
//               SizedBox(width: 8),
//               Expanded(
//                 child: Slider(
//                   value: position.inSeconds.toDouble(),
//                   min: 0,
//                   max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
//                   onChanged: isCurrentPlaying
//                       ? (value) => _seekAudio(value)
//                       : null,
//                   activeColor: isMe ? Colors.white : primaryRed,
//                   inactiveColor: isMe ? Colors.white54 : Colors.grey,
//                 ),
//               ),
//               SizedBox(width: 8),
//               Text(
//                 _formatDuration(position),
//                 style: TextStyle(
//                   fontSize: 10,
//                   color: isMe ? Colors.white70 : Colors.white70,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _formatDuration(Duration d) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final minutes = twoDigits(d.inMinutes.remainder(60));
//     final seconds = twoDigits(d.inSeconds.remainder(60));
//     return "$minutes:$seconds";
//   }
//
//   Widget _buildMessageInput() {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             blurRadius: 8,
//             offset: Offset(0, -2),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           if (_isReplying) _buildReplyingBar(),
//           if ((_selectedImageFile != null || _selectedImageBytes != null))
//             _buildImagePreview(),
//           Row(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.emoji_emotions, color: Colors.grey[600]),
//                 onPressed: () {
//                   setState(() => _showEmojiPicker = !_showEmojiPicker);
//                 },
//               ),
//               IconButton(
//                 icon: Icon(Icons.photo, color: Colors.grey[600]),
//                 onPressed: _pickImage,
//               ),
//               IconButton(
//                 icon: Icon(
//                   _isRecording ? Icons.stop : Icons.mic,
//                   color: _isRecording ? Colors.red : Colors.grey[600],
//                 ),
//                 onPressed: () {
//                   if (_isRecording) {
//                     _stopRecording(cancel: true); // Annuler l'enregistrement
//                   } else {
//                     _startRecording();
//                   }
//                 },
//               ),
//               Expanded(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     borderRadius: BorderRadius.circular(24),
//                   ),
//                   child: TextField(
//                     onChanged: (value) {
//                       setState(() {});
//                     },
//                     controller: _textController,
//                     focusNode: _focusNode,
//                     maxLines: null,
//                     style: TextStyle(color: Colors.black87),
//                     decoration: InputDecoration(
//                       hintText: _isRecording
//                           ? "Enregistrement... ($_recordingDuration s)"
//                           : "Écrire un message...",
//                       hintStyle: TextStyle(color: Colors.grey[400]),
//                       border: InputBorder.none,
//                       contentPadding: EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 10,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               SizedBox(width: 8),
//               Container(
//                 decoration: BoxDecoration(
//                   color: _canSend() ? primaryRed : Colors.grey[300],
//                   shape: BoxShape.circle,
//                 ),
//                 child: IconButton(
//                   icon: Icon(Icons.send, color: Colors.white, size: 20),
//                   onPressed: _canSend() ? _sendMessage : null,
//                 ),
//               ),
//             ],
//           ),
//           if (_showEmojiPicker)
//             SizedBox(
//               height: 250,
//               child: Stack(
//                 children: [
//                   EmojiPicker(
//                     onEmojiSelected: (category, emoji) {
//                       _textController.text += emoji.emoji;
//                       setState(() {});
//                     },
//                     // config: Config(
//                     //   columns: 7,
//                     //   emojiSizeMax: 32,
//                     //   bgColor: Colors.white,
//                     //   recentsLimit: 30,
//                     // ),
//                   ),
//                   Positioned(
//                     top: 4,
//                     right: 4,
//                     child: IconButton(
//                       icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
//                       onPressed: () => setState(() => _showEmojiPicker = false),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   bool _canSend() {
//     return (_textController.text.trim().isNotEmpty ||
//         _selectedImageFile != null ||
//         _selectedImageBytes != null ||
//         _isRecording) &&
//         !_isSendingImage &&
//         !_isSendingAudio;
//   }
//
//   Widget _buildReplyingBar() {
//     String previewText = '';
//     if (_replyingToMessage!.type == MessageType.text) {
//       previewText = _replyingToMessage!.text ?? '';
//     } else if (_replyingToMessage!.type == MessageType.image) {
//       previewText = '📷 Image';
//     } else if (_replyingToMessage!.type == MessageType.audio) {
//       previewText = '🎤 Audio';
//     } else {
//       previewText = 'Message';
//     }
//     return Container(
//       margin: EdgeInsets.only(bottom: 8),
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: secondaryGrey,
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.reply, color: primaryYellow, size: 16),
//           SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               previewText.length > 40
//                   ? '${previewText.substring(0, 40)}...'
//                   : previewText,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(color: Colors.white70, fontSize: 12),
//             ),
//           ),
//           IconButton(
//             icon: Icon(Icons.close, size: 16, color: Colors.white70),
//             onPressed: _clearReplying,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildImagePreview() {
//     ImageProvider image;
//     if (kIsWeb && _selectedImageBytes != null) {
//       image = MemoryImage(_selectedImageBytes!);
//     } else if (_selectedImageFile != null) {
//       image = FileImage(_selectedImageFile!);
//     } else {
//       return SizedBox.shrink();
//     }
//
//     return Container(
//       margin: EdgeInsets.only(bottom: 8),
//       child: Stack(
//         alignment: Alignment.topRight,
//         children: [
//           ClipRRect(
//             borderRadius: BorderRadius.circular(12),
//             child: Image(
//               image: image,
//               height: 100,
//               width: 100,
//               fit: BoxFit.cover,
//             ),
//           ),
//           IconButton(
//             icon: Container(
//               decoration: BoxDecoration(
//                 color: Colors.red,
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(Icons.close, size: 16, color: Colors.white),
//             ),
//             onPressed: () => setState(() {
//               _selectedImageFile = null;
//               _selectedImageBytes = null;
//             }),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: Colors.white,
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(color: primaryRed),
//               SizedBox(height: 16),
//               Text('Chargement...', style: TextStyle(color: Colors.grey[600])),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Row(
//           children: [
//             GestureDetector(
//               onTap: _goToProfile,
//               child: CircleAvatar(
//                 radius: 20,
//                 backgroundImage: _otherDatingProfile != null
//                     ? NetworkImage(_otherDatingProfile!.imageUrl)
//                     : NetworkImage(widget.otherUserImage),
//                 child: (widget.otherUserImage.isEmpty &&
//                     _otherDatingProfile?.imageUrl.isEmpty == true)
//                     ? Icon(Icons.person, size: 20)
//                     : null,
//               ),
//             ),
//             SizedBox(width: 12),
//             GestureDetector(
//               onTap: _goToProfile,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     widget.otherUserName,
//                     style: TextStyle(color: Colors.white, fontSize: 16),
//                   ),
//                   Text(
//                     'En ligne',
//                     style: TextStyle(color: Colors.white70, fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: primaryRed,
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.more_vert, color: Colors.white),
//             onPressed: () => _showProfileOptions(),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: _firestore
//                   .collection('dating_messages')
//                   .where('conversationId', isEqualTo: _conversationId)
//                   .orderBy('createdAt', descending: false)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.hasError) {
//                   print('Erreur: ${snapshot.error}');
//                   return Center(child: Text('Erreur: ${snapshot.error}'));
//                 }
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator());
//                 }
//
//                 final docs = snapshot.data?.docs ?? [];
//                 final newMessages = docs
//                     .map((doc) => DatingMessage.fromJson(doc.data() as Map<String, dynamic>))
//                     .toList();
//
//                 if (newMessages.length != _messages.length) {
//                   _messages = newMessages;
//                   _markMessagesAsRead();
//                   _scrollToBottom();
//                 }
//
//                 if (_messages.isEmpty) {
//                   return Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.chat_bubble_outline,
//                           size: 80,
//                           color: Colors.grey.shade400,
//                         ),
//                         SizedBox(height: 16),
//                         Text(
//                           'Aucun message',
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                         SizedBox(height: 8),
//                         Text(
//                           'Envoyez un message pour commencer la conversation',
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Colors.grey.shade500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
//
//                 return ListView.builder(
//                   controller: _scrollController,
//                   padding: EdgeInsets.all(16),
//                   itemCount: _messages.length,
//                   itemBuilder: (context, index) {
//                     final message = _messages[index];
//                     final isMe = message.senderUserId == _currentUserId;
//                     return _buildMessageBubble(message, isMe);
//                   },
//                 );
//               },
//             ),
//           ),
//           _buildMessageInput(),
//         ],
//       ),
//     );
//   }
//
//   void _showProfileOptions() {
//     showModalBottomSheet(
//       context: context,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: Icon(Icons.person, color: primaryRed),
//               title: Text('Voir le profil'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _goToProfile();
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.block, color: primaryRed),
//               title: Text('Bloquer'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showBlockConfirmation();
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.flag, color: primaryRed),
//               title: Text('Signaler'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showReportDialog();
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _showBlockConfirmation() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Text('Bloquer ${widget.otherUserName}'),
//         content: Text(
//           'Êtes-vous sûr de vouloir bloquer cet utilisateur ? '
//               'Vous ne pourrez plus voir son profil ni recevoir ses messages.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Annuler'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               await _blockUser();
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
//             child: Text('Bloquer'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _blockUser() async {
//     try {
//       final blockId = _firestore.collection('dating_blocks').doc().id;
//       final now = DateTime.now().millisecondsSinceEpoch;
//
//       await _firestore.collection('dating_blocks').doc(blockId).set({
//         'id': blockId,
//         'blockerUserId': _currentUserId,
//         'blockedUserId': widget.otherUserId,
//         'createdAt': now,
//       });
//
//       _showSnackBar('${widget.otherUserName} a été bloqué', Colors.red);
//       Navigator.pop(context);
//     } catch (e) {
//       _showSnackBar('Erreur lors du blocage', Colors.red);
//     }
//   }
//
//   void _showReportDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Text('Signaler ${widget.otherUserName}'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Pourquoi signalez-vous cette conversation ?'),
//             SizedBox(height: 16),
//             ...['Message inapproprié', 'Harcèlement', 'Spam', 'Contenu offensant', 'Autre']
//                 .map((reason) => ListTile(
//               title: Text(reason),
//               onTap: () {
//                 Navigator.pop(context);
//                 _submitReport(reason);
//               },
//             ))
//                 .toList(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _submitReport(String reason) async {
//     try {
//       final reportId = _firestore.collection('dating_reports').doc().id;
//       final now = DateTime.now().millisecondsSinceEpoch;
//
//       await _firestore.collection('dating_reports').doc(reportId).set({
//         'id': reportId,
//         'reporterUserId': _currentUserId,
//         'targetUserId': widget.otherUserId,
//         'reason': reason,
//         'description': '',
//         'createdAt': now,
//       });
//
//       _showSnackBar('Signalement envoyé', Colors.green);
//     } catch (e) {
//       _showSnackBar('Erreur lors du signalement', Colors.red);
//     }
//   }
// }