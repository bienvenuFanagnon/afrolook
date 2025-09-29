
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/custom_theme.dart';
import '../../../models/model_data.dart';
import '../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../component/consoleWidget.dart';
import '../../user/conponent.dart';
import 'acceuil/home_afroshop.dart';
import 'acceuil/produit_details.dart';

class ArticleTile extends StatefulWidget {
  final ArticleData article;
  final double w;
  final double h;

  ArticleTile({super.key, required this.article, required this.w, required this.h});

  @override
  State<ArticleTile> createState() => _ArticleTileState();
}

class _ArticleTileState extends State<ArticleTile> {
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);

  bool _isLoading = false;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Widget _buildStatItem(IconData icon, int count, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 4),
            Text(
              _formatCount(count),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int? count) {
    if (count == null) return "0";
    if (count < 1000) return count.toString();
    if (count < 1000000) return "${(count / 1000).toStringAsFixed(1)}K";
    return "${(count / 1000000).toStringAsFixed(1)}M";
  }

  Future<void> _handleProductTap() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await categorieProduitProvider.getArticleById(widget.article.id!).then((value) async {
        if (value.isNotEmpty) {
          value.first.vues = value.first.vues! + 1;
          widget.article.vues = value.first.vues!;
          await categorieProduitProvider.updateArticle(value.first, context);

          await authProvider.getUserById(widget.article.user_id!).then((users) async {
            if (users.isNotEmpty) {
              widget.article.user = users.first;
              await postProvider.getEntreprise(widget.article.user_id!).then((entreprises) {
                if (entreprises.isNotEmpty) {
                  entreprises.first.suivi = entreprises.first.usersSuiviId!.length;
                  setState(() {
                    _isLoading = false;
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProduitDetail(article: widget.article, entrepriseData: entreprises.first),
                    ),
                  );
                }
              });
            }
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error navigating to product: $e");
    }
  }

  Future<bool> _handleLike() async {
    try {
      await categorieProduitProvider.getArticleById(widget.article.id!).then((value) {
        if (value.isNotEmpty) {
          value.first.jaime = value.first.jaime! + 1;
          widget.article.jaime = value.first.jaime!;
          categorieProduitProvider.updateArticle(value.first, context).then((value) async {
            if (value) {
              await authProvider.sendNotification(
                userIds: [widget.article.user!.oneIgnalUserid!],
                smallImage: "${widget.article.images!.first}",
                send_user_id: "${authProvider.loginUserData.id!}",
                recever_user_id: "${widget.article.user!.id!}",
                message: "📢 🛒 Un afrolookeur aime ❤️ votre produit 🛒",
                type_notif: NotificationType.ARTICLE.name,
                post_id: "${widget.article!.id!}",
                post_type: PostDataType.IMAGE.name,
                chat_id: '',
              );

              NotificationData notif = NotificationData();
              notif.id = firestore.collection('Notifications').doc().id;
              notif.titre = " 🛒Boutique 🛒";
              notif.media_url = "${widget.article.images!.first}";
              notif.type = NotificationType.ARTICLE.name;
              notif.description = "Un afrolookeur aime ❤️ votre produit 🛒";
              notif.users_id_view = [];
              notif.user_id = authProvider.loginUserData.id;
              notif.receiver_id = widget.article.user!.id!;
              notif.post_id = widget.article.id!;
              notif.post_data_type = PostDataType.IMAGE.name!;
              notif.updatedAt = DateTime.now().microsecondsSinceEpoch;
              notif.createdAt = DateTime.now().microsecondsSinceEpoch;
              notif.status = PostStatus.VALIDE.name;

              await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
            }
          });
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.8),
              CustomConstants.kPrimaryColor.withOpacity(0.1),
              Colors.amber.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: CustomConstants.kPrimaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CustomConstants.kPrimaryColor.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Effet de bordure colorée


            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image section avec effet de bordure
                GestureDetector(
                  onTap: _handleProductTap,
                  child: Container(
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: widget.w * 0.5,
                        height: widget.h * 0.18,
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              imageUrl: '${widget.article.images!.first}',
                              progressIndicatorBuilder: (context, url, downloadProgress) =>
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.grey[300]!,
                                          Colors.grey[200]!,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: downloadProgress.progress,
                                        strokeWidth: 2,
                                        color: CustomConstants.kPrimaryColor,
                                      ),
                                    ),
                                  ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.grey[300]!,
                                      Colors.grey[200]!,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.shopping_bag_rounded,
                                    color: Colors.grey[500],
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),

                            // Badge de prix avec effet dégradé
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.9),
                                      CustomConstants.kPrimaryColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.6),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${widget.article.prix} Fcfa',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 2,
                                            offset: Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                      child: countryFlag(
                                        widget.article.countryData == null
                                            ? 'TG'
                                            : widget.article.countryData!['countryCode'] ?? "TG",
                                        size: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Overlay de dégradé en bas de l'image
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Content section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Titre avec effet
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            "${(widget.article.titre ?? 'Produit').trim().isEmpty
                                ? 'Produit'
                                : (widget.article.titre![0].toUpperCase() + widget.article.titre!.substring(1).toLowerCase())}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 1, // 👉 une seule ligne
                            overflow: TextOverflow.ellipsis, // 👉 coupe si trop long
                          ),
                        ),

                        SizedBox(height: 2),

                        // Stats row - seulement 3 icônes maintenant
                        Container(
                          height: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // Vues
                              _buildStatItem(
                                Icons.remove_red_eye_rounded,
                                widget.article.vues ?? 0,
                                Colors.grey[700]!,
                              ),

                              // Contact WhatsApp
                              _buildStatItem(
                                FontAwesome.whatsapp,
                                widget.article.contact ?? 0,
                                Color(0xFF25D366),
                              ),

                              // Likes avec effet spécial
                              GestureDetector(
                                onTap: _handleLike,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red.shade400,
                                        Colors.red.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FontAwesome.heart, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        _formatCount(widget.article.jaime ?? 0),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Loading overlay avec effet
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Container(
                      width: 120,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black,
                            CustomConstants.kPrimaryColor.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: CustomConstants.kPrimaryColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Chargement...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 2,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}



class ArticleTileBooster extends StatefulWidget {
  final ArticleData article;
  final double w;
  final double h;
  final bool isOtherPage;

  ArticleTileBooster({required this.article, required this.w, required this.h, required this.isOtherPage});

  @override
  _ArticleTileBoosterState createState() => _ArticleTileBoosterState();
}

class _ArticleTileBoosterState extends State<ArticleTileBooster> {
  bool _isLoading = false;
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        color: Colors.lightGreen.shade300,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () async {
                setState(() {
                  _isLoading = true;
                });

                await categorieProduitProvider.getArticleById(widget.article.id!).then((value) async {
                  if (value.isNotEmpty) {
                    value.first.vues = value.first.vues! + 1;
                    widget.article.vues = value.first.vues! + 1;
                    categorieProduitProvider.updateArticle(value.first, context).then((value) {
                      if (value) {
                        // Additional logic here
                      }
                    });
                    await authProvider.getUserById(widget.article.user_id!).then((users) async {
                      if (users.isNotEmpty) {
                        widget.article.user = users.first;
                        await postProvider.getEntreprise(widget.article.user_id!).then((entreprises) {
                          if (entreprises.isNotEmpty) {
                            entreprises.first.suivi = entreprises.first.usersSuiviId!.length;
                            setState(() {
                              _isLoading = false;
                            });
                            if(widget.isOtherPage){
                              Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''),));

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProduitDetail(article: widget.article, entrepriseData: entreprises.first),
                                ),
                              );
                            }else{
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProduitDetail(article: widget.article, entrepriseData: entreprises.first),
                                ),
                              );
                            }

                          }
                        });
                      }
                    });
                  }
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(5)),
                child: Container(
                  width: widget.w * 0.6,
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,
                    imageUrl: '${widget.article.images!.first}',
                    progressIndicatorBuilder: (context, url, downloadProgress) => Skeletonizer(
                      child: SizedBox(
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          child: Image.network('${widget.article.images!.first}'),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      child: Image.network('${widget.article.images!.first}', fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.withOpacity(0.7),
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prix: ${widget.article.prix} Fcfa',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    countryFlag(widget.article.countryData==null?"TG":widget.article.countryData!['countryCode']??"TG"!, size: 20),

                    Text(
                      'Vues: ${widget.article.vues}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Icon(
                  Fontisto.fire,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            ),
            if (_isLoading)
              ModalBarrier(
                color: Colors.black.withOpacity(0.5),
                dismissible: false,
              ),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}


class ArticleTileSheetBooster extends StatefulWidget {
  final ArticleData article;
  final double w;
  final double h;
  final bool isOtherPage;

  ArticleTileSheetBooster({
    required this.article,
    required this.w,
    required this.h,
    required this.isOtherPage,
    Key? key,
  }) : super(key: key);

  @override
  _ArticleTileSheetBoosterState createState() => _ArticleTileSheetBoosterState();
}

class _ArticleTileSheetBoosterState extends State<ArticleTileSheetBooster> {
  bool _isLoading = false;
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: widget.w * 0.6,
        height: widget.h * 0.44,
        child: Container(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () async {
                  setState(() {
                    _isLoading = true;
                  });

                  await categorieProduitProvider
                      .getArticleById(widget.article.id!)
                      .then((value) async {
                    if (value.isNotEmpty) {
                      value.first.vues = value.first.vues! + 1;
                      widget.article.vues = value.first.vues! + 1;
                      categorieProduitProvider
                          .updateArticle(value.first, context)
                          .then((value) {
                        if (value) {
                          // Additional logic here
                        }
                      });
                      await authProvider
                          .getUserById(widget.article.user_id!)
                          .then((users) async {
                        if (users.isNotEmpty) {
                          widget.article.user = users.first;
                          await postProvider
                              .getEntreprise(widget.article.user_id!)
                              .then((entreprises) {
                            if (entreprises.isNotEmpty) {
                              entreprises.first.suivi =
                                  entreprises.first.usersSuiviId!.length;
                              setState(() {
                                _isLoading = false;
                              });
                              if (widget.isOtherPage) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          HomeAfroshopPage(title: ''),
                                    ));

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProduitDetail(
                                        article: widget.article,
                                        entrepriseData: entreprises.first),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProduitDetail(
                                        article: widget.article,
                                        entrepriseData: entreprises.first),
                                  ),
                                );
                              }
                            }
                          });
                        }
                      });
                    }
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10), topRight: Radius.circular(5)),
                  child: Container(
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: '${widget.article.images!.first}',
                      progressIndicatorBuilder:
                          (context, url, downloadProgress) => Skeletonizer(
                        child: SizedBox(
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            child: Image.network('${widget.article.images!.first}'),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        child: Image.network('${widget.article.images!.first}',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.red.withOpacity(0.7),
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Prix: ${widget.article.prix} Fcfa',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                      Text(
                        'Vues: ${widget.article.vues}',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Icon(
                    Fontisto.fire,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
              ),
              if (_isLoading)
                ModalBarrier(
                  color: Colors.black.withOpacity(0.5),
                  dismissible: false,
                ),
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class ProductWidget extends StatelessWidget {
  final ArticleData article;
  final double width;
  final double height;
  final bool isOtherPage;

  const ProductWidget({
    Key? key,
    required this.article,
    required this.width,
    required this.height,
    required this.isOtherPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final afroGreen = Color(0xFF2ECC71);
    final afroYellow = Color(0xFFF1C40F);
    final afroBlack = Color(0xFF000000);

    return GestureDetector(
      onTap: () => _navigateToProductDetail(context),
      child: Container(
        width: width * 0.28,
        height: width * 0.28,
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: afroBlack.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: afroGreen.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: afroGreen.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Image qui occupe tout le widget
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: article.images?.first ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: afroBlack,
                  child: Icon(Icons.shopping_bag, color: afroGreen, size: 24),
                ),
                errorWidget: (context, url, error) => Container(
                  color: afroBlack,
                  child: Icon(Icons.shopping_bag, color: afroGreen, size: 24),
                ),
              ),
            ),

            // Overlay sombre pour la lisibilité
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                ),
              ),
            ),

            // Prix en bas à gauche
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: afroGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${article.prix} Fcfa',
                  style: TextStyle(
                    color: afroBlack,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Drapeau en haut à droite
            Positioned(
              top: 6,
              right: 6,
              child: countryFlag(
                article.countryData?['countryCode'] ?? "TG",
                size: 16,
              ),
            ),

            // Badge "BOOST" en haut à gauche
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: afroYellow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Fontisto.fire, color: afroBlack, size: 10),
                    SizedBox(width: 2),
                    Text(
                      'BOOST',
                      style: TextStyle(
                        color: afroBlack,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nombre de vues en bas à droite
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: afroBlack.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.remove_red_eye, color: afroGreen, size: 10),
                    SizedBox(width: 2),
                    Text(
                      '${article.vues ?? 0}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _navigateToProductDetail(BuildContext context) async {
    final categorieProduitProvider =
    Provider.of<CategorieProduitProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    // Affiche le loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
      ),
    );

    try {
      // Incrémenter les vues
      final article =
      await categorieProduitProvider.getArticleById(this.article.id!);
      if (article.isNotEmpty) {
        article.first.vues = (article.first.vues ?? 0) + 1;
        categorieProduitProvider.updateArticle(article.first, context);
      }

      // Récupérer les données utilisateur et entreprise
      final users = await authProvider.getUserById(this.article.user_id!);
      if (users.isNotEmpty) {
        this.article.user = users.first;
        final entreprises = await postProvider.getEntreprise(this.article.user_id!);
        if (entreprises.isNotEmpty) {
          Navigator.pop(context); // Ferme le loader avant la navigation
          if (isOtherPage) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomeAfroshopPage(title: '')),
            );
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProduitDetail(
                article: this.article,
                entrepriseData: entreprises.first,
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      Navigator.pop(context); // Ferme le loader si erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors du chargement")),
      );
    }
    Navigator.pop(context); // Ferme le loader si pas de données
  }

  void _navigateToProductDetail2(BuildContext context) async {
    final categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    // Incrémenter les vues
    final article = await categorieProduitProvider.getArticleById(this.article.id!);
    if (article.isNotEmpty) {
      article.first.vues = (article.first.vues ?? 0) + 1;
      categorieProduitProvider.updateArticle(article.first, context);
    }

    // Récupérer les données utilisateur et entreprise
    final users = await authProvider.getUserById(this.article.user_id!);
    if (users.isNotEmpty) {
      this.article.user = users.first;
      final entreprises = await postProvider.getEntreprise(this.article.user_id!);
      if (entreprises.isNotEmpty) {
        if (isOtherPage) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => HomeAfroshopPage(title: '')));
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProduitDetail(article: this.article, entrepriseData: entreprises.first),
          ),
        );
      }
    }
  }
}



