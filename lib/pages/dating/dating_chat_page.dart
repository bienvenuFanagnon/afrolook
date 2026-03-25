// lib/pages/dating/dating_chat_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../providers/dating/dating_provider.dart';
import '../../providers/authProvider.dart';

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

class _DatingChatPageState extends State<DatingChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUserId = authProvider.loginUserData.id;

      if (currentUserId == null) return;

      // Chercher la conversation existante
      final snapshot = await FirebaseFirestore.instance
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
        // Créer une nouvelle conversation
        final now = DateTime.now().millisecondsSinceEpoch;
        final newConversationId = FirebaseFirestore.instance
            .collection('dating_conversations')
            .doc()
            .id;

        final conversation = DatingConversation(
          id: newConversationId,
          connectionId: widget.connectionId,
          userId1: currentUserId,
          userId2: widget.otherUserId,
          unreadCountUser1: 0,
          unreadCountUser2: 0,
          createdAt: now,
          updatedAt: now,
        );

        await FirebaseFirestore.instance
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'initialisation de la conversation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _conversationId == null) return;

    setState(() => _isSending = true);

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) {
      setState(() => _isSending = false);
      return;
    }

    final datingProvider = Provider.of<DatingProvider>(context, listen: false);

    final success = await datingProvider.sendMessage(
      conversationId: _conversationId!,
      receiverId: widget.otherUserId,
      type: MessageType.text,
      text: text,
    );

    if (success) {
      _messageController.clear();
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi du message'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isSending = false);
  }

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

  Future<void> _markMessagesAsRead() async {
    if (_conversationId == null) return;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) return;

    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection('dating_conversations')
          .doc(_conversationId)
          .get();

      if (conversationDoc.exists) {
        final conversation = DatingConversation.fromJson(conversationDoc.data()!);

        final isUser1 = conversation.userId1 == currentUserId;
        final unreadCount = isUser1 ? conversation.unreadCountUser1 : conversation.unreadCountUser2;

        if (unreadCount > 0) {
          await FirebaseFirestore.instance
              .collection('dating_conversations')
              .doc(_conversationId)
              .update({
            if (isUser1) 'unreadCountUser1' : 0,
            if (!isUser1) 'unreadCountUser2' : 0,
          });
        }
      }
    } catch (e) {
      print('Erreur lors du marquage des messages lus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(widget.otherUserImage),
              child: widget.otherUserImage.isEmpty
                  ? Icon(Icons.person, size: 20)
                  : null,
            ),
            SizedBox(width: 12),
            Column(
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
          ],
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showProfileOptions(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_conversationId == null) {
      return Center(child: Text('Conversation non disponible'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
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

        final messages = snapshot.data?.docs
            .map((doc) => DatingMessage.fromJson(doc.data() as Map<String, dynamic> ))
            .toList() ?? [];

        // Marquer les messages comme lus après le chargement
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markMessagesAsRead();
        });

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16),
                Text(
                  'Aucun message',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Envoyez un message pour commencer la conversation',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderUserId ==
                Provider.of<UserAuthProvider>(context, listen: false)
                    .loginUserData
                    .id;
            return _buildMessageBubble(message, isMe);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(DatingMessage message, bool isMe) {
    final time = DateTime.fromMillisecondsSinceEpoch(message.createdAt);
    final timeStr = DateFormat('HH:mm').format(time);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12, left: isMe ? 50 : 0, right: isMe ? 0 : 50),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.red.shade500 : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: isMe ? Radius.circular(20) : Radius.circular(4),
                  bottomRight: isMe ? Radius.circular(4) : Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == MessageType.text && message.text != null)
                    Text(
                      message.text!,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  if (message.type == MessageType.image && message.mediaUrl != null)
                    GestureDetector(
                      onTap: () => _showImageFullscreen(message.mediaUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          message.mediaUrl!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey.shade300,
                              child: Icon(Icons.broken_image, size: 50),
                            );
                          },
                        ),
                      ),
                    ),
                  if (message.type == MessageType.audio && message.mediaUrl != null)
                    Container(
                      width: 200,
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.audiotrack, color: isMe ? Colors.white : Colors.black87),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Message audio',
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.type == MessageType.emoji && message.text != null)
                    Text(
                      message.text!,
                      style: TextStyle(fontSize: 32),
                    ),
                ],
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (isMe && message.isRead) ...[
                  SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 12,
                    color: Colors.blue,
                  ),
                ] else if (isMe && !message.isRead) ...[
                  SizedBox(width: 4),
                  Icon(
                    Icons.done,
                    size: 12,
                    color: Colors.grey.shade500,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.emoji_emotions, color: Colors.grey.shade600),
            onPressed: () => _showEmojiPicker(),
          ),
          IconButton(
            icon: Icon(Icons.photo, color: Colors.grey.shade600),
            onPressed: () => _pickImage(),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Écrire un message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              color: _messageController.text.isNotEmpty ? Colors.red.shade500 : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _messageController.text.isNotEmpty && !_isSending
                  ? _sendMessage
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: _emojis.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                _messageController.text += _emojis[index];
              },
              child: Center(
                child: Text(
                  _emojis[index],
                  style: TextStyle(fontSize: 30),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    // Implémenter la sélection d'image
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fonctionnalité à venir'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showImageFullscreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
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
              leading: Icon(Icons.person, color: Colors.red),
              title: Text('Voir le profil'),
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers le profil
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Bloquer'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            ListTile(
              leading: Icon(Icons.flag, color: Colors.red),
              title: Text('Signaler'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Bloquer'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) return;

    try {
      final blockId = FirebaseFirestore.instance.collection('dating_blocks').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await FirebaseFirestore.instance
          .collection('dating_blocks')
          .doc(blockId)
          .set({
        'id': blockId,
        'blockerUserId': currentUserId,
        'blockedUserId': widget.otherUserId,
        'createdAt': now,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.otherUserName} a été bloqué'),
          backgroundColor: Colors.red,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du blocage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final currentUserId = authProvider.loginUserData.id;

    if (currentUserId == null) return;

    try {
      final reportId = FirebaseFirestore.instance.collection('dating_reports').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await FirebaseFirestore.instance
          .collection('dating_reports')
          .doc(reportId)
          .set({
        'id': reportId,
        'reporterUserId': currentUserId,
        'targetUserId': widget.otherUserId,
        'reason': reason,
        'description': '',
        'createdAt': now,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signalement envoyé. Merci de contribuer à la sécurité de la communauté.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du signalement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  final List<String> _emojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
    '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩',
    '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
    '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬',
    '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗',
    '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯',
    '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
    '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈',
    '👿', '👹', '👺', '🤡', '💩', '👻', '💀', '☠️', '👽', '👾',
    '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿',
    '😾', '🙈', '🙉', '🙊', '💋', '💌', '💘', '💝', '💖', '💗',
    '💓', '💞', '💕', '💟', '❣️', '💔', '❤️', '🧡', '💛', '💚',
    '💙', '💜', '🤎', '🖤', '🤍', '💯', '💢', '💥', '💫', '💦',
    '💨', '🕳️', '💣', '💬', '🗯️', '💭', '💤', '👋', '🤚', '🖐️',
    '✋', '🖖', '👌', '🤌', '🤏', '✌️', '🤞', '🤟', '🤘', '🤙',
    '👈', '👉', '👆', '🖕', '👇', '☝️', '👍', '👎', '✊', '👊',
    '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💅',
    '🤳', '💪', '🦾', '🦵', '🦿', '🦶', '👂', '🦻', '👃', '🧠',
    '🦷', '🦴', '👀', '👁️', '👅', '👄', '💋', '🩸',
  ];
}