// admin_email_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminEmailScreen extends StatefulWidget {
  @override
  _AdminEmailScreenState createState() => _AdminEmailScreenState();
}

class _AdminEmailScreenState extends State<AdminEmailScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _searchController = TextEditingController();

  String _targetType = "all";
  bool _isSending = false;
  List<String> _selectedUsers = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoadingUsers = false;
  int _estimatedCount = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Color africanBlack = Color(0xFF1A1A1A);
  final Color africanRed = Color(0xFFE63946);
  final Color africanGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
    _loadUsers();

    // Ajouter des listeners pour mettre à jour l'aperçu
    _subjectController.addListener(_updatePreview);
    _messageController.addListener(_updatePreview);
    _imageUrlController.addListener(_updatePreview);
  }

  void _updatePreview() {
    setState(() {}); // Rafraîchir l'aperçu
  }

  @override
  void dispose() {
    _subjectController.removeListener(_updatePreview);
    _messageController.removeListener(_updatePreview);
    _imageUrlController.removeListener(_updatePreview);
    _animationController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _imageUrlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('email', isNotEqualTo: null)
          .where('email', isNotEqualTo: '')
          .get();

      _users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'pseudo': data['pseudo'] ?? 'Sans pseudo',
          'email': data['email'],
          'imageUrl': data['imageUrl'],
        };
      }).toList();

      _filteredUsers = List.from(_users);
      _updateEstimatedCount();
    } catch (e) {
      print('Erreur chargement utilisateurs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des utilisateurs'),
          backgroundColor: africanRed,
        ),
      );
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  void _updateEstimatedCount() {
    setState(() {
      if (_targetType == 'all') {
        _estimatedCount = _users.length;
      } else {
        _estimatedCount = _selectedUsers.length;
      }
    });
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          final pseudo = user['pseudo'].toString().toLowerCase();
          final email = user['email'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return pseudo.contains(searchLower) || email.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _showUserSelectionDialog() async {
    // Réinitialiser la recherche
    _searchController.clear();
    _filteredUsers = List.from(_users);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: africanBlack.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [africanBlack, africanRed],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, color: africanGold, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sélectionner les destinataires',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_selectedUsers.length} sélectionné(s)',
                                  style: TextStyle(
                                    color: africanGold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context, _selectedUsers),
                          ),
                        ],
                      ),
                    ),

                    // Search bar
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (query) {
                          setStateDialog(() {
                            if (query.isEmpty) {
                              _filteredUsers = List.from(_users);
                            } else {
                              _filteredUsers = _users.where((user) {
                                final pseudo = user['pseudo'].toString().toLowerCase();
                                final email = user['email'].toString().toLowerCase();
                                final searchLower = query.toLowerCase();
                                return pseudo.contains(searchLower) || email.contains(searchLower);
                              }).toList();
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Rechercher un utilisateur...',
                          prefixIcon: Icon(Icons.search, color: africanGold),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: africanGold, width: 2),
                          ),
                        ),
                      ),
                    ),

                    // User list
                    Expanded(
                      child: _isLoadingUsers
                          ? Center(child: CircularProgressIndicator(color: africanGold))
                          : _filteredUsers.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 50, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Aucun utilisateur trouvé'),
                          ],
                        ),
                      )
                          : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final isSelected = _selectedUsers.contains(user['id']);

                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isSelected
                                  ? BorderSide(color: africanGold, width: 2)
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              onTap: () {
                                setStateDialog(() {
                                  if (isSelected) {
                                    _selectedUsers.remove(user['id']);
                                  } else {
                                    _selectedUsers.add(user['id']);
                                  }
                                });
                              },
                              leading: CircleAvatar(
                                backgroundImage: user['imageUrl'] != null
                                    ? NetworkImage(user['imageUrl'])
                                    : null,
                                backgroundColor: africanGold.withOpacity(0.2),
                                child: user['imageUrl'] == null
                                    ? Icon(Icons.person, color: africanGold)
                                    : null,
                              ),
                              title: Text(
                                user['pseudo'],
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? africanRed : africanBlack,
                                ),
                              ),
                              subtitle: Text(user['email']),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle, color: africanGold)
                                  : Icon(Icons.radio_button_unchecked, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),

                    // Footer buttons
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _searchController.clear();
                                setStateDialog(() {
                                  _filteredUsers = List.from(_users);
                                  _selectedUsers.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: africanRed),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                'Tout désélectionner',
                                style: TextStyle(color: africanRed),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, _selectedUsers),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: africanGold,
                                foregroundColor: africanBlack,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                'Confirmer (${_selectedUsers.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedUsers = result;
        _updateEstimatedCount();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Communication Afrolook',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: africanBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [africanBlack, africanRed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: africanGold,
              child: Icon(Icons.email, color: africanBlack, size: 20),
            ),
          ),
        ],
      ),
      body: _isSending
          ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [africanBlack.withOpacity(0.9), africanRed.withOpacity(0.9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: africanGold.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(africanGold),
                    strokeWidth: 4,
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  'Envoi des emails en cours...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Veuillez patienter',
                  style: TextStyle(
                    color: africanGold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Destinataires
                  _buildSectionCard(
                    icon: Icons.people,
                    title: 'Destinataires',
                    child: Column(
                      children: [
                        _buildRadioTile(
                          value: 'all',
                          title: 'Tous les utilisateurs',
                          subtitle: 'Envoyer à tous les utilisateurs ayant un email',
                          icon: Icons.public,
                        ),
                        Divider(),
                        _buildRadioTile(
                          value: 'specific',
                          title: 'Utilisateurs spécifiques',
                          subtitle: 'Choisir manuellement les destinataires',
                          icon: Icons.person_search,
                        ),
                        if (_selectedUsers.isNotEmpty) ...[
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: africanGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: africanGold.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: africanGold, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_selectedUsers.length} utilisateur(s) sélectionné(s)',
                                    style: TextStyle(
                                      color: africanBlack,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showUserSelectionDialog,
                                  child: Text(
                                    'Modifier',
                                    style: TextStyle(color: africanRed),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Section Sujet
                  _buildSectionCard(
                    icon: Icons.subject,
                    title: 'Sujet de l\'email',
                    child: TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Nouvelle fonctionnalité sur Afrolook',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: africanGold, width: 2),
                        ),
                        prefixIcon: Icon(Icons.email, color: africanGold),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un sujet';
                        }
                        return null;
                      },
                    ),
                  ),

                  SizedBox(height: 20),

                  // Section Message
                  _buildSectionCard(
                    icon: Icons.message,
                    title: 'Message',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _messageController,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: 'Rédigez votre message...\n\nUtilisez {{pseudo}} pour personnaliser',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: africanGold, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un message';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: africanGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '{{pseudo}} sera remplacé par le nom de l\'utilisateur',
                              style: TextStyle(
                                color: africanBlack,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Section Image
                  _buildSectionCard(
                    icon: Icons.image,
                    title: 'Image (optionnel)',
                    child: TextFormField(
                      controller: _imageUrlController,
                      decoration: InputDecoration(
                        hintText: 'https://exemple.com/image.jpg',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: africanGold, width: 2),
                        ),
                        prefixIcon: Icon(Icons.image_search, color: africanGold),
                        suffixIcon: _imageUrlController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _imageUrlController.clear();
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Aperçu
                  _buildPreviewCard(),

                  SizedBox(height: 24),

                  // Stats et estimation
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [africanBlack, africanRed],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: africanRed.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: africanGold,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.people_alt, color: africanBlack, size: 24),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nombre de destinataires',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$_estimatedCount utilisateur(s)',
                                style: TextStyle(
                                  color: africanGold,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // Bouton d'envoi
                  Container(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _sendEmails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: africanGold,
                        foregroundColor: africanBlack,
                        elevation: 5,
                        shadowColor: africanGold.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'ENVOYER LES EMAILS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Note d'information
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: africanGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: africanGold.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: africanGold, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'L\'envoi peut prendre quelques minutes selon le nombre de destinataires. '
                                'Les utilisateurs peuvent se désabonner à tout moment.',
                            style: TextStyle(
                              fontSize: 12,
                              color: africanBlack,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 3,
      shadowColor: africanBlack.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: africanGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: africanRed, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: africanBlack,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _targetType = value;
          if (value == 'specific') {
            _showUserSelectionDialog();
          } else {
            _selectedUsers.clear();
            _updateEstimatedCount();
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _targetType == value ? africanGold : Colors.grey,
                  width: 2,
                ),
              ),
              child: _targetType == value
                  ? Container(
                margin: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: africanGold,
                ),
              )
                  : null,
            ),
            SizedBox(width: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _targetType == value ? africanGold.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _targetType == value ? africanRed : Colors.grey, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: _targetType == value ? FontWeight.bold : FontWeight.normal,
                      color: _targetType == value ? africanRed : africanBlack,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      shadowColor: africanGold.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: africanGold.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: africanBlack,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility, color: africanGold, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Aperçu de l\'email',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: africanGold.withOpacity(0.2),
                              child: Icon(Icons.email, color: africanRed, size: 20),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'De: Afrolook Media',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    'À: utilisateur@email.com',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        Text(
                          _subjectController.text.isEmpty
                              ? 'Sujet de l\'email'
                              : _subjectController.text,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: africanRed,
                          ),
                        ),
                        SizedBox(height: 16),
                        if (_imageUrlController.text.isNotEmpty) ...[
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(_imageUrlController.text),
                                fit: BoxFit.cover,
                                onError: (exception, stackTrace) {
                                  // Gérer l'erreur de chargement d'image
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _messageController.text.isEmpty
                                ? 'Votre message apparaîtra ici...'
                                : _messageController.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: africanBlack,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendEmails() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: africanGold),
            SizedBox(width: 10),
            Text('Confirmation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vous allez envoyer cet email à :'),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: africanGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, color: africanRed),
                  SizedBox(width: 8),
                  Text(
                    '$_estimatedCount destinataire(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text('Sujet: ${_subjectController.text}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: africanGold,
              foregroundColor: africanBlack,
            ),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);

    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions
          .httpsCallable('sendBulkEmail')
          .call({
        'subject': _subjectController.text,
        'message': _messageController.text,
        'imageUrl': _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
        'targetType': _targetType,
        'specificUserIds': _selectedUsers,
        'senderId': FirebaseAuth.instance.currentUser!.uid,
        'priority': 'normal',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result.data['message']}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: africanRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}