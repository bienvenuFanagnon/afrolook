import 'package:afrotok/pages/socialVideos/postVideos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../constant/logo.dart';
import '../style/theme.dart' as style;

import '../bloc/bottom_navbar_bloc.dart';
import 'home_screen/home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final BottomNavBarBloc _bottomNavBarBloc = BottomNavBarBloc();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _bottomNavBarBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Logo(),
            )
          ],
        ),
        body: StreamBuilder<NavBarItem>(
          stream: _bottomNavBarBloc.itemStream,
          initialData: _bottomNavBarBloc.defaultItem,
          builder: (BuildContext context, AsyncSnapshot<NavBarItem> snapshot) {
            switch (snapshot.data) {
              case NavBarItem.home:
                return  PostVideos();
              case NavBarItem.favourite:
                return Container();
              case NavBarItem.plus:
                return Container();
              case NavBarItem.search:
                return Container();
              case NavBarItem.profile:
                return Container();
              default:
                return Container();
            }
          },
        ),
        /*
        bottomNavigationBar: StreamBuilder(
          stream: _bottomNavBarBloc.itemStream,
          initialData: _bottomNavBarBloc.defaultItem,
          builder: (BuildContext context, AsyncSnapshot<NavBarItem> snapshot) {
            return Container(
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          width: 0.5, color: Colors.grey.withOpacity(0.4)))),
              child: BottomNavigationBar(
                elevation: 0.9,
                iconSize: 21,
                unselectedFontSize: 10.0,
                selectedFontSize: 10.0,
                type: BottomNavigationBarType.fixed,
                currentIndex: snapshot.data!.index,
                onTap: _bottomNavBarBloc.pickItem,
                items: [
                  BottomNavigationBarItem(
                    label: "Home",
                    icon: SizedBox(
                      child: SvgPicture.asset(
                        "assets/icons/home.svg",
                        color: Colors.white,
                        height: 25.0,
                        width: 25.0,
                      ),
                    ),
                    activeIcon: SizedBox(
                      child: SvgPicture.asset(
                        "assets/icons/home-active.svg",
                        color: style.Colors.mainColor,
                        height: 25.0,
                        width: 25.0,
                      ),
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: "Discover",
                    icon: SvgPicture.asset(
                      "assets/icons/search.svg",
                      color: Colors.white,
                      height: 25.0,
                      width: 25.0,
                    ),
                    activeIcon: SizedBox(
                      child: SvgPicture.asset(
                        "assets/icons/search-active.svg",
                        color: style.Colors.mainColor,
                        height: 25.0,
                        width: 25.0,
                      ),
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: "Liked",
                    icon: SvgPicture.asset(
                      "assets/icons/heart.svg",
                      color: Colors.white,
                      height: 25.0,
                      width: 25.0,
                    ),
                    activeIcon: SizedBox(
                      child: SvgPicture.asset(
                        "assets/icons/heart-active.svg",
                        color: style.Colors.mainColor,
                        height: 25.0,
                        width: 25.0,
                      ),
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: "Trending",
                    icon: SvgPicture.asset(
                      "assets/icons/trend.svg",
                      color: Colors.white,
                      height: 25.0,
                      width: 25.0,
                    ),
                    activeIcon: SizedBox(
                      child: SvgPicture.asset(
                        "assets/icons/trend-active.svg",
                        color: style.Colors.mainColor,
                        height: 25.0,
                        width: 25.0,
                      ),
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: "Profile",
                    icon: SvgPicture.asset(
                      "assets/icons/profile.svg",
                      color: Colors.white,
                      height: 25.0,
                      width: 25.0,
                    ),
                    activeIcon: SizedBox(
                      child: SvgPicture.asset(
                        "assets/icons/profile-active.svg",
                        color: style.Colors.mainColor,
                        height: 25.0,
                        width: 25.0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ));
    */
    );
  }
}
