import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../models/model_data.dart';

class RetraitPage extends StatefulWidget {
  @override
  _RetraitPageState createState() => _RetraitPageState();
}

class _RetraitPageState extends State<RetraitPage> {
  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  DateFormat formatter = DateFormat('dd MMMM yyyy');

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    double publiCash = authProvider.loginUserData.publi_cash ?? 0;
    double montantFcfa = publiCash * 50;

    return Scaffold(
      appBar: AppBar(
        title: Text('Monétisation', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(15.0),
        child: Column(
          children: [
            _buildSoldeCard(publiCash, montantFcfa),
            SizedBox(height: 20),
            Text(
              'Parrainez plus de personnes pour gagner plus de PubliCash !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 30),
            _buildRetraitButton(publiCash),
          ],
        ),
      ),
    );
  }

  Widget _buildSoldeCard(double publiCash, double montantFcfa) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.money, color: Colors.white, size: 40),
              IconButton(
                onPressed: () => setState(() => authProvider.getLoginUser(authProvider.loginUserData.id!)),
                icon: Icon(Icons.refresh, color: Colors.white, size: 30),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text('Votre Solde', style: TextStyle(fontSize: 18, color: Colors.white)),
          SizedBox(height: 5),
          Text('$publiCash PubliCash (PC)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.yellow)),
          SizedBox(height: 5),
          Text('$montantFcfa FCFA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildRetraitButton(double publiCash) {
    bool canWithdraw = publiCash > 600;
    return ElevatedButton(
      onPressed: () => _showRetraitDialog(canWithdraw),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        canWithdraw ? 'Faire une demande de Retrait' : 'Augmentez votre solde pour retirer',
        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showRetraitDialog(bool canWithdraw) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              canWithdraw
                  ? 'Félicitations ! Vous pouvez maintenant effectuer un retrait.'
                  : 'Vous devez avoir au moins 600 PC pour effectuer un retrait.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            canWithdraw
                ? Text('Les retraits seront disponibles bientôt. Continuez à parrainer !', textAlign: TextAlign.center)
                : Text('Invitez des amis pour gagner plus de PubliCash !', textAlign: TextAlign.center),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
