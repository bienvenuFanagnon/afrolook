import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

Widget buildErrorWidget(String error) {
  return Center(
    child: Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            height: 140.0,
            width: 140.0,
            child: SvgPicture.asset(
              "assets/icons/warning.svg",
            ),
          ),
          const SizedBox(
            height: 25.0,
          ),
          const Text(
            "Erreur",
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

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
