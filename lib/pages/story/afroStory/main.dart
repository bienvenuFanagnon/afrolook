// import 'package:flutter/material.dart';
//
//
// void main() => runApp(MyApp());
//
// class MyApp extends StatelessWidget {
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Story Demo',
//       theme: ThemeData(
//         accentColor: Colors.red,
//       ),
//       home: NavigationPage(),
//     );
//   }
// }
//
// class NavigationPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         title: Text(
//           "Story Demo",
//           style: TextStyle(
//             color: Colors.black,
//             fontSize: 16,
//           ),
//         ),
//       ),
//       body: Padding(
//         padding: EdgeInsets.symmetric(
//           horizontal: 16,
//           vertical: 16,
//         ),
//         child: Column(
//           children: <Widget>[
//             Center(
//               child: Text(
//                 "Story View Demos",
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             SizedBox(
//               height: 16,
//             ),
//             Center(
//               child: Text(
//                 "An exhibit on the capabilities of the story_view library for Flutter. Enjoy!",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: Colors.grey,
//                 ),
//               ),
//             ),
//             SizedBox(
//               height: 24,
//             ),
//             NavigationItem(
//               title: "Google News Example",
//               description:
//                   "A look at inline stories just like Google News highlights",
//               icon: Image.asset("assets/images/gnews.png"),
//               onTap: () {
//                 Navigator.of(context).push(
//                   MaterialPageRoute(builder: (context) => GnewsView()),
//                 );
//               },
//             ),
//             SizedBox(
//               height: 16,
//             ),
//             NavigationItem(
//               title: "Whatsapp Custom Story",
//               description: "Demo on full page stories with customizations",
//               icon: Image.asset("assets/images/whatsapp.png"),
//               onTap: () {
//                 Navigator.of(context).push(
//                   MaterialPageRoute(builder: (context) => Whatsapp()),
//                 );
//               },
//             ),
//             Expanded(
//               child: SizedBox(),
//             ),
//             Column(
//               children: <Widget>[
//                 Text(
//                   "Powered by",
//                   style: TextStyle(
//                     color: Colors.grey,
//                   ),
//                 ),
//                 Text(
//                   "github/blackmann",
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 18,
//                   ),
//                 )
//               ],
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
//
