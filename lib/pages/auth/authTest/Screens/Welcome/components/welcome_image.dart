import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../../../../theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';

class WelcomeImage extends StatelessWidget {
  const WelcomeImage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          color: colors.surface.withOpacity(0.6),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              l10n.welcomeBienvenue,
              style: const TextStyle(fontWeight: FontWeight.w900,fontSize: 30,color: Colors.green),
            ),
          ),
        ),
        // const SizedBox(height: defaultPadding * 2),
        // Row(
        //   children: [
        //     const Spacer(),
        //     // Expanded(
        //     //   flex: 8,
        //     //   child:Image.asset('assets/images/welcomtof.png') ,
        //     //     /*
        //     //     SvgPicture.asset(
        //     //       "assets/icons/chat.svg",
        //     //     )*/
        //     // ),
        //     // const Spacer(),
        //   ],
        // ),
        const SizedBox(height: defaultPadding * 2),
      ],
    );
  }
}