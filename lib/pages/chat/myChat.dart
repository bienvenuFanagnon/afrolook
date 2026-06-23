import 'dart:convert';
import 'dart:io';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/models/chatmodels/models.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constant/constColors.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../constant/sizeText.dart';
import '../../constant/textCustom.dart';
import '../../models/enums.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../home/user_presence_widget.dart';
import '../user/detailsOtherUser.dart';
import '../../services/utils/abonnement_utils.dart';
import '../../widgets/user_badge_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:cryptography/cryptography.dart';

import '../userPosts/postWidgets/postUserWidget.dart';
import '../../services/chat_cache_service.dart';
import '../../services/encryption_service.dart';
import '../../widgets/chat/chat_bubble_widget.dart';
import 'package:share_plus/share_plus.dart';

import '../user/privacy_settings_page.dart';
import 'chat_media_gallery_page.dart';
import '../afroshop/marketPlace/acceuil/produit_details.dart';
import '../contenuPayant/contentDetails.dart';
import '../postDetails.dart';
import '../post_video_format_tel_details.dart';
import '../LiveAgora/livesAgora.dart';
import '../LiveAgora/livePage.dart';
import '../LiveAgora/live_ended_page.dart';

class MyChat extends StatefulWidget {
  final String title;
  final Chat chat;

  MyChat({Key? key, required this.title, required this.chat}) : super(key: key);

  @override
  _MyChatState createState() => _MyChatState();
}

class _MyChatState extends State<MyChat> with WidgetsBindingObserver {
  late AppColors _colors;

  // Variables d'état
  bool _replying = false;
  Message? _replyingToMessage;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Gestion des fichiers
  File? _image;
  List<File> _multiImages = [];
  bool _isSendingMultiImages = false;
  final ImagePicker _picker = ImagePicker();

  // Emoji picker
  bool _showEmojiPicker = false;

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

  // Scroll vers message répondu
  String? _highlightedMessageId;

  // Messages éphémères — durée en secondes (0 = désactivé)
  int _ephemeralDuration = 0;
  Timer? _ephemeralTimer;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Providers
  late UserAuthProvider _authProvider;
  late UserProvider _userProvider;

  // Streams et données
  Stream<List<Message>>? _messagesStream;
  List<Message> _messages = [];
  /// Derniers messages reçus via le flux Firestore (fenêtre limitée).
  List<Message> _streamMessages = [];
  /// Messages plus anciens chargés via pagination (scroll vers le haut).
  List<Message> _olderMessages = [];
  bool _isLoading = true;
  bool _hasNewMessage = false;

  // Pagination (chargement des messages plus anciens)
  static const int _pageSize = 30;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  // Marquage "lu" en batch (au lieu d'une écriture par message dans le build)
  Timer? _readReceiptDebounce;

  // Typing indicator — debounce 3s avant de passer à NOTSENDING
  Timer? _typingDebounce;
  bool _isSendingTyping = false;

  /// Clé AES-256 dérivée pour cette conversation (chiffrement au repos).
  /// Si `null` après init, l'envoi de texte est bloqué jusqu'à résolution.
  SecretKey? _chatKey;

  // Blocage utilisateur
  late String _otherId;
  bool _isBlockedByMe = false;
  bool _isBlockedByOther = false;

  // Confidentialité — paramètre personnel
  bool _hideReadReceipts = false;

  // Pour éviter les reconstructions inutiles
  final _messageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);

    _otherId = widget.chat.senderId == _authProvider.loginUserData.id!
        ? widget.chat.receiverId!
        : widget.chat.senderId!;

    _audioRecorder = AudioRecorder();
    _initializeChat();
    _setupAudioListener();
    _loadCachedMessages();
    _loadMessages();
    _tryLoadOldEncryptionKey();
    _loadBlockStatus();
    _loadMyPrivacySettings();
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);

    // Scroll vers le bas après initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  /// Affiche immédiatement les derniers messages mis en cache localement
  /// (style WhatsApp : pas d'écran vide pendant la reconnexion à Firestore).
  Future<void> _loadCachedMessages() async {
    final cached = await ChatCacheService.loadMessages(widget.chat.docId!);
    if (cached.isEmpty || !mounted) return;

    setState(() {
      _messages = cached;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  /// Charge plus de messages (plus anciens) quand l'utilisateur remonte en
  /// haut de la conversation.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      final oldest = _messages.first;
      final snapshot = await _firestore
          .collection('Messages')
          .where('chat_id', isEqualTo: widget.chat.docId!)
          .where('is_valide', isEqualTo: true)
          .orderBy('createdAt', descending: false)
          .where('createdAt', isLessThan: oldest.createdAt)
          .limitToLast(_pageSize)
          .get();

      final older = snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList();
      await _decryptMessages(older);

      if (older.isEmpty) {
        _hasMoreMessages = false;
      } else {
        final prevMaxExtent = _scrollController.position.maxScrollExtent;
        final prevPixels = _scrollController.position.pixels;

        _olderMessages = [...older, ..._olderMessages];
        _hasMoreMessages = older.length == _pageSize;

        setState(() {
          _messages = _mergeMessages();
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final newMaxExtent = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(prevPixels + (newMaxExtent - prevMaxExtent));
        });
      }
    } catch (e) {
      printVm('⚠️ Erreur chargement messages plus anciens: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Fusionne les messages chargés par pagination avec la fenêtre récente du
  /// flux Firestore, en dédupliquant par id et en triant chronologiquement.
  List<Message> _mergeMessages() {
    final Map<String, Message> byId = {};
    for (final m in _olderMessages) {
      byId[m.id] = m;
    }
    for (final m in _streamMessages) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.create_at_time_spam.compareTo(b.create_at_time_spam));
    return merged;
  }

  /// Marque en une seule écriture batch tous les messages reçus non encore
  /// lus (au lieu d'écrire un par un pendant le build de la liste).
  void _scheduleReadReceipts(List<Message> messages) {
    // Si l'utilisateur a activé "Masquer les accusés de lecture", on ne révèle
    // pas qu'on a lu les messages de l'autre (double coche reste grise).
    if (_hideReadReceipts) return;

    final currentUserId = _authProvider.loginUserData.id;
    final unread = messages.where((m) =>
        m.sendBy != currentUserId && m.message_state != MessageState.LU.name).toList();

    if (unread.isEmpty) return;

    _readReceiptDebounce?.cancel();
    _readReceiptDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final batch = _firestore.batch();
        for (final m in unread) {
          m.message_state = MessageState.LU.name;
          batch.update(_firestore.collection('Messages').doc(m.id), {
            'message_state': MessageState.LU.name,
          });
        }
        await batch.commit();
      } catch (e) {
        printVm('⚠️ Erreur marquage messages lus: $e');
      }
    });
  }

  void _initializeChat() {
    if (widget.chat.senderId != _authProvider.loginUserData.id!) {
      widget.chat.your_msg_not_read = 0;
    } else {
      widget.chat.my_msg_not_read = 0;
    }
    _firestore.collection('Chats').doc(widget.chat.id).update(widget.chat.toJson());
    _loadEphemeralSettings();
  }

  Future<void> _loadEphemeralSettings() async {
    try {
      final doc = await _firestore.collection('Chats').doc(widget.chat.id).get();
      final dur = (doc.data()?['ephemeral_duration'] as int?) ?? 0;
      if (mounted) {
        setState(() => _ephemeralDuration = dur);
        if (dur > 0) _startEphemeralTimer();
      }
    } catch (_) {}
  }

  void _startEphemeralTimer() {
    _ephemeralTimer?.cancel();
    _ephemeralTimer = Timer.periodic(const Duration(seconds: 10), (_) => _expireMessages());
  }

  Future<void> _expireMessages() async {
    if (_ephemeralDuration == 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = _messages.where((m) {
      final expiresAt = m.expires_at ?? 0;
      return expiresAt > 0 && now >= expiresAt;
    }).toList();

    if (expired.isEmpty) return;

    final batch = _firestore.batch();
    for (final m in expired) {
      batch.update(_firestore.collection('Messages').doc(m.id), {
        'is_valide': false,
        'deleted_at': now,
        'deleted_by': 'system_ephemeral',
        'delete_scope': 'all',
      });
    }
    await batch.commit();
  }

  void _showEphemeralPicker() {
    final options = [
      {'label': 'Désactivé', 'value': 0},
      {'label': '30 secondes', 'value': 30},
      {'label': '5 minutes', 'value': 300},
      {'label': '1 heure', 'value': 3600},
      {'label': '24 heures', 'value': 86400},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: _colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _colors.border.withOpacity(0.3)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Durée des messages éphémères',
                  style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ...options.map((opt) {
                final isSelected = _ephemeralDuration == opt['value'] as int;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? _colors.primary : _colors.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    opt['label'] as String,
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newDuration = opt['value'] as int;
                    setState(() => _ephemeralDuration = newDuration);
                    if (newDuration > 0) {
                      _startEphemeralTimer();
                    } else {
                      _ephemeralTimer?.cancel();
                    }
                    await _firestore.collection('Chats').doc(widget.chat.id).update({
                      'ephemeral_duration': newDuration,
                    });
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Tente de récupérer la clé des anciens messages chiffrés (best-effort).
  /// N'est plus nécessaire pour les nouveaux messages.
  Future<void> _tryLoadOldEncryptionKey() async {
    try {
      final myId = _authProvider.loginUserData.id!;
      final otherId = widget.chat.senderId == myId
          ? widget.chat.receiverId!
          : widget.chat.senderId!;
      _chatKey = await EncryptionService.getChatKey(widget.chat.docId!, myId, otherId);
    } catch (_) {}
  }

  /// Déchiffre les anciens messages qui portent encore is_encrypted=true.
  Future<void> _decryptMessages(List<Message> messages) async {
    final key = _chatKey;
    if (key == null) return;

    for (final m in messages) {
      if (m.is_encrypted) {
        try {
          m.message = await EncryptionService.decryptText(key, m.message);
        } catch (_) {}
      }
    }
  }

  void _loadMessages() {
    // On ne s'abonne qu'aux [_pageSize] derniers messages : on évite ainsi
    // de retélécharger tout l'historique de la conversation à chaque
    // ouverture/écriture. Les messages plus anciens sont chargés via
    // pagination (`_loadMoreMessages`) quand l'utilisateur remonte.
    _messagesStream = _firestore
        .collection('Messages')
        .where('chat_id', isEqualTo: widget.chat.docId!)
        .where('is_valide', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .limitToLast(_pageSize)
        .snapshots()
        .asyncMap((snapshot) async {
      final messages = snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList();
      await _decryptMessages(messages);
      return messages;
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

  void _scrollToMessage(String messageId) {
    final ctx = GlobalObjectKey(messageId).currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
    setState(() => _highlightedMessageId = messageId);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  // ── Typing indicator ────────────────────────────────────────────────────────

  void _onTextChanged() {
    if (_textController.text.trim().isEmpty) {
      _typingDebounce?.cancel();
      _clearTypingState();
    } else {
      _setTypingState();
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 3), _clearTypingState);
    }
  }

  Future<void> _setTypingState() async {
    if (_isSendingTyping) return;
    _isSendingTyping = true;
    try {
      final myId = _authProvider.loginUserData.id!;
      final field = widget.chat.senderId == myId ? 'send_sending' : 'receiver_sending';
      await _firestore.collection('Chats').doc(widget.chat.id).update({field: 'SENDING'});
    } catch (_) {}
  }

  /// Retourne le timestamp d'expiration du message si un mode éphémère est actif,
  /// sinon null.
  int? get _messageExpiresAt {
    if (_ephemeralDuration <= 0) return null;
    return DateTime.now().millisecondsSinceEpoch + (_ephemeralDuration * 1000);
  }

  Future<void> _clearTypingState() async {
    _isSendingTyping = false;
    try {
      final myId = _authProvider.loginUserData.id!;
      final field = widget.chat.senderId == myId ? 'send_sending' : 'receiver_sending';
      await _firestore.collection('Chats').doc(widget.chat.id).update({field: 'NOTSENDING'});
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _audioRecorder?.dispose();
    _recordingTimer?.cancel();
    _readReceiptDebounce?.cancel();
    _typingDebounce?.cancel();
    _ephemeralTimer?.cancel();
    _clearTypingState();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  // Méthodes utilitaires
  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  /// Heure au format HH:mm (façon WhatsApp), affichée sous chaque message.
  String _formatMessageTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Libellé du séparateur de date (Aujourd'hui / Hier / date complète).
  String _formatDateSeparator(DateTime dateTime, AppLocalizations l10n) {
    final now = DateTime.now();
    if (_isSameDay(dateTime, now)) return l10n.chatToday;

    final yesterday = now.subtract(Duration(days: 1));
    if (_isSameDay(dateTime, yesterday)) return l10n.chatYesterday;

    return DateFormat('dd/MM/yyyy').format(dateTime);
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
          _multiImages.clear();
          _showEmojiPicker = false;
        });
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de la sélection de l'image");
    }
  }

  /// Sélection multiple d'images (jusqu'à 3) — réservé Premium.
  Future<void> _getMultipleImages() async {
    final isPremium = _authProvider.loginUserData.abonnement?.estPremium == true;
    if (!isPremium) {
      _showPremiumGate('Envoyer plusieurs images est réservé aux membres Premium 👑');
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(limit: 3);
      if (picked.isNotEmpty) {
        setState(() {
          _multiImages = picked.map((x) => File(x.path)).toList();
          _image = null;
          _showEmojiPicker = false;
        });
      }
    } catch (e) {
      _showErrorSnackbar("Erreur lors de la sélection des images");
    }
  }

  void _showPremiumGate(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a0a2a), Color(0xFF2a1a3a)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDB813).withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('Fonctionnalité Premium',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDB813),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/abonnement');
              },
              child: const Text('Passer à Premium', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMultipleImagesMessage() async {
    if (_multiImages.isEmpty) return;
    setState(() => _isSendingMultiImages = true);

    try {
      final urls = <String>[];
      for (final img in _multiImages) {
        final ref = FirebaseStorage.instance.ref().child(
            'chat_images/${Path.basename(img.path)}_${DateTime.now().millisecondsSinceEpoch}');
        final snap = await ref.putFile(img);
        urls.add(await snap.ref.getDownloadURL());
      }

      final replyMsg = _replyingToMessage != null ? _getReplyMessageText(_replyingToMessage!) : '';
      final reply = ReplyMessage(
        message: replyMsg,
        messageType: _replyingToMessage?.messageType ?? '',
        messageId: _replyingToMessage?.id ?? '',
      );

      final msg = Message(
        id: '',
        createdAt: DateTime.now(),
        message: urls.first,
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
        expires_at: _messageExpiresAt,
        // Stocker les URLs supplémentaires dans imageText séparées par |
        imageText: urls.length > 1 ? urls.join('|') : null,
      );

      _updateChatCounters('📷 ${urls.length} photos');
      final msgId = _firestore.collection('Messages').doc().id;
      msg.id = msgId;
      await _firestore.collection('Messages').doc(msgId).set(msg.toJson());
      await _sendNotification('📷 ${urls.length} photos');
      await _resetAfterMessage();
    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'envoi des images");
    } finally {
      if (mounted) setState(() { _isSendingMultiImages = false; _multiImages.clear(); });
    }
  }

  // Widget Audio compact avec waveform
  Widget _buildCompactAudioPlayer(Message message, bool isMe) {
    final isCurrentPlaying = _currentPlayingMessageId == message.id;
    return AudioBubble(
      message: message,
      isMe: isMe,
      audioPlayer: _audioPlayer,
      currentPlayingId: _currentPlayingMessageId,
      isPlaying: isCurrentPlaying && _isAudioPlaying,
      isLoading: isCurrentPlaying && _isAudioLoading,
      position: isCurrentPlaying ? _currentAudioPosition : Duration.zero,
      duration: isCurrentPlaying ? _currentAudioDuration : Duration.zero,
      onToggle: () => _toggleAudio(message),
      onSeek: (v) => _seekAudio(v),
      onLongPress: () => _showMessageOptions(message),
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
      printVm("Erreur audio: $e");
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
        expires_at: _messageExpiresAt,
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
        expires_at: _messageExpiresAt,
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
        expires_at: _messageExpiresAt,
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
    if (_isSendingImage || _isSendingAudio || _isSendingMultiImages) return;

    if (_multiImages.isNotEmpty) {
      _sendMultipleImagesMessage();
    } else if (_image != null) {
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
      printVm("Erreur notification: $e");
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
          backgroundColor: _colors.background,
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
  Widget _buildMessageBubble(Message message, bool isLastItem, bool isFirstInGroup, bool isLastInGroup) {
    final isMe = message.sendBy == _authProvider.loginUserData.id!;

    return Container(
      margin: EdgeInsets.only(top: isFirstInGroup ? 8 : 1, bottom: 1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe)
                Container(
                  width: 28,
                  height: 28,
                  margin: EdgeInsets.only(right: 8, bottom: 16),
                  child: isLastInGroup
                      ? _buildUserAvatar(message.sendBy)
                      : const SizedBox.shrink(),
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
          SizedBox(height: isLastItem ? 80 : 0),
        ],
      ),
    );
  }

  /// Séparateur de date entre deux groupes de messages (façon WhatsApp).
  Widget _buildDateSeparator(DateTime date) {
    final l10n = AppLocalizations.of(context);
    return ChatDateSeparator(label: _formatDateSeparator(date, l10n));
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
      case 'post':
        return PostBubble(
          message: message,
          isMe: isMe,
          onLongPress: () => _showMessageOptions(message),
          onTap: () => _openSharedPost(message.id),
        );
      case 'link_share':
        return _buildLinkShareBubble(message, isMe);
      default:
        return _buildTextMessage(message, isMe);
    }
  }

  Widget _buildLinkShareBubble(Message message, bool isMe) {
    final title = message.message;
    final thumbnail = message.imageText ?? '';
    final itemType = message.itemType ?? '';
    final isLive = itemType == 'live';

    IconData icon;
    String typeLabel;
    String actionLabel;
    Color typeColor;
    switch (itemType) {
      case 'live':
        icon = Icons.live_tv_rounded;
        typeLabel = '● LIVE';
        actionLabel = 'Visiter le live';
        typeColor = Colors.redAccent;
        break;
      case 'product':
        icon = Icons.shopping_bag_outlined;
        typeLabel = 'Produit';
        actionLabel = 'Voir le produit';
        typeColor = isMe ? Colors.white70 : _colors.primary;
        break;
      case 'vip':
        icon = Icons.star_rounded;
        typeLabel = 'Contenu VIP';
        actionLabel = 'Voir le contenu';
        typeColor = const Color(0xFFF9A825);
        break;
      default:
        icon = Icons.link_rounded;
        typeLabel = 'Lien partagé';
        actionLabel = 'Appuyer pour voir';
        typeColor = isMe ? Colors.white70 : _colors.primary;
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      onTap: () => _openSharedItem(message.id),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 60 : 12, right: isMe ? 12 : 60,
            top: 3, bottom: 3,
          ),
          constraints: const BoxConstraints(maxWidth: 230),
          decoration: BoxDecoration(
            color: isMe ? _colors.primary : _colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: isMe ? null : Border.all(color: _colors.border.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail ou placeholder live
              if (thumbnail.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: Image.network(thumbnail, height: 120, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                    if (isLive)
                      Positioned(
                        top: 6, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                )
              else if (isLive)
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.live_tv_rounded, color: Colors.redAccent, size: 24),
                        const SizedBox(width: 6),
                        const Text('● LIVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 12, color: typeColor),
                        const SizedBox(width: 4),
                        Text(typeLabel,
                            style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title.length > 60 ? '${title.substring(0, 60)}…' : title,
                      style: TextStyle(color: isMe ? Colors.white : _colors.textPrimary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(actionLabel,
                        style: TextStyle(color: isMe ? Colors.white60 : _colors.textSecondary, fontSize: 10, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSharedItem(String messageId) async {
    try {
      final doc = await _firestore.collection('Messages').doc(messageId).get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      final itemType = data['item_type'] as String? ?? '';
      final itemId = data['item_id'] as String? ?? '';
      if (itemId.isEmpty) return;

      switch (itemType) {
        case 'product':
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProduitDetail(productId: itemId)));
          break;
        case 'vip':
          final contentDoc = await _firestore.collection('ContentPaie').doc(itemId).get();
          if (!contentDoc.exists || !mounted) return;
          final content = ContentPaie.fromJson(contentDoc.data()!);
          Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailScreen(content: content)));
          break;
        case 'live':
          final liveDoc = await _firestore.collection('lives').doc(itemId).get();
          if (!liveDoc.exists || !mounted) return;
          final live = PostLive.fromMap(liveDoc.data()!);
          if (live.isLive) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => LivePage(
                liveId: itemId,
                postLive: live,
                isHost: false,
                isInvited: false,
                hostName: live.hostName ?? '',
                hostImage: live.hostImage ?? '',
              ),
            ));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => LiveEndedPage(live: live)));
          }
          break;
      }
    } catch (_) {}
  }

  Future<void> _openSharedPost(String messageId) async {
    try {
      final msgDoc = await _firestore.collection('Messages').doc(messageId).get();
      if (!msgDoc.exists || !mounted) return;
      final data = msgDoc.data()!;
      final postId = data['post_id'] as String?;
      final dataType = data['post_data_type'] as String? ?? 'IMAGE';
      if (postId == null || postId.isEmpty) return;

      final postDoc = await _firestore.collection('Posts').doc(postId).get();
      if (!postDoc.exists || !mounted) return;
      final post = Post.fromJson(postDoc.data()!);

      if (dataType == 'VIDEO') {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PostDetailsVideoFormatTel(initialPost: post),
        ));
      } else {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetailsPost(post: post),
        ));
      }
    } catch (e) {
      printVm('Erreur ouverture post partage: $e');
    }
  }

  Widget _buildTextMessage(Message message, bool isMe) {
    // Message chiffré non déchiffré (clé absente) → afficher un indicateur visuel
    if (message.is_encrypted == true && message.message.startsWith('enc:v1:')) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 60 : 12, right: isMe ? 12 : 60, top: 3, bottom: 3,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? _colors.primary.withOpacity(0.85) : _colors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 14,
                  color: isMe ? Colors.white70 : _colors.textSecondary),
              const SizedBox(width: 4),
              Text('Message ancien non disponible',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isMe ? Colors.white70 : _colors.textSecondary,
                  )),
            ],
          ),
        ),
      );
    }
    return TextBubble(
      message: message,
      isMe: isMe,
      onLongPress: () => _showMessageOptions(message),
      onTapReply: message.replyMessage.messageId.isNotEmpty
          ? () => _scrollToMessage(message.replyMessage.messageId)
          : null,
    );
  }

  Widget _buildImageMessage(Message message, bool isMe) {
    // Détecter multi-images (URLs séparées par |)
    final raw = message.imageText ?? '';
    if (raw.contains('|')) {
      final urls = [message.message, ...raw.split('|').where((u) => u.isNotEmpty)];
      return MultiImageBubble(
        urls: urls,
        message: message,
        isMe: isMe,
        onTapImage: _showImageFullScreen,
        onLongPress: () => _showMessageOptions(message),
      );
    }
    return ImageBubble(
      message: message,
      isMe: isMe,
      onTap: () => _showImageFullScreen(message.message),
      onLongPress: () => _showMessageOptions(message),
    );
  }

  Widget _buildMessageStatus(Message message, bool isMe) {
    // Le statut est désormais rendu dans chaque bulle custom via MessageMeta.
    // On garde cette méthode vide pour compatibilité avec _buildMessageBubble.
    return const SizedBox.shrink();
  }

  void _showMessageOptions(Message message) {
    final isMe = message.sendBy == _authProvider.loginUserData.id!;
    final isText = message.messageType == MessageType.text.name;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          decoration: BoxDecoration(
            color: _colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _colors.border.withOpacity(0.3)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle visuel
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Aperçu du message (texte uniquement, tronqué)
                if (isText && message.message.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _colors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      message.message.length > 60
                          ? '${message.message.substring(0, 60)}…'
                          : message.message,
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Répondre
                _optionTile(
                  ctx,
                  icon: Icons.reply_rounded,
                  iconColor: _colors.primary,
                  label: AppLocalizations.of(context).btnReply,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replying = true;
                      _replyingToMessage = message;
                    });
                    _focusNode.requestFocus();
                  },
                ),
                // Copier le texte (si c'est du texte)
                if (isText)
                  _optionTile(
                    ctx,
                    icon: Icons.copy_rounded,
                    iconColor: Colors.blueGrey,
                    label: 'Copier le texte',
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: message.message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Texte copié', textAlign: TextAlign.center),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.blueGrey,
                        ),
                      );
                    },
                  ),
                // Signaler (messages reçus uniquement)
                if (!isMe) ...[
                  Divider(color: _colors.border.withOpacity(0.4), height: 1, indent: 16, endIndent: 16),
                  _optionTile(
                    ctx,
                    icon: Icons.flag_outlined,
                    iconColor: Colors.orange,
                    label: 'Signaler ce message',
                    labelColor: Colors.orange,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showReportSheet(message);
                    },
                  ),
                ],
                // Supprimer pour tous (expéditeur uniquement)
                if (isMe) ...[
                  Divider(color: _colors.border.withOpacity(0.4), height: 1, indent: 16, endIndent: 16),
                  _optionTile(
                    ctx,
                    icon: Icons.delete_outline_rounded,
                    iconColor: Colors.red,
                    label: 'Supprimer pour tous',
                    labelColor: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeleteMessage(message);
                    },
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _optionTile(
    BuildContext ctx, {
    required IconData icon,
    required Color iconColor,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? _colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  /// Dialog de confirmation avant suppression — évite les suppressions accidentelles.
  void _confirmDeleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer ce message ?',
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Ce message sera supprimé pour vous et votre interlocuteur.',
          style: TextStyle(color: _colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage(message);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Suppression logique d'un message avec traçabilité complète.
  /// Écriture Firestore directe — on n'utilise pas le modèle pour éviter
  /// de modifier Message (champs deleted_at / deleted_by / delete_scope absents du modèle).
  Future<void> _deleteMessage(Message message) async {
    final msgId = message.id;
    if (msgId == null || msgId.isEmpty) return;

    try {
      await _firestore.collection('Messages').doc(msgId).update({
        'is_valide': false,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'deleted_by': _authProvider.loginUserData.id!,
        'delete_scope': 'all',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Message supprimé', textAlign: TextAlign.center),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ _deleteMessage error ($msgId): $e');
      _showErrorSnackbar('Erreur lors de la suppression');
    }
  }

  /// Bottom sheet de choix de motif de signalement.
  void _showReportSheet(Message message) {
    final reasons = [
      ('spam', 'Spam', Icons.mark_email_unread_outlined),
      ('harassment', 'Harcèlement ou menaces', Icons.warning_amber_rounded),
      ('inappropriate', 'Contenu inapproprié', Icons.no_adult_content),
      ('other', 'Autre', Icons.help_outline_rounded),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          decoration: BoxDecoration(
            color: _colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _colors.border.withOpacity(0.3)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'Pourquoi signalez-vous ce message ?',
                    style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                ...reasons.map((r) {
                  final (key, label, icon) = r;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: Icon(icon, color: Colors.orange, size: 22),
                    title: Text(label, style: TextStyle(color: _colors.textPrimary, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _reportMessage(message, key);
                    },
                  );
                }),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Enregistre le signalement dans la collection `Reports`.
  /// Écriture Firestore directe — collection admin-only côté client.
  /// `createdAt` en millisecondes (cohérence avec le reste du projet).
  Future<void> _reportMessage(Message message, String reason) async {
    final myId = _authProvider.loginUserData.id!;
    final msgId = message.id;
    if (msgId.isEmpty) return;

    // ID = messageId_userId → un seul signalement par utilisateur par message
    final reportId = '${msgId}_$myId';

    try {
      await _firestore.collection('Reports').doc(reportId).set({
        'reportedBy': myId,
        'messageId': msgId,
        'chatId': widget.chat.docId!,
        'reason': reason,
        'reportedUserId': message.sendBy,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Signalement envoyé. Merci.', textAlign: TextAlign.center),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ _reportMessage error ($msgId): $e');
      if (!mounted) return;
      _showErrorSnackbar('Erreur lors du signalement');
    }
  }

  // ── Blocage utilisateur ─────────────────────────────────────────────────────

  /// Vérifie les deux directions de blocage au chargement du chat.
  Future<void> _loadBlockStatus() async {
    final myId = _authProvider.loginUserData.id!;
    final blockByMe = '${myId}_$_otherId';
    final blockByOther = '${_otherId}_$myId';

    try {
      final results = await Future.wait([
        _firestore.collection('BlockedUsers').doc(blockByMe).get(),
        _firestore.collection('BlockedUsers').doc(blockByOther).get(),
      ]);

      if (!mounted) return;
      setState(() {
        _isBlockedByMe    = results[0].exists;
        _isBlockedByOther = results[1].exists;
      });
    } catch (e) {
      debugPrint('⚠️ _loadBlockStatus error: $e');
    }
  }

  Future<void> _loadMyPrivacySettings() async {
    final myId = _authProvider.loginUserData.id!;
    try {
      final doc = await _firestore.collection('Users').doc(myId).get();
      final privacy = (doc.data()?['privacySettings'] as Map<String, dynamic>?) ?? {};
      if (mounted) setState(() => _hideReadReceipts = privacy['hideReadReceipts'] == true);
    } catch (e) {
      debugPrint('⚠️ _loadMyPrivacySettings error: $e');
    }
  }

  /// Bloque l'autre utilisateur : crée le document `BlockedUsers/${myId}_${otherId}`.
  Future<void> _blockUser() async {
    final myId = _authProvider.loginUserData.id!;
    final docId = '${myId}_$_otherId';

    try {
      await _firestore.collection('BlockedUsers').doc(docId).set({
        'blockedBy': myId,
        'blockedUser': _otherId,
        'chatId': widget.chat.docId!,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      setState(() => _isBlockedByMe = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.grey[800],
          content: Text(
            '@${widget.chat.receiver?.pseudo ?? _otherId} a été bloqué',
            textAlign: TextAlign.center,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ _blockUser error: $e');
      _showErrorSnackbar('Erreur lors du blocage');
    }
  }

  /// Débloque l'autre utilisateur : supprime le document `BlockedUsers/${myId}_${otherId}`.
  Future<void> _unblockUser() async {
    final myId = _authProvider.loginUserData.id!;
    final docId = '${myId}_$_otherId';

    try {
      await _firestore.collection('BlockedUsers').doc(docId).delete();

      if (!mounted) return;
      setState(() => _isBlockedByMe = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            '@${widget.chat.receiver?.pseudo ?? _otherId} a été débloqué',
            textAlign: TextAlign.center,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ _unblockUser error: $e');
      _showErrorSnackbar('Erreur lors du déblocage');
    }
  }

  /// Menu contextuel de la conversation (bouton ⋮ dans l'AppBar).
  void _showChatMenu() {
    final pseudo = widget.chat.receiver?.pseudo ?? _otherId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          decoration: BoxDecoration(
            color: _colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _colors.border.withOpacity(0.3)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
                ),
                // Médias partagés
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(Icons.photo_library_outlined, color: _colors.primary, size: 22),
                  title: Text(
                    'Médias partagés',
                    style: TextStyle(color: _colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatMediaGalleryPage(
                          chatId: widget.chat.docId!,
                          chatTitle: widget.title,
                        ),
                      ),
                    );
                  },
                ),
                Divider(color: _colors.border.withOpacity(0.4), height: 1, indent: 16, endIndent: 16),
                // Confidentialité — paramètres de l'utilisateur connecté
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(Icons.shield_outlined, color: _colors.primary, size: 22),
                  title: Text(
                    'Ma confidentialité',
                    style: TextStyle(color: _colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacySettingsPage()),
                    );
                  },
                ),
                Divider(color: _colors.border.withOpacity(0.4), height: 1, indent: 16, endIndent: 16),
                // Inviter sur Afrolook
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(Icons.person_add_rounded, color: _colors.primary, size: 22),
                  title: Text(
                    'Inviter sur Afrolook',
                    style: TextStyle(color: _colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Share.share(
                      'Rejoins-moi sur Afrolook 🌍 — la plateforme mode & lifestyle africaine !\n'
                      'Télécharge l\'app : https://afrolook.app',
                      subject: 'Invitation Afrolook',
                    );
                  },
                ),
                Divider(color: _colors.border.withOpacity(0.4), height: 1, indent: 16, endIndent: 16),
                // Messages éphémères — Premium
                Builder(builder: (ctx2) {
                  final isPremium = _authProvider.loginUserData.abonnement?.estPremium == true;
                  final labels = {0: 'Désactivé', 30: '30 secondes', 300: '5 minutes', 3600: '1 heure', 86400: '24 heures'};
                  final currentLabel = labels[_ephemeralDuration] ?? 'Désactivé';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: Icon(Icons.timer_outlined, color: isPremium ? _colors.primary : Colors.grey, size: 22),
                    title: Text(
                      'Messages éphémères',
                      style: TextStyle(color: _colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      isPremium ? currentLabel : '👑 Premium',
                      style: TextStyle(color: isPremium ? _colors.textSecondary : Colors.amber, fontSize: 12),
                    ),
                    onTap: isPremium ? () {
                      Navigator.pop(ctx);
                      _showEphemeralPicker();
                    } : null,
                  );
                }),
                Divider(color: _colors.border.withOpacity(0.4), height: 1, indent: 16, endIndent: 16),
                // Bloquer / Débloquer
                if (_isBlockedByMe)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: const Icon(Icons.lock_open_rounded, color: Colors.green, size: 22),
                    title: Text(
                      'Débloquer @$pseudo',
                      style: TextStyle(color: _colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _unblockUser();
                    },
                  )
                else
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: const Icon(Icons.block_rounded, color: Colors.red, size: 22),
                    title: Text(
                      'Bloquer @$pseudo',
                      style: const TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmBlockUser(pseudo);
                    },
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Confirmation avant de bloquer (action irréversible visible).
  void _confirmBlockUser(String pseudo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Bloquer @$pseudo ?',
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Cette personne ne pourra plus vous envoyer de messages. Vous pouvez la débloquer à tout moment.',
          style: TextStyle(color: _colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _blockUser();
            },
            child: const Text('Bloquer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Bannière affichée au-dessus de l'input quand la conversation est bloquée.
  Widget _buildBlockBanner() {
    final pseudo = widget.chat.receiver?.pseudo ?? _otherId;

    if (_isBlockedByMe) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.grey[900],
        child: Row(
          children: [
            const Icon(Icons.block_rounded, color: Colors.grey, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vous avez bloqué @$pseudo.',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: _unblockUser,
              child: const Text(
                'Débloquer',
                style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (_isBlockedByOther) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.grey[900],
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, color: Colors.grey, size: 16),
            SizedBox(width: 8),
            Text(
              'Vous ne pouvez pas envoyer de message à cette personne.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Input désactivé affiché à la place de `_buildMessageInput` quand bloqué.
  Widget _buildBlockedInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _colors.background,
        border: Border(top: BorderSide(color: _colors.border.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_rounded, color: _colors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text(
            'Messagerie désactivée',
            style: TextStyle(color: _colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Input bar complète ──────────────────────────────────────────────────────

  Widget _buildMessageInput() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _colors.background,
            border: Border(top: BorderSide(color: _colors.border.withOpacity(0.3))),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: _isRecording ? _buildRecordingBar() : Column(
            children: [
              if (_replying && _replyingToMessage != null) _buildReplyIndicatorBar(),
              if (_image != null) _buildImagePreview(),
              if (_multiImages.isNotEmpty) _buildMultiImagePreview(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Bouton + (ouvre menu médias)
                  _buildAttachButton(),
                  const SizedBox(width: 6),
                  // Champ texte
                  Expanded(child: _buildMessageTextField()),
                  const SizedBox(width: 6),
                  // Micro ou Envoyer
                  _buildSendOrMicButton(),
                ],
              ),
            ],
          ),
        ),
        // Emoji picker
        if (_showEmojiPicker)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              textEditingController: _textController,
              onEmojiSelected: (category, emoji) {
                setState(() {
                  canSend = _textController.text.trim().isNotEmpty;
                });
              },
              config: Config(
                height: 280,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28,
                  backgroundColor: _colors.background,
                  buttonMode: ButtonMode.CUPERTINO,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: _colors.surfaceVariant,
                  indicatorColor: _colors.primary,
                  iconColorSelected: _colors.primary,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: _colors.background,
                  buttonIconColor: _colors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecordingBar() {
    final minutes = _recordingDuration ~/ 60;
    final seconds = _recordingDuration % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Row(
      children: [
        // Bouton annuler
        GestureDetector(
          onTap: () => _stopRecording(cancel: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _colors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _colors.border.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline_rounded, color: _colors.textSecondary, size: 18),
                const SizedBox(width: 4),
                Text('Annuler', style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Indicateur micro + chrono
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'En cours…',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Bouton envoyer
        GestureDetector(
          onTap: () => _stopRecording(),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_colors.primary, Color.lerp(_colors.primary, const Color(0xFF1abc9c), 0.6)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: _colors.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachButton() {
    return GestureDetector(
      onTap: _showAttachMenu,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [_colors.primary, Color.lerp(_colors.primary, const Color(0xFF1abc9c), 0.5)!],
          ),
          boxShadow: [BoxShadow(color: _colors.primary.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isPremium = _authProvider.loginUserData.abonnement?.estPremium == true;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _colors.border.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _attachItem(Icons.photo_library_rounded, 'Photo', Colors.blue, () {
                      Navigator.pop(context);
                      _getImage();
                    }),
                    _attachItem(
                      Icons.photo_library_outlined,
                      'Multi-photos',
                      isPremium ? _colors.primary : Colors.grey,
                      () {
                        Navigator.pop(context);
                        _getMultipleImages();
                      },
                      badge: isPremium ? null : '👑',
                    ),
                    _attachItem(Icons.mic_rounded, _isRecording ? 'Stop' : 'Vocal', Colors.red, () {
                      Navigator.pop(context);
                      if (_isRecording) _stopRecording(); else _startRecording();
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachItem(IconData icon, String label, Color color, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Text(badge, style: const TextStyle(fontSize: 14)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: _colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildReplyIndicatorBar() {
    final replyText = _getReplyMessageText(_replyingToMessage!);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: _colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: _colors.primary, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: _colors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).chatReplyTo,
                    style: TextStyle(color: _colors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                Text(
                  replyText.length > 40 ? '${replyText.substring(0, 40)}…' : replyText,
                  style: TextStyle(color: _colors.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() { _replying = false; _replyingToMessage = null; }),
            child: Icon(Icons.close_rounded, size: 16, color: _colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_image!, height: 70, width: 70, fit: BoxFit.cover),
          ),
          if (_isSendingImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.black54),
                child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              ),
            ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: () => setState(() => _image = null),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ...List.generate(_multiImages.length, (i) => Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_multiImages[i], height: 70, width: 70, fit: BoxFit.cover),
                ),
              ),
              if (i == 0)
                Positioned(
                  top: -4,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _multiImages.clear()),
                    child: Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          )),
          if (_isSendingMultiImages)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CircularProgressIndicator(color: _colors.primary, strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageTextField() {
    return Container(
      decoration: BoxDecoration(
        color: _colors.surfaceVariant,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _colors.border.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bouton emoji
          GestureDetector(
            onTap: () {
              setState(() {
                _showEmojiPicker = !_showEmojiPicker;
                if (_showEmojiPicker) _focusNode.unfocus();
                else _focusNode.requestFocus();
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 10),
              child: Text(_showEmojiPicker ? '⌨️' : '😊', style: const TextStyle(fontSize: 20)),
            ),
          ),
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  canSend = _textController.text.trim().isNotEmpty || _image != null || _isRecording || _multiImages.isNotEmpty;
                });
                if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
              },
              onTap: () {
                if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
              },
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 1,
              style: TextStyle(color: _colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: _isRecording
                    ? '🎙️ Enregistrement… ($_recordingDuration s)'
                    : AppLocalizations.of(context).chatMessage,
                hintStyle: TextStyle(color: _colors.textSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool canSend = false;

  Widget _buildSendOrMicButton() {
    final isSending = _isSendingImage || _isSendingAudio || _isSendingMultiImages;
    canSend = _textController.text.trim().isNotEmpty || _image != null || _isRecording || _multiImages.isNotEmpty;

    if (isSending) {
      return SizedBox(
        width: 38, height: 38,
        child: CircularProgressIndicator(color: _colors.primary, strokeWidth: 2.5),
      );
    }

    if (!canSend) {
      // Bouton micro
      return GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopRecording(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isRecording ? Colors.red.withOpacity(0.15) : _colors.surfaceVariant,
            border: Border.all(color: _isRecording ? Colors.red : _colors.border.withOpacity(0.4)),
          ),
          child: Icon(
            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
            color: _isRecording ? Colors.red : _colors.textSecondary,
            size: 20,
          ),
        ),
      );
    }

    // Bouton envoyer animé
    return GestureDetector(
      onTap: _sendMessage,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [_colors.primary, Color.lerp(_colors.primary, const Color(0xFF1abc9c), 0.6)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: _colors.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
      )
          .animate(key: const ValueKey('send-btn'))
          .scale(begin: const Offset(0.7, 0.7), duration: 200.ms, curve: Curves.elasticOut),
    );
  }

  // AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _colors.background,
              Color.lerp(_colors.background, _colors.primary, 0.06)!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colors.primary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: _buildChatHeader(),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: _colors.textSecondary, size: 22),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: _colors.primary, size: 26),
          onPressed: _scrollToBottom,
        ),
        IconButton(
          icon: Icon(Icons.more_vert_rounded, color: _colors.textSecondary, size: 22),
          onPressed: _showChatMenu,
        ),
      ],
    );
  }
  Widget _buildChatHeader() {
    return StreamBuilder<UserData>(
      stream: _userProvider.getStreamUser(
        widget.chat.receiver!.id!,
      ),
      builder: (context, userSnapshot) {
        final user = userSnapshot.hasData
            ? userSnapshot.data!
            : widget.chat.receiver!;

        return StreamBuilder<Chat>(
          stream: _userProvider.getStreamChat(
            widget.chat.id!,
          ),
          builder: (context, chatSnapshot) {
            final chat = chatSnapshot.hasData
                ? chatSnapshot.data!
                : widget.chat;

            final isTyping = _isUserTyping(chat);

            return GestureDetector(
              onTap: () {
                showUserDetailsModalDialog(
                  user,
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height,
                  context,
                );
              },
              child: Row(
                children: [
                  // Avatar avec ring dégradé pulsant
                  Stack(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_colors.primary, Color.lerp(_colors.primary, const Color(0xFF1abc9c), 0.6)!],
                          ),
                          boxShadow: [BoxShadow(color: _colors.primary.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: CircleAvatar(
                            radius: 19,
                            backgroundImage: NetworkImage(user.imageUrl ?? ''),
                            backgroundColor: _colors.surfaceVariant,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: UserPresenceWidget(
                          userId: user.id!,
                          size: 12,
                          showTextStatus: false,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                "@${user.pseudo ?? ''}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _colors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            UserBadgeWidget(user: user, size: 14),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (isTyping)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const TypingIndicator(),
                            const SizedBox(width: 6),
                            Text("en train d'écrire…",
                                style: TextStyle(color: _colors.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                          ])
                        else
                          UserPresenceWidget(userId: user.id!, showTextStatus: true, isChatHeader: true),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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

  /// Délai max entre deux messages du même expéditeur pour les regrouper
  /// visuellement (façon WhatsApp), sans bulle/avatar répété.
  static const int _groupingThresholdMs = 2 * 60 * 1000;

  Widget _buildMessageList(List<Message> messages) {
    // Construit une liste plate [date séparateur | message] en calculant le
    // regroupement visuel (premier/dernier d'un groupe consécutif du même
    // expéditeur, rapproché dans le temps).
    final items = <_ChatListItem>[];
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final previous = i > 0 ? messages[i - 1] : null;
      final next = i < messages.length - 1 ? messages[i + 1] : null;

      if (previous == null || !_isSameDay(previous.createdAt, message.createdAt)) {
        items.add(_ChatListItem.date(message.createdAt));
      }

      final isFirstInGroup = previous == null ||
          previous.sendBy != message.sendBy ||
          !_isSameDay(previous.createdAt, message.createdAt) ||
          (message.create_at_time_spam - previous.create_at_time_spam) > _groupingThresholdMs;

      final isLastInGroup = next == null ||
          next.sendBy != message.sendBy ||
          !_isSameDay(next.createdAt, message.createdAt) ||
          (next.create_at_time_spam - message.create_at_time_spam) > _groupingThresholdMs;

      items.add(_ChatListItem.message(message, isFirstInGroup: isFirstInGroup, isLastInGroup: isLastInGroup));
    }

    final itemCount = items.length + (_isLoadingMore ? 1 : 0);
    return ListView.builder(
      key: _messageKey,
      controller: _scrollController,
      itemCount: itemCount,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _colors.primary),
              ),
            ),
          );
        }

        final itemIndex = _isLoadingMore ? index - 1 : index;
        final item = items[itemIndex];

        if (item.date != null) {
          return _buildDateSeparator(item.date!);
        }

        final message = item.message!;
        final isLastItem = itemIndex == items.length - 1;
        final isHighlighted = _highlightedMessageId == message.id;

        return KeyedSubtree(
          key: GlobalObjectKey(message.id!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: isHighlighted
                ? BoxDecoration(
                    color: _colors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: _buildMessageBubble(message, isLastItem, item.isFirstInGroup, item.isLastInGroup),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              _colors.primary.withOpacity(0.04),
              _colors.background,
            ],
          ),
        ),
        child: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _colors.primary))
                : StreamBuilder<List<Message>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      l10n.convErrorLoading,
                      style: TextStyle(color: _colors.textPrimary),
                    ),
                  );
                } else if (snapshot.hasData) {
                  _streamMessages = snapshot.data!;
                  final messages = _mergeMessages();

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.convNoMessage,
                        style: TextStyle(color: _colors.textSecondary),
                      ),
                    );
                  }

                  // Scroll vers le bas si nouveau(x) message(s)
                  if (messages.length > _messages.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  }

                  _messages = messages;

                  // Cache local + marquage "lu" en arrière-plan (hors build).
                  ChatCacheService.saveMessages(widget.chat.docId!, messages);
                  _scheduleReadReceipts(messages);

                  return _buildMessageList(messages);
                } else if (_messages.isNotEmpty) {
                  // Affichage des messages en cache pendant la connexion au flux.
                  return _buildMessageList(_messages);
                }
                return Center(child: CircularProgressIndicator(color: _colors.primary));
              },
            ),
          ),
          _buildBlockBanner(),
          (_isBlockedByMe || _isBlockedByOther)
              ? _buildBlockedInputBar()
              : _buildMessageInput(),
        ],
        ),
      ),
    );
  }
}

/// Élément de la liste affichée : soit un séparateur de date, soit un
/// message avec ses informations de regroupement visuel.
class _ChatListItem {
  final DateTime? date;
  final Message? message;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  _ChatListItem.date(this.date)
      : message = null,
        isFirstInGroup = false,
        isLastInGroup = false;

  _ChatListItem.message(this.message, {required this.isFirstInGroup, required this.isLastInGroup}) : date = null;
}

