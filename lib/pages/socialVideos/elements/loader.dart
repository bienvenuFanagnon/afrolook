import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget buildLoadingWidget() {
  return Container(
    color: Colors.black,
    child: Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        SizedBox(
          height: 100.0,
          width: 100.0,
          child: CupertinoActivityIndicator(color: Colors.green),

        )
      ],
    )),
  );
}
