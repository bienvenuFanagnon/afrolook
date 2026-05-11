import 'package:afrotok/pages/user/UserRetrait/userRetraitForm.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/coin_gift_provider.dart';
import '../../models/model_data.dart';
import '../../services/coin_gift_service.dart';
import '../paiement/depotPageTranaction.dart';
import '../paiement/newDepot.dart';
import 'UserRetrait/userRetraitListe.dart';
import 'coin_conversion_page.dart';

class MonetisationPage extends StatefulWidget {
  @override
  _MonetisationPageState createState() => _MonetisationPageState();
}

class _MonetisationPageState extends State<MonetisationPage> {
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  late CoinGiftUserProvider coinProvider;
  Stream<UserData>? userStream;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    userStream = authProvider.getUserStream();
  }

  void refreshUser() {
    setState(() {
      userStream = authProvider.getUserStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Monétisation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: refreshUser,
            tooltip: "Rafraîchir",
          ),
        ],
      ),
      body: StreamBuilder<UserData>(
        stream: userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00CC66))));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
                child: Text("Erreur de chargement",
                    style: TextStyle(color: Colors.red)));
          }

          final user = snapshot.data!;
          double soldePrincipal = user.votre_solde_principal ?? 0;
          int giftCoinsBalance = user.giftCoinsBalance ?? 0;
          int totalCoinsEarnedFromAdSupport = user.totalCoinsEarnedFromAdSupport ?? 0;
          int totalCoinsFromPub = totalCoinsEarnedFromAdSupport;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carte du solde principal FCFA
                _buildSoldePrincipalCard(soldePrincipal),
                const SizedBox(height: 16),

                // Carte des pièces
                _buildCoinsCard(giftCoinsBalance, totalCoinsFromPub),
                const SizedBox(height: 16),

                // Section conversion pièces → FCFA
                _buildConversionSection(user, giftCoinsBalance),
                const SizedBox(height: 24),

                // En-tête historique des transactions
                _buildTransactionHeader(),
                const SizedBox(height: 16),

                // Liste des transactions
                _buildTransactionList(user.id!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSoldePrincipalCard(double soldePrincipal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF121212), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00CC66).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00CC66).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Color(0xFF00CC66), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "SOLDE PRINCIPAL",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "${soldePrincipal.toStringAsFixed(2)} FCFA",
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00CC66),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DepositScreen()));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.arrow_downward, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text("Dépôt", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00CC66),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(left: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) =>  UserRetraitListPage()),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.arrow_upward, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text("Retrait", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinsCard(int giftCoinsBalance, int totalCoinsFromPub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🪙', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              const Text(
                "SOLDE PIÈCES",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatNumber(giftCoinsBalance),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "pièces",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildConversionSection(UserData user, int giftCoinsBalance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz, color: Color(0xFFFFD700), size: 20),
              SizedBox(width: 8),
              Text(
                "Convertir pièces en FCFA",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "1 pièce = 0.4 FCFA (10 FCFA = 25 pièces)",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Affichage du solde
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Solde disponible',
                  style: TextStyle(color: Colors.white70),
                ),
                Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      _formatNumber(giftCoinsBalance),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bouton Convertir qui ouvre la nouvelle page
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CoinConversionPage()),
                );
                if (result == true) {
                  refreshUser();
                }
              },
              icon: const Icon(Icons.swap_horiz, color: Colors.black),
              label: const Text(
                "Convertir mes pièces",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            "⚠️ Minimum 100 pièces pour la conversion",
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
  void _showConversionDialog(UserData user, int coinsBalance) {
    final TextEditingController coinsController = TextEditingController();
    final double fcfaRate = 0.4; // 1 pièce = 0.4 FCFA

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Variables d'état
          int coinsToConvert = 0;
          double fcfaToGet = 0;
          String errorMessage = '';
          bool isValid = false;

          void updateConversion(String value) {
            print("Valeur saisie: $value"); // Debug

            // Réinitialiser
            errorMessage = '';
            isValid = false;

            if (value.isEmpty) {
              coinsToConvert = 0;
              fcfaToGet = 0;
              setStateDialog(() {});
              return;
            }

            final parsed = int.tryParse(value);

            if (parsed == null) {
              errorMessage = 'Veuillez entrer un nombre valide';
              coinsToConvert = 0;
              fcfaToGet = 0;
              setStateDialog(() {});
              return;
            }

            // Appliquer les limites
            if (parsed > coinsBalance) {
              errorMessage = 'Solde insuffisant. Maximum : ${_formatNumber(coinsBalance)} pièces';
              coinsToConvert = 0;
              fcfaToGet = 0;
            } else if (parsed < 100) {
              errorMessage = 'Minimum 100 pièces pour la conversion';
              coinsToConvert = 0;
              fcfaToGet = 0;
            } else {
              coinsToConvert = parsed;
              fcfaToGet = parsed * fcfaRate;
              isValid = true;
              errorMessage = '';
            }

            print("coinsToConvert: $coinsToConvert, fcfaToGet: $fcfaToGet, isValid: $isValid"); // Debug
            setStateDialog(() {});
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Convertir pièces en FCFA',
              style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Entrez le nombre de pièces à convertir',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),

                // Affichage du solde disponible
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Solde disponible :',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Row(
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            _formatNumber(coinsBalance),
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Champ de saisie
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: errorMessage.isNotEmpty
                          ? Colors.red.withOpacity(0.5)
                          : const Color(0xFFFFD700).withOpacity(0.3),
                    ),
                  ),
                  child: TextField(
                    controller: coinsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixIcon: const Text('🪙', style: TextStyle(fontSize: 20)),
                      hintText: 'Ex: 100, 500, 1000...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: updateConversion,
                  ),
                ),

                // Message d'erreur
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 16),

                // Affichage du montant à recevoir (toujours visible si valide)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isValid
                        ? const LinearGradient(
                      colors: [Color(0xFF00CC66), Color(0xFF00994D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : const LinearGradient(
                      colors: [Color(0xFF333333), Color(0xFF222222)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Vous recevrez :',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isValid ? '${fcfaToGet.toStringAsFixed(0)} FCFA' : '0 FCFA',
                        style: TextStyle(
                          color: isValid ? Colors.white : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: isValid
                    ? () async {
                  Navigator.pop(ctx);
                  await _convertCoins(user.id!, coinsToConvert);
                  coinsController.clear();
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? const Color(0xFFFFD700) : Colors.grey,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Convertir',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _convertCoins(String userId, int coinsAmount) async {
    setState(() => _isConverting = true);

    try {
      await CoinGiftService.convertCoinsToFcfa(
        userId: userId,
        coinsAmount: coinsAmount,
        firestore: FirebaseFirestore.instance,
      );

      // Rafraîchir les données
      await authProvider.refreshUserData();
      await coinProvider.refreshBalance(userId);
      refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Conversion réussie ! Les FCFA ont été ajoutés à votre solde principal.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isConverting = false);
    }
  }

  Widget _buildTransactionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF00CC66).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history, color: Color(0xFF00CC66), size: 16),
          ),
          const SizedBox(width: 8),
          const Text(
            "HISTORIQUE DES TRANSACTIONS",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(String userId) {
    return StreamBuilder<List<TransactionSolde>>(
      stream: postProvider.getTransactionsSoldes(userId),
      builder: (context, snapshotTx) {
        if (snapshotTx.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00CC66))));
        }
        if (snapshotTx.hasError) {
          return Center(
              child: Text("Erreur de chargement",
                  style: TextStyle(color: Colors.red)));
        }

        final transactions = snapshotTx.data ?? [];
        if (transactions.isEmpty) {
          return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt, size: 48, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text("Aucune transaction",
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return TransactionWidget(transaction: tx);
          },
        );
      },
    );
  }

  String _formatNumber(int num) {
    // if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    // if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }
}

// Widget pour afficher chaque transaction avec tous les types
class TransactionWidget extends StatelessWidget {
  final TransactionSolde transaction;
  const TransactionWidget({required this.transaction});

  String formatDate(DateTime date) {
    final formatter = DateFormat('dd MMM yyyy, HH:mm');
    return formatter.format(date);
  }

  String getTransactionLabel(String type) {
    switch (type) {
      case "DEPOT":
        return "Dépôt";
      case "DEPOTADMIN":
        return "Dépôt Admin";
      case "RETRAIT":
        return "Retrait";
      case "RETRAITADMIN":
        return "Retrait Admin";
      case "GAIN":
        return "Gain";
      case "GAIN_PIECES":
        return "Gain en pièces";
      case "DEPENSE":
        return "Dépense";
      case "ACHAT_PIECES":
        return "Achat de pièces";
      case "CONVERSION_PIECES":
        return "Conversion pièces → FCFA";
      case "CADEAU_PIECES":
        return "Cadeau envoyé";
      case "CADEAU_PIECES_RECU":
        return "Cadeau reçu";
      case "LIKE_PIECES":
        return "Like envoyé";
      default:
        return type;
    }
  }

  IconData getIcon(String type) {
    switch (type) {
      case "DEPOT":
      case "DEPOTADMIN":
        return Icons.account_balance_wallet;
      case "RETRAIT":
      case "RETRAITADMIN":
        return Icons.arrow_upward;
      case "GAIN":
      case "GAIN_PIECES":
        return Icons.trending_up;
      case "DEPENSE":
        return Icons.shopping_cart;
      case "ACHAT_PIECES":
        return Icons.shopping_bag;
      case "CONVERSION_PIECES":
        return Icons.swap_horiz;
      case "CADEAU_PIECES":
        return Icons.card_giftcard;
      case "CADEAU_PIECES_RECU":
        return Icons.card_giftcard;
      case "LIKE_PIECES":
        return Icons.favorite;  // 🔥 Icône cœur pour les likes
      default:
        return Icons.help_outline;
    }
  }

  Color getColor(String type) {
    switch (type) {
      case "DEPOT":
      case "DEPOTADMIN":
      case "GAIN":
      case "GAIN_PIECES":
      case "CADEAU_PIECES_RECU":
        return const Color(0xFF00CC66);
      case "RETRAIT":
      case "RETRAITADMIN":
      case "DEPENSE":
      case "ACHAT_PIECES":
      case "CADEAU_PIECES":
      case "LIKE_PIECES":  // 🔥 Like = rouge (dépense)
        return const Color(0xFFFF3B30);
      case "CONVERSION_PIECES":
        return const Color(0xFFFFD700);
      default:
        return Colors.grey;
    }
  }

  String getPrefix(String type) {
    switch (type) {
      case "DEPOT":
      case "DEPOTADMIN":
      case "GAIN":
      case "GAIN_PIECES":
      case "CADEAU_PIECES_RECU":
        return "+ ";
      case "RETRAIT":
      case "RETRAITADMIN":
      case "DEPENSE":
      case "ACHAT_PIECES":
      case "CADEAU_PIECES":
      case "LIKE_PIECES":  // 🔥 Like = dépense, donc préfixe "-"
        return "- ";
      case "CONVERSION_PIECES":
        return "→ ";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == TypeTransaction.DEPOT.name ||
        transaction.type == TypeTransaction.DEPOTADMIN.name ||
        transaction.type == TypeTransaction.GAIN.name ||
        transaction.type == TypeTransaction.GAIN_PIECES.name ||
        transaction.type == TypeTransaction.CADEAU_PIECES_RECU.name;

    final isValide = transaction.statut == StatutTransaction.VALIDER.name;
    final color = getColor(transaction.type!);
    final icon = getIcon(transaction.type!);
    final prefix = getPrefix(transaction.type!);
    final label = getTransactionLabel(transaction.type!);

    // Pour les transactions en pièces, on formate l'affichage
    bool isCoinAchatTransaction = transaction.type == TypeTransaction.ACHAT_PIECES.name||
        transaction.type == TypeTransaction.CONVERSION_PIECES.name ;

    bool isCoinTransaction = transaction.type == TypeTransaction.ACHAT_PIECES.name ||
        transaction.type == TypeTransaction.CADEAU_PIECES.name ||
        transaction.type == TypeTransaction.CADEAU_PIECES_RECU.name ||
        transaction.type == TypeTransaction.LIKE_PIECES.name ||
        transaction.type == TypeTransaction.GAIN_PIECES.name;

    String amountDisplay;
    if (isCoinAchatTransaction) {
      amountDisplay = "${prefix}${transaction.montant!.toStringAsFixed(2)} FCFA";
    } else if (isCoinTransaction) {
      amountDisplay = "${prefix}${transaction.montant!.toStringAsFixed(2)} 🪙";
    } else {
      amountDisplay = "${prefix}${transaction.montant!.toStringAsFixed(2)} FCFA";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),

          // Infos principales
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amountDisplay,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (transaction.description != null && transaction.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      transaction.description!,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Statut + Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDate(DateTime.fromMillisecondsSinceEpoch(transaction.createdAt!)),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isValide
                      ? const Color(0xFF00CC66).withOpacity(0.15)
                      : const Color(0xFFFF9500).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction.statut!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isValide ? const Color(0xFF00CC66) : const Color(0xFFFF9500),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// import 'package:afrotok/pages/user/UserRetrait/userRetraitForm.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../../providers/authProvider.dart';
// import '../../../providers/postProvider.dart';
// import '../../models/model_data.dart';
// import '../paiement/depotPageTranaction.dart';
// import '../paiement/newDepot.dart';
// import 'UserRetrait/userRetraitListe.dart';
//
// class MonetisationPage extends StatefulWidget {
//   @override
//   _MonetisationPageState createState() => _MonetisationPageState();
// }
//
// class _MonetisationPageState extends State<MonetisationPage> {
//   late UserAuthProvider authProvider;
//   late PostProvider postProvider;
//   Stream<UserData>? userStream;
//
//   @override
//   void initState() {
//     super.initState();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     postProvider = Provider.of<PostProvider>(context, listen: false);
//     userStream = authProvider.getUserStream();
//   }
//
//   void refreshUser() {
//     setState(() {
//       userStream = authProvider.getUserStream();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFF0A0A0A),
//       appBar: AppBar(
//         title: Text('Monétisation',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         centerTitle: true,
//         backgroundColor: Colors.black,
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh, color: Colors.white),
//             onPressed: refreshUser,
//             tooltip: "Rafraîchir",
//           ),
//         ],
//       ),
//       body: StreamBuilder<UserData>(
//         stream: userStream,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00CC66))));
//           }
//           if (snapshot.hasError || !snapshot.hasData) {
//             return Center(
//                 child: Text("Erreur de chargement",
//                     style: TextStyle(color: Colors.red)));
//           }
//
//           final user = snapshot.data!;
//           double soldePrincipal = user.votre_solde_principal ?? 0;
//
//           return Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Carte du solde principal
//                 Container(
//                   width: double.infinity,
//                   padding: EdgeInsets.all(24),
//                   decoration: BoxDecoration(
//                     color: Color(0xFF121212),
//                     borderRadius: BorderRadius.circular(16),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.4),
//                         blurRadius: 10,
//                         offset: Offset(0, 4),
//                       )
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "SOLDE PRINCIPAL",
//                         style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey[500],
//                             fontWeight: FontWeight.w600,
//                             letterSpacing: 1.2
//                         ),
//                       ),
//                       SizedBox(height: 10),
//                       Text(
//                         "${soldePrincipal.toStringAsFixed(2)} FCFA",
//                         style: TextStyle(
//                           fontSize: 28,
//                           fontWeight: FontWeight.bold,
//                           color: Color(0xFF00CC66),
//                         ),
//                       ),
//                       SizedBox(height: 16),
//                       Divider(color: Colors.grey[800], height: 1),
//                       SizedBox(height: 16),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           // Bouton Dépôt
//                           Expanded(
//                             child: Container(
//                               height: 50,
//                               margin: EdgeInsets.only(right: 8),
//                               child: ElevatedButton(
//                                 onPressed: () {
//                                   Navigator.push(context,
//                                       MaterialPageRoute(builder: (_) => DepositScreen()));
//                                 },
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Icon(Icons.arrow_downward, size: 18, color: Colors.white),
//                                     SizedBox(width: 6),
//                                     Text("Dépôt", style: TextStyle(fontWeight: FontWeight.bold)),
//                                   ],
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Color(0xFF00CC66),
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(12)),
//                                   elevation: 0,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           // Bouton Retrait
//                           Expanded(
//                             child: Container(
//                               height: 50,
//                               margin: EdgeInsets.only(left: 8),
//                               child: ElevatedButton(
//                                 onPressed: () {
//                                   // Dialogue retrait
//
//                                   Navigator.push(
//                                     context,
//                                     MaterialPageRoute(builder: (context) => UserRetraitListPage()),
//                                   );
//                                 },
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Icon(Icons.arrow_upward, size: 18, color: Colors.white),
//                                     SizedBox(width: 6),
//                                     Text("Retrait", style: TextStyle(fontWeight: FontWeight.bold)),
//                                   ],
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Color(0xFFFF3B30),
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(12)),
//                                   elevation: 0,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 24),
//
//                 // En-tête historique des transactions
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "HISTORIQUE DES TRANSACTIONS",
//                         style: TextStyle(
//                             color: Colors.grey[500],
//                             fontSize: 12,
//                             fontWeight: FontWeight.w600,
//                             letterSpacing: 1.1
//                         ),
//                       ),
//                       // if (snapshot.hasData)
//                       //   Text(
//                       //     "Total: ${transactions.length}",
//                       //     style: TextStyle(
//                       //       color: Colors.grey[500],
//                       //       fontSize: 12,
//                       //     ),
//                       //   ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 16),
//
//                 // Liste des transactions
//                 Expanded(
//                   child: StreamBuilder<List<TransactionSolde>>(
//                     stream: postProvider.getTransactionsSoldes(user.id!),
//                     builder: (context, snapshotTx) {
//                       if (snapshotTx.connectionState == ConnectionState.waiting) {
//                         return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00CC66))));
//                       }
//                       if (snapshotTx.hasError) {
//                         return Center(
//                             child: Text("Erreur de chargement",
//                                 style: TextStyle(color: Colors.red)));
//                       }
//
//                       final transactions = snapshotTx.data ?? [];
//                       if (transactions.isEmpty) {
//                         return Center(
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(Icons.receipt, size: 48, color: Colors.grey[700]),
//                                 SizedBox(height: 16),
//                                 Text("Aucune transaction",
//                                     style: TextStyle(color: Colors.grey[600])),
//                               ],
//                             ));
//                       }
//
//                       return ListView.builder(
//                         physics: BouncingScrollPhysics(),
//                         itemCount: transactions.length,
//                         itemBuilder: (context, index) {
//                           final tx = transactions[index];
//                           return TransactionWidget(transaction: tx);
//                         },
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
// // Widget pour afficher chaque transaction
//
//
// class TransactionWidget extends StatelessWidget {
//   final TransactionSolde transaction;
//   const TransactionWidget({required this.transaction});
//
//   String formatDate(DateTime date) {
//     final formatter = DateFormat('dd MMM yyyy, HH:mm');
//     return formatter.format(date);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isCredit = transaction.type == TypeTransaction.DEPOT.name || transaction.type == TypeTransaction.GAIN.name;
//     final isValide = transaction.statut == StatutTransaction.VALIDER.name;
//
//     // Définir les styles selon le type
//     IconData icon;
//     Color color;
//     String prefix;
//
//     switch (transaction.type) {
//       case "DEPOT":
//         icon = Icons.account_balance_wallet;
//         color = const Color(0xFF007AFF);
//         prefix = "+ ";
//         break;
//       case "GAIN":
//         icon = Icons.trending_up;
//         color = const Color(0xFF00CC66);
//         prefix = "+ ";
//         break;
//       case "DEPENSE":
//         icon = Icons.shopping_cart;
//         color = const Color(0xFFFF3B30);
//         prefix = "- ";
//         break;
//       default:
//         icon = Icons.help_outline;
//         color = Colors.grey;
//         prefix = "";
//     }
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1E1E1E),
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 6,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Icône
//           Container(
//             width: 48,
//             height: 48,
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Icon(icon, color: color, size: 24),
//           ),
//           const SizedBox(width: 12),
//
//           // Infos principales
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "${prefix}${transaction.montant!.toStringAsFixed(2)} FCFA",
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   transaction.description ?? '',
//                   style: TextStyle(
//                     color: Colors.grey[400],
//                     fontSize: 13,
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//
//           // Statut + Date
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 formatDate(DateTime.fromMillisecondsSinceEpoch(transaction.createdAt!)),
//                 style: TextStyle(fontSize: 12, color: Colors.grey[500]),
//               ),
//               const SizedBox(height: 6),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: isValide
//                       ? const Color(0xFF00CC66).withOpacity(0.15)
//                       : const Color(0xFFFF9500).withOpacity(0.15),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   transaction.statut!.toUpperCase(),
//                   style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.bold,
//                     color: isValide ? const Color(0xFF00CC66) : const Color(0xFFFF9500),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
