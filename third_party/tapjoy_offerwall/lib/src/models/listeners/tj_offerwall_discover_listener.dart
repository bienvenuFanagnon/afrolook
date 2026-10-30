import 'package:flutter/services.dart';

const String TJOWDRequestDidSucceedForViewListener = "requestDidSucceedForView";
const String TJOWDContentIsReadyForViewListener = "contentIsReadyForView";
const String TJOWDRequestDidFailForViewListener = "requestDidFailForView";
const String TJOWDContentErrorForViewListener = "contentErrorForView";


typedef EventListener = void Function(Map<String, dynamic> event);
typedef ErrorListener = void Function(PlatformException);
