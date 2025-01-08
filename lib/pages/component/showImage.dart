

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../models/model_data.dart';

void showImageDetailsModalDialog(String image, double w, double h,BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content:           ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(10),topRight: Radius.circular(10)),
          child: Container(
            // width: w,
            // height: h,
            child: CachedNetworkImage(
              fit: BoxFit.cover,

              imageUrl: '${image}',
              progressIndicatorBuilder: (context, url, downloadProgress) =>
              //  LinearProgressIndicator(),

              Skeletonizer(
                  child: SizedBox(width: 120,height: 100, child:  ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
              errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
            ),
          ),
        ),

      );
    },
  );
}
