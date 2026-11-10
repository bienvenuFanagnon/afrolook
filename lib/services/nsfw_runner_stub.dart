/// Version web : le modèle ne tourne pas dans le navigateur (`tflite_flutter` dépend de `dart:ffi`, absent du web).
/// Aucun score n'est donc calculé et rien n'est bloqué, comme avant (l'ancien code renvoyait déjà null sur le web).
Future<List<double>?> nsfwScore(String imagePath, String asset) async => null;
