import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../../../../theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Size size = MediaQuery.of(context).size;
    return Container(
      margin: EdgeInsets.symmetric(vertical: size.height * 0.02),
      width: size.width * 0.8,
      child: Row(
        children: <Widget>[
          buildDivider(colors),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              AppLocalizations.of(context).commonOr.toUpperCase(),
              style: TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          buildDivider(colors),
        ],
      ),
    );
  }

  Expanded buildDivider(AppColors colors) {
    return Expanded(
      child: Divider(
        color: colors.divider,
        height: 1.5,
      ),
    );
  }
}
