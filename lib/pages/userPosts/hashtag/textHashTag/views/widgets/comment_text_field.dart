import 'dart:math';

import 'package:flutter/material.dart';

import 'package:fluttertagger/fluttertagger.dart';

import '../../models/user.dart';
import 'custom_text_field.dart';

class CommentTextField extends StatelessWidget {
  final FlutterTaggerController controller;
  final List<String> emojis;
  final VoidCallback onSend;
  final EdgeInsets insets;
  final FocusNode? focusNode;

  ///Key passed down from FlutterTagger
  final Key? containerKey;

  const CommentTextField({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.insets,
    this.emojis = const  [
      '😍', '😜', '👍', '🤞', '🙌', '😉', '🙏', // Emojis existants
      '❤️', '💛', '💚', '💙', '💜', // Cœurs
      '🥭', '🍍', '🍌', '🍉', '🍇', '🍊', '🍋', '🍈', '🍒', '🍑', // Fruits
      '🌴', '🌵', '🌿', '🍀', '🌾', '🌳', '🌲', '🌱', '🌺', '🌸' // Plantes
          '🔨', '⛏️', '🪓', '🔧', '🔩', '🪚', '🪛', '🧱', '🪣', '🧺' // Outils
          '👩🏿', '👨🏿', '👶🏿', // Femme, homme et enfant africains
      '👩🏿‍🦱', '👨🏿‍🦱', '👶🏿‍🦱', // Femme, homme et enfant africains avec cheveux bouclés
      '👩🏿‍🦳', '👨🏿‍🦳', '👶🏿‍🦳' // Femme, homme et enfant africains avec cheveux blancs
          '💑', '👩‍❤️‍👨', '👩‍❤️‍👩', '👨‍❤️‍👨', // Amoureux et couples
      '👫', '👬', '👭', // Jeunes couples
      '👩‍🎓', '👨‍🎓', '🧑‍🎓', // Écoliers
      '📚', '📖', '✏️', '🖊️', '🖋️', '📝', '📒', '📓', '📔', '📕' // Outils d'école

    ],

    this.focusNode,
    this.containerKey,
  }) : super(key: key);

  List<String> getShuffledEmojis() {
    List<String> shuffledEmojis = List.from(emojis);
    shuffledEmojis.shuffle(Random());
    return shuffledEmojis;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    List<String> shuffledEmojis = getShuffledEmojis();

    return Container(
      key: containerKey,
      constraints: BoxConstraints(
        maxHeight: insets == EdgeInsets.zero ? 158 : 158 + insets.bottom,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 10,
      ),
      color: Colors.white,
      child: Column(
        mainAxisAlignment: insets == EdgeInsets.zero
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: SizedBox(
              width: width,
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,

                itemCount: shuffledEmojis.length,
                itemBuilder: (context, index) {
                  return SizedBox(
                    height: 40,
                    width: 40,
                    child: Card(
                      child: Center(
                        child: EmojiIcon(
                          fontSize: 20,
                          emoji: shuffledEmojis[index],
                          onTap: (emoji) {
                            final baseOffset = controller.selection.baseOffset;
                            final cursorPosition = controller.cursorPosition;
                            final substring = controller.formattedText.substring(0, cursorPosition);
                            final newText = substring + emoji + controller.formattedText.substring(cursorPosition);

                            controller.text = newText;
                            controller.formatTags();

                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: baseOffset + emoji.length),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Container(
              //   height: 50,
              //   width: 50,
              //   decoration: BoxDecoration(
              //     shape: BoxShape.circle,
              //     image: DecorationImage(
              //       fit: BoxFit.cover,
              //       image: NetworkImage(User.anon().avatar),
              //     ),
              //   ),
              // ),
              // const Spacer(),
              Expanded(
                child: CustomTextField(


                  focusNode: focusNode,
                  controller: controller,
                  hint: "Votre message",
                  suffix: IconButton(
                    onPressed: onSend,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class EmojiIcon extends StatelessWidget {
  final String emoji;
  final Function(String) onTap;
  final double fontSize;

  const EmojiIcon({
    Key? key,
    required this.emoji,
    required this.onTap,
    this.fontSize = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(emoji),
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: fontSize,
        ),
      ),
    );
  }
}
