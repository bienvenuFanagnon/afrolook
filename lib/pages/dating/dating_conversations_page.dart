// lib/pages/dating/dating_conversations_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'dating_chat_page.dart';
import 'dating_subscription_page.dart';

class DatingConversationsPage extends StatefulWidget {
  const DatingConversationsPage({Key? key}) : super(key: key);

  @override
  State<DatingConversationsPage> createState() => _DatingConversationsPageState();
}

class _DatingConversationsPageState extends State<DatingConversationsPage> {
  String? _currentUserId;
  String? _subscriptionPlan;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentUserId = authProvider.loginUserData.id;
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_dating_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final subscription = snapshot.docs.first;
        _subscriptionPlan = subscription['planCode'];
        _isPremium = _subscriptionPlan == 'plus' || _subscriptionPlan == 'gold';
      } else {
        _isPremium = false;
      }
      setState(() {});
    } catch (e) {
      printVm('❌ Erreur chargement abonnement: $e');
      _isPremium = false;
    }
  }

  void _showPremiumDialog() {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              t.datingPremiumMessagingTitle,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE63946), Color(0xFFFF69B4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              t.datingPremiumMessagingDesc,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              t.datingPremiumUpgradeIntro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              t.datingPremiumUpgradeCallToAction,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(t.datingFeatureUnlimitedMessages),
            _buildFeatureRow(t.datingFeatureSeeWhoLiked),
            _buildFeatureRow(t.datingFeatureSuperLikesPerDay),
            _buildFeatureRow(t.datingFeatureProfileBoost),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.datingLaterButton, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DatingSubscriptionPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              t.datingSeeOffersTitleCase,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
        ],
      ),
    );
  }

  /// Met à jour la date du dernier message pour remonter la conversation en tête de liste.
  Future<void> _updateConversationLastMessageAt(String conversationId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance
        .collection('dating_conversations')
        .doc(conversationId)
        .update({
      'lastMessageAt': now,
      'updatedAt': now,
    });
  }

  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

  Future<void> _openChat(DatingConversation conversation, String otherUserId, DatingProfile otherProfile) async {
    // Met à jour lastMessageAt pour que cette conversation remonte en tête
    await _updateConversationLastMessageAt(conversation.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatingChatPage(
          connectionId: conversation.connectionId,
          otherUserId: otherUserId,
          otherUserName: otherProfile.pseudo,
          otherUserImage: otherProfile.imageUrl,
          conversationId: conversation.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: Center(child: Text(t.datingPleaseLogin)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.datingMessagesTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(
              t.datingChatWithMatches,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<DatingConversation>>(
        stream: _getUserConversations(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(t.datingErrorGeneric.replaceAll('{error}', '${snapshot.error}')),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(t.datingLoadingMessages),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFCDD2), Color(0xFFFCE4EC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 60,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t.datingNoMessagesTitle,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.of(context).textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.datingStartConversation,
                    style: TextStyle(fontSize: 14, color: AppColors.of(context).textSecondary),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.favorite, color: Colors.white),
                    label: Text(
                      t.datingSeeMyMatches,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final otherUserId = conversation.userId1 == _currentUserId
                  ? conversation.userId2
                  : conversation.userId1;

              return FutureBuilder<DatingProfile?>(
                future: _getOtherDatingProfile(otherUserId),
                builder: (context, profileSnapshot) {
                  if (!profileSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final otherProfile = profileSnapshot.data!;
                  final unreadCount = _currentUserId == conversation.userId1
                      ? conversation.unreadCountUser1
                      : conversation.unreadCountUser2;

                  final hasUnread = unreadCount > 0;
                  final lastMessageTime = conversation.lastMessageAt ?? conversation.createdAt;
                  final formattedTime = _formatTimeAgo(lastMessageTime);
                  final isNew = lastMessageTime > DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        if (_isPremium) {
                          _openChat(conversation, otherUserId, otherProfile);
                        } else {
                          _showPremiumDialog();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: hasUnread ? Colors.red.shade50 : AppColors.of(context).surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: hasUnread ? Colors.red.shade200 : AppColors.of(context).border,
                            width: hasUnread ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Photo de profil avec effet de cœur pour les non lus
                              Stack(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: hasUnread
                                            ? [Colors.red.shade400, Colors.pink.shade400]
                                            : [Colors.grey.shade300, Colors.grey.shade400],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: hasUnread
                                              ? Colors.red.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: Image.network(
                                          _cdnUrl(otherProfile.imageUrl),
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.person,
                                                size: 30,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasUnread)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              // Infos
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          otherProfile.pseudo,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                            color: hasUnread ? AppColors.of(context).textPrimary : AppColors.of(context).textSecondary,
                                          ),
                                        ),
                                        if (otherProfile.isVerified)
                                          const SizedBox(width: 8),
                                        if (otherProfile.isVerified)
                                          const Icon(
                                            Icons.verified,
                                            size: 14,
                                            color: Colors.blue,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.cake,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          t.datingAgeYears.replaceAll('{age}', '${otherProfile.age}'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasUnread ? Colors.red.shade700 : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.location_on,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          otherProfile.pays,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            conversation.lastMessage ?? t.datingNewConversation,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: hasUnread
                                                  ? Colors.red.shade700
                                                  : Colors.grey.shade600,
                                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Heure du dernier message
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: hasUnread ? Colors.red : Colors.grey.shade500,
                                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Bouton de chat
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isPremium
                                          ? (hasUnread ? Colors.red : Colors.grey.shade100)
                                          : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isPremium ? Icons.chat_bubble : Icons.lock,
                                      size: 18,
                                      color: _isPremium
                                          ? (hasUnread ? Colors.red : Colors.grey.shade600)
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimeAgo(int timestamp) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return t.datingJustNow;
    } else if (difference.inHours < 1) {
      return t.datingMinutesAgo.replaceAll('{count}', '${difference.inMinutes}');
    } else if (difference.inDays < 1) {
      return t.datingHoursAgo.replaceAll('{count}', '${difference.inHours}');
    } else if (difference.inDays == 1) {
      return t.datingYesterday;
    } else if (difference.inDays < 7) {
      return t.datingDaysAgo.replaceAll('{count}', '${difference.inDays}');
    } else {
      return '${time.day}/${time.month}';
    }
  }

  Future<DatingProfile?> _getOtherDatingProfile(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('dating_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return DatingProfile.fromJson(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Stream<List<DatingConversation>> _getUserConversations(String userId) {
    return FirebaseFirestore.instance
        .collection('dating_conversations')
        .where('userId1', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => DatingConversation.fromJson(doc.data()))
        .toList())
        .asyncMap((conversations) async {
      final snapshot2 = await FirebaseFirestore.instance
          .collection('dating_conversations')
          .where('userId2', isEqualTo: userId)
          .get();

      final otherConversations = snapshot2.docs
          .map((doc) => DatingConversation.fromJson(doc.data()))
          .toList();

      final allConversations = [...conversations, ...otherConversations];
      allConversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return allConversations;
    });
  }
}