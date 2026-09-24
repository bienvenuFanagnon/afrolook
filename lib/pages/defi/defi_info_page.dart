import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DefiInfoPage extends StatelessWidget {
  const DefiInfoPage({super.key});

  static const Color _yellow = Color(0xFFFFE14D);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surfaceVariant,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: _yellow, size: 22),
            const SizedBox(width: 8),
            Text('Comment fonctionnent les Défis ?',
                style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(c),
            const SizedBox(height: 28),
            _section(c, '1. Crée ton défi', Icons.add_circle_outline,
                'Publie un post (image, vidéo, audio ou texte) et active le mode Défi. Définis la cagnotte, la durée, et les éventuels frais de participation et de vote.'),
            _section(c, '2. La cagnotte', Icons.monetization_on_outlined,
                'Tu verses une cagnotte de départ en Afrcoins au moment de la création. Les frais de participation et de vote viennent s\'y ajouter au fil du temps.'),
            _section(c, '3. Les participants répondent', Icons.video_camera_front_outlined,
                'Les autres utilisateurs répondent à ton défi avec leur propre post (même liberté de format). Si tu as activé un frais de participation, ils paient en Afrcoins pour s\'inscrire.'),
            _section(c, '4. Le vote', Icons.how_to_vote_outlined,
                'La communauté vote pour ses favoris. Si le vote est payant, chaque vote coûte le prix que tu as fixé (minimum 5 Afrcoins). Un utilisateur ne peut voter qu\'une seule fois par réponse.'),
            _section(c, '5. Le classement', Icons.leaderboard_outlined,
                'Les réponses sont classées par nombre de votes, puis par score, puis par likes et interactions en cas d\'égalité.'),
            _section(c, '6. Les gains', Icons.emoji_events_outlined,
                'À la fin du défi, la cagnotte est distribuée aux gagnants selon la répartition choisie. L\'application prend 30% de chaque paiement (arrondi à l\'entier supérieur en sa faveur). Le reste va directement dans ton solde de gains Afrcoins.'),
            const SizedBox(height: 12),
            _revenueBox(c),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _hero(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x33FFE14D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _yellow.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: _yellow, size: 48),
          const SizedBox(height: 12),
          Text(
            'Les Défis Afrolook',
            style: TextStyle(color: _yellow, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Lance un défi, fais concourir la communauté et récompense les meilleurs créateurs avec ta cagnotte.',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _section(AppColors c, String title, IconData icon, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x22FFE14D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _yellow, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueBox(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exemple de revenus', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          _exRow(c, 'Frais de participation', '100 Afrcoins × 20 participants = 2 000 🪙'),
          _exRow(c, 'Frais de vote (10 coins)', '10 × 150 votes = 1 500 🪙'),
          _exRow(c, 'Total brut', '3 500 🪙'),
          _exRow(c, 'Part app (30% ↑)', '− 1 050 🪙'),
          _exRow(c, 'Tu reçois', '2 450 🪙 + ta cagnotte si tu gagnes', highlight: true),
        ],
      ),
    );
  }

  Widget _exRow(AppColors c, String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: highlight ? _yellow : c.textPrimary, fontSize: 12, fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
