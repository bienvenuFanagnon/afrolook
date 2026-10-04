import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../ads/ad_config.dart';
import '../../ads/admob_service.dart';

/// Pub récompensée AdMob (ex. « regarder une pub pour poster sans attendre »).
/// Même API qu'avant : [showAd] via GlobalKey, [onUserEarnedReward], [onAdDismissed].
class RewardedAdWidget extends StatefulWidget {
  final void Function(double amount, String name) onUserEarnedReward;
  final void Function()? onAdDismissed;
  final Widget? child;

  const RewardedAdWidget({
    Key? key,
    required this.onUserEarnedReward,
    this.onAdDismissed,
    this.child,
  }) : super(key: key);

  @override
  RewardedAdWidgetState createState() => RewardedAdWidgetState();

  // Méthode statique pour déclencher l'affichage via une GlobalKey
  static void showAd(GlobalKey<RewardedAdWidgetState> key) {
    key.currentState?.showAd();
  }
}

class RewardedAdWidgetState extends State<RewardedAdWidget> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && AdConfig.current.enabled) AdmobService.loadRewarded();
  }

  Future<void> showAd() async {
    // Pas de pub sur le web : on continue comme si elle avait été fermée
    if (kIsWeb) {
      widget.onAdDismissed?.call();
      return;
    }
    final shown = AdmobService.showRewarded(
      onEarned: () => widget.onUserEarnedReward(1, 'reward'),
      onDismissed: widget.onAdDismissed,
    );
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vidéo en cours de chargement, réessayez dans un instant...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdmobService.rewardedReadyNotifier,
      builder: (context, ready, _) {
        if (widget.child != null) {
          return GestureDetector(
            onTap: showAd,
            child: Opacity(opacity: ready ? 1.0 : 0.5, child: widget.child),
          );
        }
        return ElevatedButton.icon(
          onPressed: ready ? showAd : null,
          icon: const Icon(Icons.card_giftcard),
          label: Text(ready ? '🎁 Gagner une récompense' : 'Chargement...'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
          ),
        );
      },
    );
  }
}
