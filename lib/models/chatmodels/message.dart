/*
 * Copyright (c) 2022 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import 'dart:convert';


import 'package:afrotok/models/chatmodels/reaction.dart';
import 'package:afrotok/models/chatmodels/reply_message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';


class Message {
  /// Provides id
  late String id;

  /// Used for accessing widget's render box.
  final GlobalKey key;

  /// Provides actual message it will be text or image/audio file path.
  final String message;
  late  String message_state='';

  /// Provides message created date time.
  final DateTime createdAt;

  /// Provides id of sender of message.
  final String sendBy;
  final String receiverBy;
  final String chat_id;

  /// Provides reply message if user triggers any reply on any message.
  late ReplyMessage replyMessage;

  /// Represents reaction on message.
  final Reaction reaction;

  /// Provides message type.
   String messageType;
  int create_at_time_spam;

  /// Status of the message.
  final ValueNotifier<MessageStatus> _status;

  /// Provides max duration for recorded voice message.
  Duration? voiceMessageDuration;

  Message(   {
     this.message_state='',
    required this.receiverBy,
    required this.chat_id,
    required this.create_at_time_spam,
    this.id = '',
    required this.message,
    required this.createdAt,
    required this.sendBy,
    required this.replyMessage ,
    Reaction? reaction,
    required this.messageType,
    this.voiceMessageDuration,
    MessageStatus status = MessageStatus.pending,
  })  : reaction = reaction ?? Reaction(reactions: [], reactedUserIds: []),
        key = GlobalKey(),
        _status = ValueNotifier(status),
        assert(
          (messageType==MessageType.voice.name
              ? ((defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android))
              : true),
          "Voice messages are only supported with android and ios platform",
        );

  /// curret messageStatus
  MessageStatus get status => _status.value;

  /// For [MessageStatus] ValueNotfier which is used to for rebuilds
  /// when state changes.
  /// Using ValueNotfier to avoid usage of setState((){}) in order
  /// rerender messages with new receipts.
  ValueNotifier<MessageStatus> get statusNotifier => _status;

  /// This setter can be used to update message receipts, after which the configured
  /// builders will be updated.
  set setStatus(MessageStatus messageStatus) {
    _status.value = messageStatus;
  }


  factory Message.fromJson(Map<String, dynamic> json) => Message(
      id: json["id"].toString(),
      message: json["message"],
      createdAt:DateTime.fromMillisecondsSinceEpoch(json["create_at_time_spam"]),
      sendBy: json["send_by"],
      replyMessage: ReplyMessage.fromJson(json["reply_message"]),
      reaction: Reaction.fromJson(json["reaction"]),
      messageType: json["message_type"],
      voiceMessageDuration: json["voice_message_duration"],
      status:json['status']==MessageStatus.pending.name?MessageStatus.pending:json['status']==MessageStatus.read.name?MessageStatus.read:json['status']==MessageStatus.delivered.name?MessageStatus.delivered:json['status']==MessageStatus.undelivered.name?MessageStatus.undelivered:MessageStatus.undelivered,
      chat_id: json['chat_id'],
      create_at_time_spam: json['create_at_time_spam'],
      message_state: json['message_state'], receiverBy: json['receiverBy'],
  )
  ;

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'createdAt': createdAt,
        'send_by': sendBy,
        'chat_id': chat_id,
        'reply_message': replyMessage.toJson(),
        'reaction': reaction.toJson(),
        'message_type': messageType,
    'create_at_time_spam': create_at_time_spam,
        'voice_message_duration': voiceMessageDuration,
        'status': status.name,
    'message_state': message_state,
    'receiverBy': receiverBy
      };
}

class ReplyMessage {
  /// Provides reply message.
  late  String message;

  /// Provides user id of who replied message.
  final String replyBy;

  /// Provides user id of whom to reply.
  final String replyTo;
  late final String messageType;

  /// Provides max duration for recorded voice message.
  final Duration? voiceMessageDuration;

  /// Id of message, it replies to.
  late final String messageId;

  ReplyMessage({
    this.messageId="",
    required this.message,
    this.replyTo="",
    this.replyBy="",
    required this.messageType,
    this.voiceMessageDuration,
  });

  factory ReplyMessage.fromJson(Map<String, dynamic> json) => ReplyMessage(
    message: json['message'],
    replyBy: json['replyBy'],
    replyTo: json['replyTo'],
    messageType: json["message_type"],
    messageId: json["id"],
    voiceMessageDuration: json["voiceMessageDuration"],
  );

  Map<String, dynamic> toJson() => {
    'message': message,
    'replyBy': replyBy,
    'replyTo': replyTo,
    'message_type': messageType,
    'id': messageId,
    'voiceMessageDuration': voiceMessageDuration,
  };
}
