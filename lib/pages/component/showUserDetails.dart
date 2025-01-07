import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../user/detailsOtherUser.dart';

void showUserDetailsModalDialog(UserData user, double w, double h,BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: DetailsOtherUser(
          user: user,
          w: w,
          h: h,
        ),
      );
    },
  );
}
