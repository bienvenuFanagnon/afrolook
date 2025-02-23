import 'package:flutter/material.dart';

class TokenPurchaseDialog extends StatelessWidget {
  final Function(String, double,int) onTokenSelected;
  final bool isLoading;

  TokenPurchaseDialog({
    required this.onTokenSelected,
    required this.isLoading,
  });

  final List<Map<String, dynamic>> tokens = [
    {
      'emoji': '💰',
      'name': '50K Tokens',
      'pricePC': 300/25,
      'priceXOF': 300, // Conversion de PC à XOF
      'summary': 50000
    },
    {
      'emoji': '💎',
      'name': '120K Tokens',
      'pricePC': 500/25,
      'priceXOF': 500, // Conversion de PC à XOF
      'summary': 120000
    },
    {
      'emoji': '✨',
      'name': '250k Tokens',
      'pricePC': 900/25,
      'priceXOF': 900, // Conversion de PC à XOF
      'summary': 250000
    },
    {
      'emoji': '🌟',
      'name': '550k Tokens',
      'pricePC': 1700/25,
      'priceXOF': 1700, // Conversion de PC à XOF
      'summary': 550000
    },
  ];

  String? selectedToken;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Center(
            child: Text(
              'Acheter des Tokens',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 15,
                runSpacing: 15,
                alignment: WrapAlignment.center,
                children: tokens.map((token) {
                  return GestureDetector(
                    onTap: () => setState(() => selectedToken = token['emoji']),
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
                            border: selectedToken == token['emoji'] ? Border.all(color: Colors.blue, width: 3) : null,
                          ),
                          child: Text(
                            token['emoji'],
                            style: TextStyle(fontSize: 30),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          token['name'],
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        // Text(
                        //   '${token['summary']}',
                        //   style: TextStyle(fontSize: 12, color: Colors.black54),
                        // ),
                        // Text(
                        //   '${token['pricePC']} PC',
                        //   style: TextStyle(fontSize: 12, color: Colors.black54),
                        // ),
                        Text(
                          '${token['priceXOF'].toStringAsFixed(2)} XOF',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        if (selectedToken == token['emoji'])
                          Container(
                            margin: EdgeInsets.only(top: 5),
                            height: 2,
                            width: 40,
                            color: Colors.blue,
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
                  isLoading
                      ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator()))
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: selectedToken != null
                        ? () => onTokenSelected(selectedToken!, tokens.firstWhere((token) => token['emoji'] == selectedToken)['pricePC'],tokens.firstWhere((token) => token['emoji'] == selectedToken)['summary'])
                        : null,
                    child: Text('Acheter'),
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
