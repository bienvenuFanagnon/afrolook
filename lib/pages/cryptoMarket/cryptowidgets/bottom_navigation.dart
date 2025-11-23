import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class BottomNavigation extends StatefulWidget {
  @override
  _BottomNavigationState createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C).withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Color(0xFF00B894),
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: _currentIndex == 0
                    ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                )
                    : null,
                child: Icon(Iconsax.home_2),
              ),
              label: 'Marché',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: _currentIndex == 1
                    ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                )
                    : null,
                child: Icon(Iconsax.wallet_3),
              ),
              label: 'Portefeuille',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: _currentIndex == 2
                    ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                )
                    : null,
                child: Icon(Iconsax.graph),
              ),
              label: 'Trading',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: _currentIndex == 3
                    ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                )
                    : null,
                child: Icon(Iconsax.user),
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}