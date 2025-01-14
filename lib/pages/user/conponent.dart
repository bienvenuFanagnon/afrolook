 import 'package:country_flags/country_flags.dart';
import 'package:flutter/cupertino.dart';

Widget countryFlag(String? code,{required double size}){
  return code==null?Container(): CountryFlag.fromCountryCode(code,width: size,height: size!,  shape: const Circle(),
  );
}
