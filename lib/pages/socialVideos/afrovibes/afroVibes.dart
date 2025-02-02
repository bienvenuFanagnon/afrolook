import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class AfroVibesPage extends StatefulWidget {
  @override
  _AfroVibesPageState createState() => _AfroVibesPageState();
}

class _AfroVibesPageState extends State<AfroVibesPage> {
  final List<Map<String, dynamic>> chaineData = [
    {
      'titre': 'Chaine 1',
      'abonner': '500K',
      'logo': 'https://thumbor.comeup.com/unsafe/fit-in/630x354/filters:quality(90):no_upscale()/uploads/media/picture/2023-12-18/logo-youtube-657ffa0dbe57f.png',
      'videos': [
        {
          'urlvideo': 'https://www.youtube.com/watch?v=pFXm1yK22Ws',
          'like': '150',
          'comment': '50',
          'share': '20',
          'titre': 'Video 1',
          'thumbnail': 'https://img.youtube.com/vi/pFXm1yK22Ws/0.jpg'
        }
      ]
    },
    {
      'titre': 'Chaine 2',
      'abonner': '1M',
      'logo': 'https://thumbor.comeup.com/unsafe/fit-in/630x354/filters:quality(90):no_upscale()/uploads/media/picture/2023-12-18/logo-youtube-657ffa0dbe57f.png',
      'videos': [
        {
          'urlvideo': 'https://www.youtube.com/watch?v=gEbbHlMXE9Y',
          'like': '200',
          'comment': '80',
          'share': '30',
          'titre': 'Video 2',
          'thumbnail': 'https://img.youtube.com/vi/gEbbHlMXE9Y/0.jpg'
        }
      ]
    },
    {
      'titre': 'Chaine 3',
      'abonner': '750K',
      'logo': 'https://thumbor.comeup.com/unsafe/fit-in/630x354/filters:quality(90):no_upscale()/uploads/media/picture/2023-12-18/logo-youtube-657ffa0dbe57f.png',
      'videos': [
        {
          'urlvideo': 'https://www.youtube.com/watch?v=f2lNVCSMj8w',
          'like': '300',
          'comment': '120',
          'share': '50',
          'titre': 'Video 3',
          'thumbnail': 'https://img.youtube.com/vi/f2lNVCSMj8w/0.jpg'
        }
      ]
    }
  ];

  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: YoutubePlayer.convertUrlToId(chaineData[0]['videos'][0]['urlvideo']!)!,
      flags: YoutubePlayerFlags(autoPlay: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AfroVibes'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          YoutubePlayer(controller: _controller),
          SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: chaineData.length,
              itemBuilder: (context, index) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.load(YoutubePlayer.convertUrlToId(chaineData[index]['videos'][0]['urlvideo']!)!);
                        });
                      },
                      child: Image.network(
                        chaineData[index]['videos'][0]['thumbnail']!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[300],
                            child: Center(
                              child: Text(
                                'AfroVibes',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Image.network(
                            chaineData[index]['logo']!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chaineData[index]['videos'][0]['titre']!,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                chaineData[index]['titre']!,
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              Text(
                                'Abonnés: ${chaineData[index]['abonner']}',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.thumb_up, color: Colors.green),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.comment, color: Colors.green),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.share, color: Colors.green),
                                    onPressed: () {},
                                  ),
                                ],
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
}