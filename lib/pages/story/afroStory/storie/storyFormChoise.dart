import 'package:afrotok/pages/story/afroStory/storie/storyImageForm.dart';
import 'package:afrotok/pages/story/afroStory/storie/storyTextForm.dart';
import 'package:flutter/material.dart';

class StoryChoicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Afro Chronique',style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddTextStoryPage()),
                );
              },
              child: Text('Ajouter une chronique Texte',style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddImageStoryPage()),
                );
              },
              child: Text('Ajouter une chronique Image',style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            // ElevatedButton(
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => AddVideoStoryPage()),
            //     );
            //   },
            //   child: Text('Ajouter une Vidéo'),
            //   style: ElevatedButton.styleFrom(primary: Colors.green),
            // ),
          ],
        ),
      ),
    );
  }
}
