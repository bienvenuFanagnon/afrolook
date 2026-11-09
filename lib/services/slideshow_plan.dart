/// Durée d'un diaporama (08/11/2026) : la personne choisit la durée TOTALE (7, 15, 30 ou 60 s) et le temps se répartit à parts égales entre les images, ou bien une durée par image.
/// Mêmes calculs que le serveur (`Slideshow.php`) : ce qui est affiché est ce qui sera fabriqué. Une transition est toujours plus courte que chaque image.
class SlideshowPlan {
  SlideshowPlan._();

  /// Durées totales proposées (secondes).
  static const List<int> totals = [7, 15, 30, 60];

  static const double minImage = 1;
  static const double maxImage = 10;
  static const double transitionMax = .5;

  /// Maximum du film (secondes) : 60 pour un post, 30 pour une chronique, le même pour tous les plans.
  static const double maxTotal = 60;

  static double _r2(double v) => (v * 100).round() / 100;

  /// Durée d'une transition : 0,5 s au plus, jamais plus que la moitié de la plus courte image ; 0 pour une coupe franche.
  static double transitionSeconds(String transition, double shortest) => transition == 'none' ? 0 : _r2(shortest / 2 < transitionMax ? shortest / 2 : transitionMax);

  /// Durée de chaque image pour [total] secondes au total : (total + chevauchements) ÷ nombre d'images.
  static List<double> even(int n, double total, String transition) {
    final t = transition == 'none' ? 0.0 : transitionMax;
    final d = _r2((total + (n - 1) * t) / n);
    return List<double>.filled(n, d);
  }

  /// Durée totale du film : somme des images moins les chevauchements des transitions.
  static double total(List<double> d, String transition) {
    if (d.isEmpty) return 0;
    final t = transitionSeconds(transition, d.reduce((a, b) => a < b ? a : b));
    return _r2(d.fold<double>(0, (a, b) => a + b) - (d.length - 1) * t);
  }

  /// Durée totale la plus courte possible pour [n] images (1 s chacune).
  static double minTotal(int n, String transition) => total(List<double>.filled(n, minImage), transition);

  /// null si tout va bien ; sinon `short` (une image serait trop courte) ou `long` (le film dépasserait le maximum).
  static String? problem(List<double> d, String transition, {double max = maxTotal}) {
    if (d.isEmpty) return null;
    if (d.reduce((a, b) => a < b ? a : b) < minImage - 0.001) return 'short';
    if (total(d, transition) > max + 0.05) return 'long';
    return null;
  }

  /// « 3,4 » : nombre à la française, sans zéro inutile.
  static String fmt(double v) {
    final s = v.toStringAsFixed(1);
    return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll('.', ',');
  }
}
