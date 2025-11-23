import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';

import '../../providers/crypto_admin_provider.dart';

class CryptoFormPage extends StatefulWidget {
  final String? cryptoId;

  const CryptoFormPage({Key? key, this.cryptoId}) : super(key: key);

  @override
  State<CryptoFormPage> createState() => _CryptoFormPageState();
}

class _CryptoFormPageState extends State<CryptoFormPage> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Si un cryptoId est fourni, charger les données de la crypto
    if (widget.cryptoId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CryptoAdminProvider>().loadCryptoForEdit(widget.cryptoId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F111C),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header
                _buildHeader(),
                SizedBox(height: 20),

                // Formulaire
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Emoji/Symbole
                        _buildEmojiSection(),
                        SizedBox(height: 24),

                        // Symbol et Nom
                        _buildSymbolNameSection(),
                        SizedBox(height: 20),

                        // Prix
                        _buildPriceSection(),
                        SizedBox(height: 20),

                        // Supply
                        _buildSupplySection(),
                        SizedBox(height: 20),

                        // Catégorie et Rank
                        _buildCategoryRankSection(),
                        SizedBox(height: 20),

                        // Paramètres de trading
                        _buildTradingSettings(),
                        SizedBox(height: 30),

                        // Bouton d'enregistrement
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(0xFF00B894).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Iconsax.arrow_left_2, color: Color(0xFF00B894)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        SizedBox(width: 12),
        Text(
          widget.cryptoId != null ? 'Modifier la Crypto' : 'Nouvelle Crypto',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiSection() {
    return Consumer<CryptoAdminProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            GestureDetector(
              onTap: _showEmojiPicker,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(0xFF2A3649),
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A202C),
                      Color(0xFF131A26),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.emojiController.text.isNotEmpty
                          ? provider.emojiController.text
                          : '😊',
                      style: TextStyle(fontSize: 40),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Choisir emoji',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Color(0xFF1A202C),
              ),
              child: TextFormField(
                controller: provider.emojiController,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Ou saisir un emoji...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Emoji requis';
                  }
                  return null;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEmojiPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        title: Text(
          'Choisir un emoji',
          style: TextStyle(color: Colors.white),
        ),
        content: Consumer<CryptoAdminProvider>(
          builder: (context, provider, child) {
            return SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  '🪙', '⚡', '🏺', '🌍', '💎', '🚀', '🌟', '🔥',
                  '💧', '🌙', '☀️', '⭐', '🌈', '🎯', '💰', '💳',
                  '💸', '💵', '💴', '💶', '💷', '🪙', '💣', '🧨',
                  '✨', '🎉', '🎊', '🏆', '🥇', '🥈', '🥉', '🎖️',
                  '🏅', '👑', '💎', '🔮', '🎲', '♠️', '♥️', '♦️',
                  '♣️', '🃏', '🀄', '🎴', '👁️', '🗿', '🪬', '💊',
                  '💉', '🩸', '💣', '🧿', '🎭', '🪙', '⚱️', '🏺',
                  '📿', '💎', '🔱', '⚜️', '✅', '❌', '⚡', '🔰',
                ].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      provider.emojiController.text = emoji;
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Color(0xFF2A3649),
                      ),
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Color(0xFF00B894)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolNameSection() {
    return Consumer<CryptoAdminProvider>(
      builder: (context, provider, child) {
        return Row(
          children: [
            // Symbol
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYMBOLE',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Color(0xFF1A202C),
                    ),
                    child: TextFormField(
                      controller: provider.symbolController,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'BTC',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Symbole requis';
                        }
                        if (value.length > 10) {
                          return 'Symbole trop long';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            // Nom
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOM COMPLET',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Color(0xFF1A202C),
                    ),
                    child: TextFormField(
                      controller: provider.nameController,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Bitcoin',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nom requis';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriceSection() {
    return Consumer<CryptoAdminProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRIX',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPriceField(
                    'Prix Actuel (\$)',
                    provider.currentPrice,
                        (value) => provider.currentPrice = value,
                    '50000.00',
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildPriceField(
                    'Prix Initial (\$)',
                    provider.initialPrice,
                        (value) => provider.initialPrice = value,
                    '50000.00',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriceField(String label, double value, Function(double) onChanged, String hint) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color(0xFF1A202C),
      ),
      child: TextFormField(
        initialValue: value > 0 ? value.toStringAsFixed(2) : '',
        onChanged: (text) {
          final newValue = double.tryParse(text) ?? 0.0;
          onChanged(newValue);
        },
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          prefix: Text(
            '\$ ',
            style: TextStyle(
              color: Color(0xFF00B894),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Prix requis';
          }
          if (double.tryParse(value) == null) {
            return 'Prix invalide';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSupplySection() {
    return Consumer<CryptoAdminProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SUPPLY',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSupplyField(
                    'Circulating Supply',
                    provider.circulatingSupply,
                        (value) => provider.circulatingSupply = value,
                    '19500000',
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildSupplyField(
                    'Total Supply',
                    provider.totalSupply,
                        (value) => provider.totalSupply = value,
                    '21000000',
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildSupplyField(
              'Market Cap (\$)',
              provider.marketCap,
                  (value) => provider.marketCap = value,
              '950000000000',
            ),
          ],
        );
      },
    );
  }

  Widget _buildSupplyField(String label, double value, Function(double) onChanged, String hint) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color(0xFF1A202C),
      ),
      child: TextFormField(
        initialValue: value > 0 ? value.toStringAsFixed(0) : '',
        onChanged: (text) {
          final newValue = double.tryParse(text) ?? 0.0;
          onChanged(newValue);
        },
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCategoryRankSection() {
    return Consumer<CryptoAdminProvider>(
      builder: (context, provider, child) {
        return Row(
          children: [
            // Catégorie
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CATÉGORIE',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Color(0xFF1A202C),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: provider.category,
                      onChanged: (value) {
                        if (value != null) {
                          provider.category = value;
                        }
                      },
                      items: [
                        'DeFi',
                        'NFT',
                        'Gaming',
                        'Layer 1',
                        'Layer 2',
                        'AI',
                        'Meme',
                        'Privacy',
                        'Oracle',
                        'Storage',
                        'Stable',
                        'Volatile',
                        'Precious',
                        'Community',
                        'Premium',
                      ].map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      dropdownColor: Color(0xFF1A202C),
                      icon: Icon(Iconsax.arrow_down_1, color: Color(0xFF00B894)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            // Rank
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RANK',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Color(0xFF1A202C),
                    ),
                    child: TextFormField(
                      initialValue: provider.rank > 0 ? provider.rank.toString() : '',
                      onChanged: (text) {
                        final newRank = int.tryParse(text) ?? 1;
                        provider.rank = newRank;
                      },
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: '1',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Rank requis';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Rank invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTradingSettings() {
    return Consumer<CryptoAdminProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PARAMÈTRES DE TRADING',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            // Trending Switch
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Color(0xFF1A202C),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.trend_up, color: Color(0xFFFF6B9D), size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Crypto Trending',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  Switch(
                    value: provider.isTrending,
                    onChanged: (value) => provider.isTrending = value,
                    activeColor: Color(0xFFFF6B9D),
                    activeTrackColor: Color(0xFFFF6B9D).withOpacity(0.3),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Daily Limits
            Row(
              children: [
                Expanded(
                  child: _buildLimitField(
                    'Variation Max (%)',
                    provider.dailyMaxChange,
                        (value) => provider.dailyMaxChange = value,
                    '0.2',
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildLimitField(
                    'Variation Min (%)',
                    provider.dailyMinChange,
                        (value) => provider.dailyMinChange = value,
                    '-0.2',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLimitField(String label, double value, Function(double) onChanged, String hint) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color(0xFF1A202C),
      ),
      child: TextFormField(
        initialValue: value != 0 ? value.toString() : '',
        onChanged: (text) {
          final newValue = double.tryParse(text) ?? 0.0;
          onChanged(newValue);
        },
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          suffix: Text(
            '%',
            style: TextStyle(
              color: Color(0xFF00B894),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Consumer<CryptoAdminProvider>(
      builder: (context, provider, child) {
        if (provider.isUploading) {
          return Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00B894).withOpacity(0.6),
                  Color(0xFF00D4AA).withOpacity(0.6),
                ],
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    widget.cryptoId != null ? 'Modification...' : 'Création en cours...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Color(0xFF00B894),
                Color(0xFF00D4AA),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00B894).withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _saveCrypto(provider),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.cryptoId != null ? Iconsax.edit : Iconsax.add_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      widget.cryptoId != null ? 'MODIFIER LA CRYPTO' : 'CRÉER LA CRYPTO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _saveCrypto(CryptoAdminProvider provider) async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        if (widget.cryptoId != null) {
          await provider.updateCrypto(widget.cryptoId!);
        } else {
          await provider.createCrypto();
        }

        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.cryptoId != null
                  ? 'Crypto modifiée avec succès!'
                  : 'Crypto créée avec succès!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Color(0xFF00B894),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e.toString()}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Color(0xFFE84393),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}