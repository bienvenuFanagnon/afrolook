//CoinTransactionsPage - Historique des transactions
// lib/pages/coins/coin_transactions_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../providers/dating/coin_provider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class CoinTransactionsPage extends StatefulWidget {
  const CoinTransactionsPage({Key? key}) : super(key: key);

  @override
  State<CoinTransactionsPage> createState() => _CoinTransactionsPageState();
}

class _CoinTransactionsPageState extends State<CoinTransactionsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CoinProvider>(context, listen: false).loadUserTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        title: Text(
          t.datingTransactionHistoryTitle,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
      ),
      body: Consumer<CoinProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.transactions.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }

          if (provider.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    t.datingNoTransactions,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    t.datingTransactionsAppearHere,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: provider.transactions.length,
            itemBuilder: (context, index) {
              final transaction = provider.transactions[index];
              return _buildTransactionCard(context, transaction);
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, UserCoinTransaction transaction) {
    final t = AppLocalizations.of(context);
    final isGain = transaction.coinsAmount > 0;
    final icon = isGain ? Icons.trending_up : Icons.trending_down;
    final iconColor = isGain ? Colors.green : Colors.red;
    final amountText = t.datingCoinsCount.replaceAll(
        '{count}', isGain ? '+${transaction.coinsAmount}' : '${transaction.coinsAmount}');

    String typeLabel = '';
    switch (transaction.type) {
      case CoinTransactionType.buy_coins:
        typeLabel = t.datingTxTypeBuyCoins;
        break;
      case CoinTransactionType.spend_subscription:
        typeLabel = t.datingTxTypeSubscriptionDating;
        break;
      case CoinTransactionType.spend_creator_subscription:
        typeLabel = t.datingTxTypeSubscriptionCreator;
        break;
      case CoinTransactionType.spend_paid_content:
        typeLabel = t.datingTxTypeContentPurchase;
        break;
      case CoinTransactionType.earn_creator_subscription:
        typeLabel = t.datingTxTypeCreatorSubscriptionEarning;
        break;
      case CoinTransactionType.earn_paid_content:
        typeLabel = t.datingTxTypeContentSaleEarning;
        break;
      case CoinTransactionType.convert_to_xof:
        typeLabel = t.datingTxTypeConvertToXof;
        break;
      default:
        typeLabel = transaction.type.value;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: AppColors.of(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    transaction.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                SizedBox(height: 4),
                if (transaction.xofAmount > 0)
                  Text(
                    '${transaction.xofAmount.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(transaction.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(t, transaction.status),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getStatusColor(transaction.status),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
      case TransactionStatus.approved:
      case TransactionStatus.paid:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
      case TransactionStatus.canceled:
      case TransactionStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(AppLocalizations t, TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return t.datingTxStatusSuccess;
      case TransactionStatus.pending:
        return t.datingTxStatusPending;
      case TransactionStatus.failed:
        return t.datingTxStatusFailed;
      case TransactionStatus.canceled:
        return t.datingTxStatusCanceled;
      case TransactionStatus.approved:
        return t.datingTxStatusApproved;
      case TransactionStatus.rejected:
        return t.datingTxStatusRejected;
      case TransactionStatus.paid:
        return t.datingTxStatusPaid;
      default:
        return status.value;
    }
  }
}