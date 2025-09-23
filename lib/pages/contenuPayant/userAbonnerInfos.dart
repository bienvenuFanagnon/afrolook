import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/authProvider.dart';
import '../../models/model_data.dart';
import '../component/showUserDetails.dart';

class ContentOwnerInfo extends StatefulWidget {
  final String ownerId;

  const ContentOwnerInfo({required this.ownerId, Key? key}) : super(key: key);

  @override
  _ContentOwnerInfoState createState() => _ContentOwnerInfoState();
}

class _ContentOwnerInfoState extends State<ContentOwnerInfo> {
  bool _isSubscribed = false;
  bool _isLoading = true;
  UserData? _owner;
  UserData? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadOwnerInfo();
  }

  Future<void> _loadOwnerInfo() async {
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentUser = userProvider.loginUserData;

    // Récupération des infos de l'utilisateur propriétaire
     await userProvider.getUserById(widget.ownerId).then((value) {
      if(value.isNotEmpty){
        _owner = value.first;
      }
    },);

    // Vérification si l'utilisateur courant est abonné
    _isSubscribed = _checkIfSubscribed(_currentUser, _owner);

    setState(() => _isLoading = false);
  }

  // Fonction de vérification d'abonnement
  bool _checkIfSubscribed(UserData? currentUser, UserData? owner) {
    if (currentUser == null || owner == null) return false;
    return owner.userAbonnesIds?.contains(currentUser.id) ?? false;
  }

  void _toggleSubscribe() async {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);

    await userProvider.getUserById(widget.ownerId!).then((users) async {
      if (users.isNotEmpty) {
        showUserDetailsModalDialog(users.first, width, height, context);
      }
    });
    // final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    // setState(() => _isLoading = true);

    // if (_isSubscribed) {
    //   await userProvider.unsubscribe(widget.ownerId);
    //   _owner?.userAbonnesIds?.remove(_currentUser?.id);
    // } else {
    //   await userProvider.subscribe(widget.ownerId);
    //   _owner?.userAbonnesIds?.add(_currentUser!.id!);
    // }

    // _isSubscribed = !_isSubscribed;
    // setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: Colors.green));
    if (_owner == null) return SizedBox();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(_owner!.imageUrl ?? ''),
            backgroundColor: Colors.grey[800],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("@${_owner!.pseudo?? 'Utilisateur' }",
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('${_owner!.abonnes ?? 0} abonné(s)',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _toggleSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSubscribed ? Colors.grey : Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(_isSubscribed ? 'Abonné' : 'S’abonner'),
          ),
        ],
      ),
    );
  }
}
