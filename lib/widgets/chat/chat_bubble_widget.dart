import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../models/chatmodels/message.dart';
import '../../models/enums.dart';
import '../../models/model_data.dart' show MessageState;
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool _isOnlyEmoji(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.length > 8) return false;
  final emojiRegex = RegExp(
    r'^[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{231A}-\u{231B}\u{23E9}-\u{23F3}\u{23F8}-\u{23FA}]+$',
    unicode: true,
  );
  return emojiRegex.hasMatch(trimmed);
}

String _formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ---------------------------------------------------------------------------
// Date separator
// ---------------------------------------------------------------------------

class ChatDateSeparator extends StatelessWidget {
  final String label;
  const ChatDateSeparator({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.of(context).primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.of(context).primary.withOpacity(0.25),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.08,
              color: AppColors.of(context).primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator (3 dots animés)
// ---------------------------------------------------------------------------

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(context).primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        )
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(
              begin: 0.6,
              end: 1.2,
              delay: Duration(milliseconds: i * 150),
              duration: 400.ms,
              curve: Curves.easeInOut,
            )
            .then()
            .scaleXY(begin: 1.2, end: 0.6, duration: 400.ms, curve: Curves.easeInOut);
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Read receipt icon
// ---------------------------------------------------------------------------

class ReadReceiptIcon extends StatelessWidget {
  final bool isRead;
  final bool isMe;
  const ReadReceiptIcon({super.key, required this.isRead, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();
    return Icon(
      isRead ? MaterialCommunityIcons.check_all : MaterialCommunityIcons.check,
      size: 13,
      color: isRead ? AppColors.of(context).primary : AppColors.of(context).textSecondary,
    );
  }
}

// ---------------------------------------------------------------------------
// Reply preview (à l'intérieur de la bulle)
// ---------------------------------------------------------------------------

class _ReplyPreview extends StatelessWidget {
  final ReplyMessage reply;
  final bool isMe;
  const _ReplyPreview({required this.reply, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final borderColor = isMe ? Colors.white54 : colors.primary;
    final bgColor = isMe ? Colors.white12 : colors.primary.withOpacity(0.10);

    Widget content;
    if (reply.messageType == MessageType.image.name) {
      content = Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: reply.message,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              reply.imageText?.isNotEmpty == true ? reply.imageText! : '📷 Photo',
              style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (reply.messageType == MessageType.voice.name) {
      content = Row(
        children: [
          Icon(Icons.mic, size: 14, color: isMe ? Colors.white70 : colors.primary),
          const SizedBox(width: 4),
          Text('Message vocal',
              style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : colors.textSecondary)),
        ],
      );
    } else {
      content = Text(
        reply.message.length > 40 ? '${reply.message.substring(0, 40)}…' : reply.message,
        style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : colors.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.replyTo.isNotEmpty ? '@${reply.replyTo}' : 'Réponse',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isMe ? Colors.white : colors.primary,
            ),
          ),
          const SizedBox(height: 2),
          content,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message status + heure
// ---------------------------------------------------------------------------

class MessageMeta extends StatelessWidget {
  final Message message;
  final bool isMe;
  final Color textColor;

  const MessageMeta({
    super.key,
    required this.message,
    required this.isMe,
    this.textColor = Colors.white70,
  });

  String _formatTime(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.create_at_time_spam),
          style: TextStyle(fontSize: 9, color: textColor),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          ReadReceiptIcon(isRead: message.message_state == MessageState.LU.name, isMe: true),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction chip
// ---------------------------------------------------------------------------

class _ReactionChip extends StatelessWidget {
  final String reactions;
  final int count;
  final bool isMe;
  const _ReactionChip({required this.reactions, required this.count, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).border),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reactions, style: const TextStyle(fontSize: 13)),
          if (count > 1) ...[
            const SizedBox(width: 3),
            Text('$count',
                style: TextStyle(fontSize: 10, color: AppColors.of(context).textSecondary, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text bubble
// ---------------------------------------------------------------------------

class TextBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback? onLongPress;

  const TextBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onlyEmoji = _isOnlyEmoji(message.message);

    if (onlyEmoji) {
      return _EmojiOnlyBubble(message: message, isMe: isMe, onLongPress: onLongPress);
    }

    final hasReply = message.replyMessage.message.isNotEmpty;
    final hasReactions = message.reaction != null && message.reaction!.reactions.isNotEmpty;

    final sentRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: isFirstInGroup ? const Radius.circular(18) : const Radius.circular(4),
      bottomLeft: const Radius.circular(18),
      bottomRight: isLastInGroup ? const Radius.circular(4) : const Radius.circular(18),
    );
    final receivedRadius = BorderRadius.only(
      topLeft: isFirstInGroup ? const Radius.circular(18) : const Radius.circular(4),
      topRight: const Radius.circular(18),
      bottomLeft: isLastInGroup ? const Radius.circular(4) : const Radius.circular(18),
      bottomRight: const Radius.circular(18),
    );

    Widget bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [colors.primary, Color.lerp(colors.primary, const Color(0xFF1abc9c), 0.6)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : colors.surface,
          borderRadius: isMe ? sentRadius : receivedRadius,
          border: isMe ? null : Border.all(color: colors.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: isMe ? colors.primary.withOpacity(0.25) : Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasReply) _ReplyPreview(reply: message.replyMessage, isMe: isMe),
            Text(
              message.message,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : colors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.bottomRight,
              child: MessageMeta(message: message, isMe: isMe),
            ),
          ],
        ),
      ),
    );

    if (!hasReactions) return bubble;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        Positioned(
          bottom: -10,
          right: isMe ? 8 : null,
          left: isMe ? null : 8,
          child: _ReactionChip(
            reactions: message.reaction!.reactions.join(''),
            count: message.reaction!.reactedUserIds.length,
            isMe: isMe,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Large emoji bubble (seul emoji, sans fond)
// ---------------------------------------------------------------------------

class _EmojiOnlyBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onLongPress;

  const _EmojiOnlyBubble({required this.message, required this.isMe, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(message.message, style: const TextStyle(fontSize: 44))
              .animate()
              .scale(begin: const Offset(0.5, 0.5), duration: 300.ms, curve: Curves.elasticOut),
          const SizedBox(height: 2),
          MessageMeta(
            message: message,
            isMe: isMe,
            textColor: AppColors.of(context).textSecondary,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image bubble
// ---------------------------------------------------------------------------

class ImageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ImageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasCaption = message.imageText != null && message.imageText!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          decoration: BoxDecoration(
            color: colors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: message.message,
                    width: 220,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      width: 220,
                      height: 180,
                      color: colors.surfaceVariant,
                      child: Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2)),
                    ),
                    errorWidget: (c, u, e) => Container(
                      width: 220,
                      height: 180,
                      color: colors.surfaceVariant,
                      child: Icon(Icons.broken_image, color: colors.textSecondary),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: MessageMeta(message: message, isMe: isMe),
                    ),
                  ),
                ],
              ),
              if (hasCaption)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    message.imageText!,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-image bubble (liste d'URLs dans imageText séparées par |)
// ---------------------------------------------------------------------------

class MultiImageBubble extends StatelessWidget {
  final List<String> urls;
  final Message message;
  final bool isMe;
  final void Function(String url)? onTapImage;
  final VoidCallback? onLongPress;

  const MultiImageBubble({
    super.key,
    required this.urls,
    required this.message,
    required this.isMe,
    this.onTapImage,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final count = urls.length.clamp(1, 3);
    final displayUrls = urls.take(count).toList();

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              if (count == 1)
                _thumb(displayUrls[0], 220, 180, context)
              else if (count == 2)
                Row(children: [
                  Expanded(child: _thumb(displayUrls[0], 110, 150, context)),
                  const SizedBox(width: 2),
                  Expanded(child: _thumb(displayUrls[1], 110, 150, context)),
                ])
              else
                Column(children: [
                  _thumb(displayUrls[0], 220, 130, context),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(child: _thumb(displayUrls[1], 109, 100, context)),
                    const SizedBox(width: 2),
                    Expanded(child: _thumb(displayUrls[2], 109, 100, context)),
                  ]),
                ]),
              Container(
                color: colors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: MessageMeta(message: message, isMe: isMe,
                      textColor: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(String url, double w, double h, BuildContext context) {
    return GestureDetector(
      onTap: () => onTapImage?.call(url),
      child: CachedNetworkImage(
        imageUrl: url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        placeholder: (c, u) => Container(
          width: w, height: h,
          color: AppColors.of(context).surfaceVariant,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.of(context).primary)),
        ),
        errorWidget: (c, u, e) => Container(width: w, height: h, color: AppColors.of(context).surfaceVariant),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audio bubble avec waveform animée
// ---------------------------------------------------------------------------

class AudioBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final AudioPlayer audioPlayer;
  final String? currentPlayingId;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final VoidCallback onToggle;
  final ValueChanged<double> onSeek;
  final VoidCallback? onLongPress;

  const AudioBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.audioPlayer,
    required this.currentPlayingId,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onSeek,
    this.onLongPress,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  static const int _barCount = 20;
  final List<double> _barHeights = [];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.message.id.hashCode);
    for (int i = 0; i < _barCount; i++) {
      _barHeights.add(4 + rng.nextDouble() * 22);
    }
    _waveController = AnimationController(vsync: this, duration: 800.ms)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isCurrentPlaying = widget.currentPlayingId == widget.message.id;
    final progress = widget.duration.inMilliseconds > 0
        ? (widget.position.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final activeBarCount = (_barCount * progress).round();

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240, minWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: widget.isMe
              ? LinearGradient(
                  colors: [colors.primary, Color.lerp(colors.primary, const Color(0xFF1abc9c), 0.6)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: widget.isMe ? null : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: widget.isMe ? null : Border.all(color: colors.border.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: widget.isMe ? colors.primary.withOpacity(0.3) : Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Bouton play/pause circulaire
            GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isMe ? Colors.white24 : colors.primary.withOpacity(0.15),
                  border: Border.all(
                    color: widget.isMe ? Colors.white54 : colors.primary.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: widget.isLoading && isCurrentPlaying
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.isMe ? Colors.white : colors.primary,
                        ),
                      )
                    : Icon(
                        widget.isPlaying && isCurrentPlaying ? Icons.pause : Icons.play_arrow,
                        color: widget.isMe ? Colors.white : colors.primary,
                        size: 18,
                      ),
              ),
            ),

            const SizedBox(width: 10),

            // Waveform
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(_barCount, (i) {
                          final isPast = i < activeBarCount;
                          final isActive = widget.isPlaying && isCurrentPlaying;
                          double height = _barHeights[i];
                          if (isActive && !isPast) {
                            final wave = math.sin(_waveController.value * math.pi * 2 + i * 0.5);
                            height = height * (0.5 + 0.5 * ((wave + 1) / 2));
                          }
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              height: height.clamp(3.0, 26.0),
                              decoration: BoxDecoration(
                                color: isPast
                                    ? (widget.isMe ? Colors.white : colors.primary)
                                    : (widget.isMe ? Colors.white38 : colors.primary.withOpacity(0.25)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(widget.position),
                        style: TextStyle(
                          fontSize: 9,
                          color: widget.isMe ? Colors.white70 : colors.textSecondary,
                        ),
                      ),
                      MessageMeta(message: widget.message, isMe: widget.isMe),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
