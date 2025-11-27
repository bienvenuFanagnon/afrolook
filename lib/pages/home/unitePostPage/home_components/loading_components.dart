import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingComponents {
  static Widget buildShimmerEffect() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget buildErrorWidget(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 50),
          SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  static Widget buildLoadingMoreWidget() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 10),
            Text(
              'Chargement anticipé...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildNoMoreContentWidget() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'Vous avez vu tous les contenus',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}