import 'package:afrotok/constant/constColors.dart';
import 'package:flutter/material.dart';

class ButtonWidget extends StatelessWidget {
  final String text;
  final VoidCallback onClicked;

  const ButtonWidget({
    Key? key,
    required this.text,
    required this.onClicked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ConstColors.buttonsColors,
          shape: StadiumBorder(),
       //   onPrimary: Colors.black,

          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        ),
        child: Text(text,style: TextStyle(fontSize: 15),),

        onPressed: onClicked,
      );
}
