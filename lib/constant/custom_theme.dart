
import 'package:flutter/material.dart';

class CustomConstants  {
  // Colors
  static const Color kPrimaryColor =  Color(0xFFF0355E);
  static const Color kSecondaryColor =  Color(0xFFf68f13);
  static const Color kLightBackgroundColor=  Color(0xFFf4f9fc);
  static const Color kUnselectedIconColor =  Color(0xFFBBBABA);
  static const Color kWhiteColor =  Colors.white;
  static const Color kBlackColor =  Colors.black;

  static const Color noActiveBuild =  Color(0xFFE5E3E3);
  static const Color iconUnSelectColors =  Color(0xFF919191);

  // size
  static late MediaQueryData mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static double? defaultSize;
  static Orientation? orientation;

  void init(BuildContext context) {
    mediaQueryData = MediaQuery.of(context);

    screenWidth = mediaQueryData.size.width;
    screenHeight = mediaQueryData.size.height;
    orientation = mediaQueryData.orientation;
  }
}

// Get the proportionate height as per screen size
double getProportionateScreenHeight(double inputHeight) {
  double screenHeight = CustomConstants.screenHeight;
  return (inputHeight / 812.0) * screenHeight;
}

// Get the proportionate height as per screen size
double getProportionateScreenWidth(double inputWidth) {
  double screenWidth = CustomConstants.screenWidth;
  return (inputWidth / 375.0) * screenWidth;
}
