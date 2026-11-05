import 'package:afrotok/services/read_meter.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import '../../../services/api/api_gateway.dart';
import '../../../services/api/wallet_api.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:intl/intl.dart';
import '../../../l10n/tr.dart';

class PendingTransactionsScreen extends StatefulWidget {
  const PendingTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<PendingTransactionsScreen> createState() => _PendingTransactionsScreenState();
}

class _PendingTransactionsScreenState extends State<PendingTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _getCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _getCurrentUser() {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  void _showVerificationDialog(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _VerificationDialog(
        transaction: transaction,
        onComplete: () {
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Transactions en attente')),
          backgroundColor: Color(0xFFD8A868),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(context.tr('Veuillez vous connecter'), style: TextStyle(fontSize: 18)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFD8A868)),
                child: Text(context.tr('Retour'), style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Transactions en attente - Afrolook')),
        backgroundColor: Color(0xFFD8A868),
        foregroundColor: Colors.white,
      ),
      body: _buildPendingDepositsList(),
    );
  }

  Widget _buildPendingDepositsList() {
    // Liste des dépôts en cours de la personne : GET /payments/deposits?status=open (ajouté à l'API le 05/11) ; en cas d'erreur, « Réessayer ».
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(_reload),
      future: ApiGateway.instance.client.get('/payments/deposits', query: {'status': 'open'}).then(WalletApi.list),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(snapshot.error is ApiException ? WalletApi.message(snapshot.error!) : context.tr('Erreur: {a}', {'a': snapshot.error})),
              TextButton(onPressed: () => setState(() => _reload++), child: Text(context.tr('Réessayer'))),
            ]),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFFD8A868)));
        }

        final transactions = snapshot.data ?? <Map<String, dynamic>>[];

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(context.tr('Aucune transaction en attente'), style: TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final data = Map<String, dynamic>.from(transactions[index]);
            final createdAt = DateTime.tryParse('${data['created_at']}')?.toLocal();
            final amount = ((data['amount_xof'] ?? 0) as num).toDouble();
            final reference = '${data['id'] ?? context.tr('En attente...')}';
            final amountWithoutFees = ((data['credited_xof'] ?? 0) as num).toDouble();
            final status = '${data['status'] ?? 'pending'}';
            final depositNumber = '${data['deposit_number'] ?? ''}';
            data['reference'] = reference;

            return _buildTransactionCard(
              depositNumber: depositNumber,
              amount: amount,
              amountWithoutFees: amountWithoutFees,
              reference: reference,
              createdAt: createdAt,
              status: status,
              data: data,
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionCard({
    required String depositNumber,
    required double amount,
    required double amountWithoutFees,
    required String reference,
    required DateTime? createdAt,
    required String status,
    required Map<String, dynamic> data,
  }) {
    final bool isPending = status == 'pending' || status == 'processing';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = context.tr('Terminé');
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = context.tr('Échoué');
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.orange;
        statusText = context.tr('En attente');
        statusIcon = Icons.pending;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isPending
            ? () => _showVerificationDialog({
          'id': reference,
          'reference': reference,
          'amount': amount,
          'amountWithoutFees': amountWithoutFees,
          'createdAt': createdAt,
          'type': 'afrolook_deposit',
          'data': data,
          'depositNumber': depositNumber,
        })
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, size: 18, color: Color(0xFFD8A868)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('Dépôt Afrolook'),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        SizedBox(width: 4),
                        Text(statusText, style: TextStyle(color: statusColor, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('Montant:'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('${amount.toStringAsFixed(0)} FCFA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              if (depositNumber.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('N° dépôt:'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(depositNumber, style: TextStyle(fontSize: 11)),
                  ],
                ),
              SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (createdAt != null)
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  if (isPending)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Color(0xFFD8A868).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 12, color: Color(0xFFD8A868)),
                          SizedBox(width: 4),
                          Text(context.tr('Vérifier'), style: TextStyle(color: Color(0xFFD8A868), fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DIALOG DE VÉRIFICATION
// ============================================================

class _VerificationDialog extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onComplete;

  const _VerificationDialog({
    required this.transaction,
    required this.onComplete,
  });

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  bool _isChecking = true;
  String _message = tr('Vérification du paiement en cours...');
  bool _isSuccess = false;
  String? _errorDetails;
  int _checkCount = 0;
  final int _maxChecks = 5;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final reference = widget.transaction['reference'];

    if (reference == null || reference == 'En attente...') {
      setState(() {
        _isChecking = false;
        _isSuccess = false;
        _message = context.tr('❌ Aucune référence trouvée.');
      });
      return;
    }

    _checkCount++;

    try {
      final d = await WalletApi.instance.depositStatus('$reference');
      final status = d['status'];
      final success = status == 'completed';
      final pending = status == 'processing' || status == 'created';
      final result = (data: {'message': d['failure_reason'], 'reason': d['failure_reason']});

      if (status == 'completed' || success == true) {
        setState(() {
          _isChecking = false;
          _isSuccess = true;
          _message = context.tr('✅ Paiement confirmé avec succès !');
        });

        widget.onComplete();

        Future.delayed(Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (status == 'failed') {
        setState(() {
          _isChecking = false;
          _isSuccess = false;
          _message = '❌ ${result.data['message'] ?? 'Le paiement a échoué'}';
          _errorDetails = result.data['reason'];
        });
      } else if (pending == true) {
        if (_checkCount < _maxChecks) {
          setState(() {
            _message = context.tr('⏳ Paiement en attente... ({a}/{b})', {'a': _checkCount, 'b': _maxChecks});
          });
          Future.delayed(Duration(seconds: 3), _checkStatus);
        } else {
          setState(() {
            _isChecking = false;
            _isSuccess = false;
            _message = context.tr('⏳ Délai dépassé. Veuillez réessayer plus tard.');
          });
        }
      } else {
        setState(() {
          _isChecking = false;
          _isSuccess = false;
          _message = '❌ ${result.data['message'] ?? 'Statut inconnu'}';
        });
      }
    } catch (e) {
      printVm('Erreur: $e');
      if (_checkCount < _maxChecks) {
        setState(() {
          _message = context.tr('⚠️ Erreur technique, nouvelle tentative... ({a}/{b})', {'a': _checkCount, 'b': _maxChecks});
        });
        Future.delayed(Duration(seconds: 3), _checkStatus);
      } else {
        setState(() {
          _isChecking = false;
          _isSuccess = false;
          _message = context.tr('❌ Erreur technique. Veuillez réessayer.');
          _errorDetails = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Vérification du paiement')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isChecking)
            CircularProgressIndicator(color: Color(0xFFD8A868))
          else if (_isSuccess)
            Icon(Icons.check_circle, size: 50, color: Colors.green)
          else
            Icon(Icons.error, size: 50, color: Colors.red),
          SizedBox(height: 20),
          Text(_message, textAlign: TextAlign.center),
          if (_errorDetails != null && !_isSuccess) ...[
            SizedBox(height: 12),
            Text(_errorDetails!, style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
          SizedBox(height: 16),
          Text(context.tr('Réf: {a}', {'a': widget.transaction['reference'] ?? 'N/A'}), style: TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Fermer'))),
      ],
    );
  }
}