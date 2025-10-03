import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({Key? key}) : super(key: key);

  @override
  State<ContactPage> createState() => _AidePageState();
}

class _AidePageState extends State<ContactPage> {
  List<String> attachments = [];

  String _nom = '';
  String _email = 'mykeys@my-keys.com';
  String _message = '';
  bool tap = false;

  final _formKey = GlobalKey<FormState>();

  bool isHTML = false;

  final _subjectController = TextEditingController(text: "Demande d'information");

  final _bodyController = TextEditingController();

  final _recipientController = TextEditingController(
    text: 'mykeys@my-keys.com',
  );

  Future sendEmail(String emailText) async {
    final Email email = Email(
      body: '${_bodyController.text}',
      subject: _subjectController.text,
      recipients: [emailText],
      attachmentPaths: attachments,
      isHTML: isHTML,
    );

    String platformResponse;

    try {
      var response = await FlutterEmailSender.send(email);
      platformResponse = 'success';
      _bodyController.text = '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Votre message a été envoyé.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (error) {
      print(error);
      platformResponse = error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message non envoyé', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;
  }

  Future<void> launchWhatsApp(String phone) async {
    String url = "https://wa.me/$phone";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(
        duration: Duration(seconds: 2),
        content: Text("Impossible d'ouvrir WhatsApp", textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir le lien', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _email = 'mykeys@my-keys.com';
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactez-nous', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.green),
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Comment pouvons-nous vous aider?',
                  style: TextStyle(fontSize: 20.0, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 20),

              // NOUVEAU: WhatsApp Support en première position
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[800]!, Colors.green[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Icon(FontAwesome.whatsapp, size: 40, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Support WhatsApp Direct',
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '+228 71 64 54 03',
                      style: TextStyle(fontSize: 16, color: Colors.yellow[700], fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Contactez-nous directement sur WhatsApp pour une assistance rapide',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: Icon(FontAwesome.whatsapp, color: Colors.white),
                      label: Text('Écrire sur WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.green[700],
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        launchWhatsApp('22871645403');
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Canal WhatsApp Officiel
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green[900],
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.notifications, size: 35, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Canal WhatsApp Officiel',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Restez informé des dernières actualités',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: Icon(FontAwesome.whatsapp, color: Colors.white, size: 18),
                      label: Text('Rejoindre le Canal'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.green[700],
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        _launchURL('https://whatsapp.com/channel/0029VaxfuwYISTkF3o42e60V');
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Bouton Facebook
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue[900],
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Icon(FontAwesome.facebook, size: 40, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Vous préférez nous écrire sur Facebook?',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Notre équipe répond rapidement à vos messages sur notre page Facebook',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: Icon(FontAwesome.facebook, color: Colors.white),
                      label: Text('Écrire sur Facebook'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue[700],
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        _launchURL('https://www.facebook.com/profile.php?id=61554481360821');
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              // Section YouTube
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Icon(FontAwesome.youtube_play, size: 40, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Chaîne YouTube Officielle',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Regardez nos tutoriels et guides vidéo',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: Icon(FontAwesome.youtube_play, color: Colors.white, size: 18),
                      label: Text('Voir les Tutoriels'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red[700],
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        _launchURL('https://youtube.com/@afrolookstudioofficiel?si=3wWf802tZbGVEeC_');
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              Text(
                'Ou contactez-nous par email:',
                style: TextStyle(fontSize: 16.0, color: Colors.grey),
              ),
              SizedBox(height: 20),

              // Option 1: Support général
              Card(
                color: Colors.green[900],
                child: ListTile(
                  leading: Icon(Icons.email, color: Colors.white),
                  title: Text('Support général', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Informations générales, signaler un problème', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    sendEmail('officiel.afrolook@gmail.com');
                  },
                ),
              ),
              SizedBox(height: 15),

              // Option 2: Investissements
              Card(
                color: Colors.green[800],
                child: ListTile(
                  leading: Icon(Icons.attach_money, color: Colors.white),
                  title: Text('Investissements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Informations pour les investisseurs', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    sendEmail('officiel.afrolook.investissement@gmail.com');
                  },
                ),
              ),
              SizedBox(height: 15),

              // Option 3: Publicité
              Card(
                color: Colors.green[700],
                child: ListTile(
                  leading: Icon(Icons.campaign, color: Colors.white),
                  title: Text('Publicité Afrolook Ads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Pour vos campagnes publicitaires', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    sendEmail('officiel.afrolook.annonce@gmail.com');
                  },
                ),
              ),
              SizedBox(height: 30),

              // Section Réseaux sociaux
              Center(
                child: Text(
                  'Rejoignez-nous sur les réseaux sociaux',
                  style: TextStyle(fontSize: 18.0, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Groupe Facebook
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(FontAwesome.facebook, color: Colors.blue, size: 40),
                        onPressed: () {
                          _launchURL('https://facebook.com/groups/28745647531687196/');
                        },
                      ),
                      Text('Groupe Facebook', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  // Page Facebook
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(FontAwesome.facebook_square, color: Colors.blue, size: 40),
                        onPressed: () {
                          _launchURL('https://www.facebook.com/profile.php?id=61554481360821');
                        },
                      ),
                      Text('Page Facebook', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  // Twitter/X
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(FontAwesome.twitter, color: Colors.lightBlue, size: 40),
                        onPressed: () {
                          _launchURL('https://x.com/Afrolook2?t=_Sv_PF1PnaE58CnlqiSKuQ&s=09');
                        },
                      ),
                      Text('Twitter/X', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Section pour ceux qui ont des difficultés
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vous avez des difficultés?',
                      style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Rejoignez notre communauté sur Facebook pour obtenir de l\'aide:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: Icon(FontAwesome.facebook, color: Colors.white),
                      label: Text('Rejoindre le groupe Facebook'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue[800],
                      ),
                      onPressed: () {
                        _launchURL('https://facebook.com/groups/28745647531687196/');
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}