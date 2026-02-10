import 'package:flutter/material.dart';

class NumbersWidget extends StatelessWidget {
  final int followers;
  final int points;
  final double taux;
  NumbersWidget({required this.followers, required this.taux, required this.points});
  String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return "${number / 1000} k";
    } else if (number < 1000000000) {
      return "${number / 1000000} m";
    } else {
      return "${number / 1000000000} b";
    }
  }
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          buildButton(context, '${(taux/100).toStringAsFixed(2)}%', 'Popularité'),
          buildDivider(),
          buildButton(context, '${formatNumber(followers)}', 'Abonné(s)'),
          buildDivider(),
          buildButton(context, '${formatNumber(points)}', 'Points'),
        ],
      );
  Widget buildDivider() => Container(
        height: 24,
        child: VerticalDivider(),
      );

  Widget buildButton(BuildContext context, String value, String text) =>
      MaterialButton(
        padding: EdgeInsets.symmetric(vertical: 4),
        onPressed: () {},
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24,color: Colors.yellow),
            ),
            SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white),
            ),
          ],
        ),
      );
}
