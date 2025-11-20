import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../user/detailsOtherUser.dart';

void showUserDetailsModalDialog(UserData user, double w, double h, BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => UserProfileModal(
        user: user,
        w: w,
        h: h,
      ),
    ),
  );
}
