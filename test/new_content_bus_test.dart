import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/new_content_bus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Après une publication, le post créé passe en tête du fil (08/11/2026) : il est transmis directement, sans le chercher dans le fil
/// (qui exclut les propres posts de la personne).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le post qui vient d\'être publié est envoyé au fil dès le retour à l\'accueil', () async {
    final bus = NewContentBus.instance;
    final received = bus.newPosts.first.timeout(const Duration(seconds: 5));

    bus.rememberPublished(Post()..id = 'p-nouveau');
    bus.onPublished();

    final post = await received;
    expect(post.id, 'p-nouveau');
    // un fil qui se recharge ensuite remet ce post en tête (pendant 2 minutes)
    expect(bus.recentOwn?.id, 'p-nouveau');
  });

  test('chaque publication envoie son propre post, jamais le précédent', () async {
    final bus = NewContentBus.instance;
    final seen = <String?>[];
    final sub = bus.newPosts.listen((p) => seen.add(p.id));

    bus.rememberPublished(Post()..id = 'a');
    bus.onPublished();
    await Future.delayed(const Duration(milliseconds: 1500));
    bus.rememberPublished(Post()..id = 'b');
    bus.onPublished();
    await Future.delayed(const Duration(milliseconds: 1500));

    await sub.cancel();
    expect(seen, ['a', 'b']);
  });
}
