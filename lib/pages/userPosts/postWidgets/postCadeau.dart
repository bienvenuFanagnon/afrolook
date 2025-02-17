import 'package:flutter/material.dart';

class GiftDialog extends StatelessWidget {
  final Function(String, int) onGiftSelected;
  late bool isLoading =false;

  GiftDialog({required this.onGiftSelected, required this.isLoading});

  final List<Map<String, dynamic>> gifts = [
    {'emoji': '🎁', 'name': 'Cadeau Simple', 'price': 2},
    {'emoji': '❤️', 'name': 'Cœur', 'price': 4},
    {'emoji': '🥉', 'name': 'Bronze', 'price': 20},
    {'emoji': '🥈', 'name': 'Argent', 'price': 40},
    {'emoji': '🥇', 'name': 'Or', 'price': 120},
    {'emoji': '💎', 'name': 'Diamant', 'price': 200},

  ];

  String? selectedGift;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: Colors.yellow.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Center(
            child: Text(
              'Choisir un cadeau',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 15,
                runSpacing: 15,
                alignment: WrapAlignment.center,
                children: gifts.map((gift) {
                  return GestureDetector(
                    onTap: () => setState(() => selectedGift = gift['emoji']),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 2),
                            ],
                            border: selectedGift == gift['emoji'] ? Border.all(color: Colors.green, width: 3) : null,
                          ),
                          child: Text(
                            gift['emoji'],
                            style: TextStyle(fontSize: 30),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          gift['name'],
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        Text(
                          '${gift['price']} PC',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        if (selectedGift == gift['emoji'])
                          Container(
                            margin: EdgeInsets.only(top: 5),
                            height: 2,
                            width: 40,
                            color: Colors.green,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Fermer'),
                  ),
                  isLoading?Center(child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator())): ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: selectedGift != null
                        ? () => onGiftSelected(selectedGift!, gifts.firstWhere((gift) => gift['emoji'] == selectedGift)['price'])
                        : null,
                    child: Text('Envoyer'),
                  ),

                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
