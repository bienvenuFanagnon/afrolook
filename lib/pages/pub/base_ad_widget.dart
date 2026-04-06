import 'package:flutter/material.dart';
import '../../services/ad_service.dart';

abstract class BaseAdWidget extends StatefulWidget {
  final bool forceShow; // Pour forcer l'affichage même sur Web (debug)

  const BaseAdWidget({Key? key, this.forceShow = false}) : super(key: key);
}

abstract class BaseAdWidgetState<T extends BaseAdWidget> extends State<T> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeAd();
  }

  void _initializeAd() {
    if (!widget.forceShow) {
    // if (!AdService.adsSupported && !widget.forceShow) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Ads not supported on this platform';
      });
      return;
    }

    loadAd();
  }

  @override
  void dispose() {
    disposeAd();
    super.dispose();
  }

  // À implémenter par les classes filles
  void loadAd();
  void disposeAd();
  Widget buildAdWidget();

  @override
  Widget build(BuildContext context) {
    // Si pas supporté et pas forcé, ne rien afficher
    if ( !widget.forceShow) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const SizedBox.shrink();

      // return _buildLoadingWidget();
    }

    if (_hasError) {
      return const SizedBox.shrink();

      // return _buildErrorWidget();
    }

    return buildAdWidget();
  }


  // Méthodes pour les classes filles
  void setLoading(bool loading) => setState(() => _isLoading = loading);
  void setError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
  }
  void setLoaded() => setState(() => _isLoading = false);
}