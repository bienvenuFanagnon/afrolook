import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTextWidget extends StatelessWidget {
  final int startDateMillis;
  final int endDateMillis;

  const DateTextWidget({
    Key? key,
    required this.startDateMillis,
    required this.endDateMillis,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMillis);
    DateTime endDate = DateTime.fromMillisecondsSinceEpoch(endDateMillis);
    DateTime now = DateTime.now();

    String formattedStartDate = DateFormat('dd MMM yyyy').format(startDate);
    String formattedEndDate = DateFormat('dd MMM yyyy').format(endDate);

    Color startDateColor = startDate.isAfter(now) ? Colors.brown : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Début : ',
              style: TextStyle(fontSize: 16,),
            ),
            Text(
              ' $formattedStartDate',
              style: TextStyle(fontSize: 16, color: startDateColor),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              'Fin : ',
              style: TextStyle(fontSize: 16,),
            ),
            Text(
              ' $formattedEndDate',
              style: TextStyle(fontSize: 16, color: startDateColor),
            ),
          ],
        ),
      ],
    );
  }
}
