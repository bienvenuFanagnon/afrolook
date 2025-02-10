import 'dart:typed_data';
import 'package:afrotok/pages/userPosts/UniqueAfroDesign.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';

class Uniquedesign extends StatefulWidget {
  final Uint8List initialImage;
  final Canal? canal;

  const Uniquedesign({super.key, required this.initialImage, required this.canal});

  @override
  State<Uniquedesign> createState() => _UniquedesignState();
}

class _UniquedesignState extends State<Uniquedesign> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text("Vous êtes unique, alors Votre look sera unique", style: TextStyle(color: Colors.white,fontSize: 18,fontWeight: FontWeight.w900)),
        backgroundColor: Colors.green,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          child: Consumer<UserAuthProvider>(
            builder: (context, userProvider, child) {
              return                   UniqueAfrolookDesign(initialImage: widget.initialImage, canal: widget.canal==null?null:widget.canal!,);

            },
          ),
        ),
      ),
    );
  }
}
