// home_posts_widgets.dart
import 'package:flutter/material.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class HomePostsWidgets {
  // Widget de filtre par pays
  static Widget buildCountryFilter({
    required BuildContext context,
    required String? selectedCountryCode,
    required bool showAllCountries,
    required Function(String?) onCountrySelected,
    required Function onShowAllCountries,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE21221), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Filtrer par pays',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Option "Tous les pays"
          Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: () => onShowAllCountries(),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: showAllCountries ? Color(0xFFE21221) : Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.public,
                  color: showAllCountries ? Colors.white : Colors.grey[400],
                ),
              ),
              title: Text(
                '🌍 Tous les pays',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Afficher les posts de toute l\'Afrique',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              trailing: showAllCountries
                  ? Icon(Icons.check, color: Colors.green)
                  : null,
            ),
          ),

          Divider(color: Colors.grey[700], height: 20),

          // Liste des pays africains populaires
          Text(
            'Pays africains',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 8),

          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: AfricanCountry.allCountries.length,
              itemBuilder: (context, index) {
                final country = AfricanCountry.allCountries[index];
                final isSelected = !showAllCountries &&
                    selectedCountryCode?.toLowerCase() == country.code.toLowerCase();

                return GestureDetector(
                  onTap: () => onCountrySelected(country.code),
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFFE21221) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(country.flag),
                        SizedBox(width: 6),
                        Text(
                          country.code,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Affichage du filtre actif
          if (!showAllCountries && selectedCountryCode != null)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFE21221).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE21221)),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, color: Color(0xFFE21221), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtre actif : ${selectedCountryCode!.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onShowAllCountries(),
                    child: Text(
                      'Réinitialiser',
                      style: TextStyle(
                        color: Color(0xFFFFD600),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Widget d'en-tête avec filtre
  static Widget buildHeader({
    required BuildContext context,
    required String? selectedCountryCode,
    required bool showAllCountries,
    required Function onFilterPressed,
    required Function onRefresh,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Découvrir',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => onRefresh(),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(0xFFE21221)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.public,
                          color: showAllCountries ? Colors.white : Color(0xFFFFD600),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          showAllCountries ? '🌍' : selectedCountryCode?.toUpperCase() ?? '🌍',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                          onPressed: () => onFilterPressed(),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),

          // Info sur le filtre actuel
          if (!showAllCountries)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFFE21221).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Color(0xFFE21221), size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Affichage des posts disponibles en ${selectedCountryCode!.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Widget de chargement
  static Widget buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: Column(
        children: List.generate(3, (index) => Container(
          margin: EdgeInsets.all(12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey[700],
                    radius: 20,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 12,
                        color: Colors.grey[700],
                      ),
                      SizedBox(height: 6),
                      Container(
                        width: 60,
                        height: 10,
                        color: Colors.grey[700],
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[700],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 60, height: 12, color: Colors.grey[700]),
                  Container(width: 60, height: 12, color: Colors.grey[700]),
                  Container(width: 60, height: 12, color: Colors.grey[700]),
                ],
              ),
            ],
          ),
        )),
      ),
    );
  }

  // Widget d'indicateur de chargement
  static Widget buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: LoadingAnimationWidget.flickr(
          size: 40,
          leftDotColor: Color(0xFFE21221),
          rightDotColor: Color(0xFFFFD600),
        ),
      ),
    );
  }

  // Widget d'erreur
  static Widget buildErrorWidget(Function onRetry) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Color(0xFFE21221),
            size: 50,
          ),
          SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Impossible de charger les posts',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => onRetry(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE21221),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // Widget vide
  static Widget buildEmptyWidget({
    String? countryCode,
    bool showAllCountries = true,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feed,
            color: Colors.grey[600],
            size: 60,
          ),
          SizedBox(height: 16),
          Text(
            showAllCountries
                ? 'Aucun post disponible pour le moment'
                : 'Aucun post disponible en ${countryCode?.toUpperCase() ?? "ce pays"}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            showAllCountries
                ? 'Revenez plus tard pour découvrir de nouveaux contenus'
                : 'Essayez de voir les posts de tous les pays',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Badge de pays sur un post
  static Widget buildCountryBadge(Post post) {
    final isAllCountries = post.isAvailableInAllCountries == true;
    final countryCodes = post.availableCountries ?? [];

    String displayText = isAllCountries ? '🌍' : '';
    Color badgeColor = isAllCountries ? Colors.green : Color(0xFFE21221);

    if (!isAllCountries && countryCodes.isNotEmpty) {
      // Prendre le premier pays comme indicateur
      displayText = countryCodes.first;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.public,
            size: 12,
            color: badgeColor,
          ),
          SizedBox(width: 4),
          Text(
            displayText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}