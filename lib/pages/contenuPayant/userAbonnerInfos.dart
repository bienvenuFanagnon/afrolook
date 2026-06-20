import 'package:afrotok/pages/contenuPayant/profileScreenContent.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/authProvider.dart';
import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../component/showUserDetails.dart';

class ContentOwnerInfo extends StatefulWidget {
  final String ownerId;

  const ContentOwnerInfo({required this.ownerId, Key? key}) : super(key: key);

  @override
  _ContentOwnerInfoState createState() => _ContentOwnerInfoState();
}

class _ContentOwnerInfoState extends State<ContentOwnerInfo> {
  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

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
    await userProvider.getUserById(widget.ownerId).then((value) {
      if (value.isNotEmpty) _owner = value.first;
    });
    _isSubscribed = _checkIfSubscribed(_currentUser, _owner);
    setState(() => _isLoading = false);
  }

  bool _checkIfSubscribed(UserData? currentUser, UserData? owner) {
    if (currentUser == null || owner == null) return false;
    return owner.userAbonnesIds?.contains(currentUser.id) ?? false;
  }

  void _toggleSubscribe() async {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    await userProvider.getUserById(widget.ownerId).then((users) async {
      if (users.isNotEmpty) showUserDetailsModalDialog(users.first, width, height, context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (_isLoading) return Center(child: CircularProgressIndicator(color: colors.primary));
    if (_owner == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreenContenu(userId: _owner!.id!))),
            child: CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(_cdnUrl(_owner!.imageUrl)),
              backgroundColor: colors.surfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${_owner!.pseudo ?? 'Utilisateur'}',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${_owner!.abonnes ?? 0} abonné(s)',
                    style: TextStyle(color: colors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _toggleSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSubscribed ? colors.textSecondary : colors.primary,
              foregroundColor: _isSubscribed ? colors.textPrimary : colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(_isSubscribed ? 'Abonné' : 'S\'abonner'),
          ),
        ],
      ),
    );
  }
}
