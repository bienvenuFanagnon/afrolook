import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_sheet.dart';

/// Ouvre la liste des langues de l'application. Même fenêtre depuis la page de connexion,
/// la création de compte et le menu : le choix est mémorisé et s'applique tout de suite.
Future<void> showLanguagePickerSheet(BuildContext context) {
  final colors = AppColors.of(context);
  final l10n = AppLocalizations.of(context);
  final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
  return showResponsiveBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.langChoose,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: kSupportedLocales.entries.map((entry) {
                    final selected = localeProvider.locale.languageCode == entry.key;
                    return ListTile(
                      title: Text(entry.value, style: TextStyle(color: colors.textPrimary)),
                      trailing: selected ? Icon(Icons.check, color: colors.primary) : null,
                      onTap: () {
                        localeProvider.setLocale(Locale(entry.key));
                        Navigator.pop(sheetContext);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Petit bouton « 🌐 FR ▾ » à mettre dans l'en-tête d'une page (connexion, inscription…).
class LanguageSelectorButton extends StatelessWidget {
  const LanguageSelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final code = context.watch<LocaleProvider>().locale.languageCode;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).langChoose,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showLanguagePickerSheet(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primary.withOpacity(0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Text(code.toUpperCase(), style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              Icon(Icons.expand_more, size: 16, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
