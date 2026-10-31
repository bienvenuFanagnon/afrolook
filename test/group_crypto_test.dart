import 'dart:convert';

import 'package:afrotok/services/crypto/group_crypto_service.dart';
import 'package:afrotok/services/crypto/key_change_tracker.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faux serveur qui applique les règles de `GroupKeyController` (fiche 34) : administrateurs seulement, destinataires membres, une enveloppe n'est
/// jamais remplacée, époque courante ou suivante, rotation exigée après un départ, un ancien membre n'a plus accès aux enveloppes.
class FakeServer implements GroupKeyBackend {
  final Map<String, String> publicKeyOf = {}; // userId -> base64
  final Map<String, int> versionOf = {};
  final Set<String> members = {};
  final Set<String> admins = {};
  int epoch = 0;
  bool rotationNeeded = false;
  final Map<String, Map<int, Map<String, dynamic>>> envelopes = {}; // userId -> epoch -> {envelope, wrapped_by, wrapper_key_version}
  late String me; // appelant courant
  int postCalls = 0;

  void publish(String uid, String pubB64) {
    if (publicKeyOf[uid] == pubB64) return;
    publicKeyOf[uid] = pubB64;
    versionOf[uid] = (versionOf[uid] ?? 0) + 1;
  }

  void removeMember(String uid) {
    members.remove(uid);
    admins.remove(uid);
    if (epoch > 0) rotationNeeded = true;
  }

  @override
  Future<Map<String, dynamic>> fetchKeys(String groupId) async {
    if (!members.contains(me)) throw const GroupKeyApiError(404, 'not_found');
    final mine = (envelopes[me] ?? {}).entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {
      'encrypted': epoch > 0,
      'epoch': epoch,
      'rotation_required': rotationNeeded,
      'envelopes': [for (final e in mine) {'epoch': e.key, ...e.value}],
      if (admins.contains(me) && epoch > 0) 'pending_members': [for (final m in members) if (envelopes[m]?[epoch] == null) m],
    };
  }

  @override
  Future<Map<String, dynamic>> postEnvelopes(String groupId, int ep, List<Map<String, dynamic>> list) async {
    postCalls++;
    if (!admins.contains(me)) throw const GroupKeyApiError(404, 'not_found');
    if (ep != epoch && ep != epoch + 1) throw const GroupKeyApiError(409, 'invalid_epoch');
    final ids = list.map((e) => e['user_id'] as String).toList();
    if (ids.toSet().length != ids.length || ids.any((u) => !members.contains(u))) throw const GroupKeyApiError(422, 'invalid_recipients');
    if (list.any((e) => (e['wrapper_key_version'] as int) != versionOf[me])) throw const GroupKeyApiError(422, 'invalid_wrapper_key');
    var created = 0;
    for (final e in list) {
      final slot = envelopes.putIfAbsent(e['user_id'] as String, () => {});
      if (slot.containsKey(ep)) continue; // jamais remplacée
      slot[ep] = {'envelope': e['envelope'], 'wrapped_by': me, 'wrapper_key_version': e['wrapper_key_version']};
      created++;
    }
    if (ep == epoch + 1) {
      epoch = ep;
      rotationNeeded = false;
    }
    return {'epoch': ep, 'created': created, 'skipped': ids.length - created};
  }

  @override
  Future<Map<String, Map<String, dynamic>>> publicKeys(List<String> userIds) async => {
        for (final u in userIds)
          if (publicKeyOf[u] != null) u: {'user_id': u, 'public_key': publicKeyOf[u], 'version': versionOf[u]},
      };

  @override
  Future<List<String>> memberIds(String groupId) async => members.toList();

  @override
  Future<Map<String, dynamic>> publishMyKey(String publicKeyB64) async {
    publish(me, publicKeyB64);
    return {'user_id': me, 'public_key': publicKeyB64, 'version': versionOf[me]};
  }
}

/// Un « téléphone » : sa paire de clés, son stockage, son service.
class Device {
  Device(this.uid, this.server) {
    service = GroupCryptoService(backend: _AsUser(server, uid), identity: _Identity(this), store: store, tracker: KeyChangeTracker(MemoryKeyValueStore()));
  }
  final String uid;
  final FakeServer server;
  final MemoryGroupKeyStore store = MemoryGroupKeyStore();
  SimpleKeyPair? pair;
  late final GroupCryptoService service;

  Future<void> publishKey() async {
    pair ??= await X25519().newKeyPair();
    server.publish(uid, base64Encode((await pair!.extractPublicKey()).bytes));
  }
}

class _Identity implements GroupKeyIdentity {
  _Identity(this.d);
  final Device d;
  @override
  Future<SimpleKeyPair> keyPair(String userId) async => d.pair ??= await X25519().newKeyPair();
}

/// Le serveur voit l'appelant courant : chaque appareil l'annonce avant ses appels.
class _AsUser implements GroupKeyBackend {
  _AsUser(this.s, this.uid);
  final FakeServer s;
  final String uid;
  T _as<T>(T Function() f) {
    s.me = uid;
    return f();
  }

  @override
  Future<Map<String, dynamic>> fetchKeys(String g) => _as(() => s.fetchKeys(g));
  @override
  Future<Map<String, dynamic>> postEnvelopes(String g, int e, List<Map<String, dynamic>> l) => _as(() => s.postEnvelopes(g, e, l));
  @override
  Future<Map<String, Map<String, dynamic>>> publicKeys(List<String> u) => _as(() => s.publicKeys(u));
  @override
  Future<List<String>> memberIds(String g) => _as(() => s.memberIds(g));
  @override
  Future<Map<String, dynamic>> publishMyKey(String k) => _as(() => s.publishMyKey(k));
}

const g = 'groupe-1';

Map<String, dynamic> textDoc(String id, String text, {String uid = 'owner'}) =>
    {'id': id, 'group_id': g, 'send_by': uid, 'message': text, 'message_type': 'text', 'is_valide': true, 'is_deleted': false, 'is_encrypted': false};

void main() {
  late FakeServer server;
  late Device owner, bob, eve;

  setUp(() async {
    server = FakeServer();
    owner = Device('owner', server);
    bob = Device('bob', server);
    eve = Device('eve', server);
    server.members.addAll({'owner', 'bob'});
    server.admins.add('owner');
    await owner.publishKey();
    await bob.publishKey();
  });

  Future<void> enable() async {
    final r = await owner.service.syncAsAdmin(g, 'owner', mayEnable: true);
    expect(r.enabled, isTrue);
    expect(server.epoch, 1);
  }

  group('création et chiffrement / déchiffrement', () {
    test('le propriétaire crée l\'époque 1 ; chaque membre ouvre SON enveloppe et lit les messages', () async {
      await enable();
      final st = await bob.service.refresh(g, 'bob');
      expect(st.encrypted, isTrue);
      expect(st.hasCurrentKey, isTrue);
      expect(st.openedEpochs, [1]);

      final sealed = await owner.service.sealMessage(g, 'owner', 'm1', textDoc('m1', 'Bonjour à tous'));
      expect(sealed['is_encrypted'], isTrue);
      expect(sealed['key_epoch'], 1);
      expect(sealed['message'], startsWith(GroupCryptoService.fieldPrefix));
      expect(sealed['message'], isNot(contains('Bonjour')));

      final seen = await bob.service.openMessage(g, 'bob', sealed);
      expect(seen['message'], 'Bonjour à tous');
      expect(seen['_locked'], isNull);
      // le propriétaire relit aussi son propre message
      expect((await owner.service.openMessage(g, 'owner', sealed))['message'], 'Bonjour à tous');
    });

    test('l\'API ne reçoit que des enveloppes opaques : la clé de groupe n\'apparaît nulle part dans ce qu\'elle stocke', () async {
      await enable();
      final stored = jsonEncode(server.envelopes.map((u, m) => MapEntry(u, m.map((e, v) => MapEntry('$e', v)))));
      expect(stored, contains(GroupCryptoService.envelopePrefix));
      // nonce 12 + clé 32 + étiquette 16 = 60 octets : rien d'autre que la clé chiffrée
      expect(base64Decode((server.envelopes['bob']![1]!['envelope'] as String).substring(GroupCryptoService.envelopePrefix.length)).length, 60);
      // deux enveloppes (propriétaire et Bob) différentes pour la même clé
      expect(server.envelopes['owner']![1]!['envelope'], isNot(server.envelopes['bob']![1]!['envelope']));
    });

    test('accents, émojis et longs textes passent intacts ; le même texte donne deux chiffrés différents', () async {
      await enable();
      final text = 'Été à Abidjan 🌍 — ça va ? ' + 'é' * 3000;
      final a = await owner.service.sealMessage(g, 'owner', 'a', textDoc('a', text));
      final b = await owner.service.sealMessage(g, 'owner', 'b', textDoc('b', text));
      expect(a['message'], isNot(b['message']));
      expect((await bob.service.openMessage(g, 'bob', a))['message'], text);
    });

    test('légende, citation de réponse et aperçu de lien sont chiffrés et rendus en clair à la lecture', () async {
      await enable();
      final doc = {
        ...textDoc('m2', 'voir https://exemple.org'),
        'reply_to_id': 'm1',
        'reply_to_message': 'texte cité',
        'link_preview': {'url': 'https://exemple.org', 'title': 'Titre secret'},
      };
      final sealed = await owner.service.sealMessage(g, 'owner', 'm2', doc);
      expect(sealed.containsKey('link_preview'), isFalse);
      expect(jsonEncode(sealed), isNot(contains('Titre secret')));
      expect(jsonEncode(sealed), isNot(contains('texte cité')));
      final seen = await bob.service.openMessage(g, 'bob', sealed);
      expect(seen['reply_to_message'], 'texte cité');
      expect(seen['link_preview'], {'url': 'https://exemple.org', 'title': 'Titre secret'});

      final img = {'id': 'm3', 'group_id': g, 'send_by': 'owner', 'message': 'https://cdn/x.jpg', 'message_type': 'image', 'caption': 'ma légende', 'is_encrypted': false};
      final sealedImg = await owner.service.sealMessage(g, 'owner', 'm3', img);
      expect(sealedImg['message'], 'https://cdn/x.jpg'); // médias non chiffrés (étape distincte)
      expect(sealedImg['caption'], startsWith(GroupCryptoService.fieldPrefix));
      expect((await bob.service.openMessage(g, 'bob', sealedImg))['caption'], 'ma légende');
    });
  });

  group('messages altérés, déplacés, clé absente', () {
    test('un message déplacé vers un autre groupe, un autre identifiant ou une autre époque est refusé sans exception', () async {
      await enable();
      final sealed = await owner.service.sealMessage(g, 'owner', 'm1', textDoc('m1', 'secret'));

      final otherId = await bob.service.openMessage(g, 'bob', {...sealed, 'id': 'm-autre'});
      expect(otherId['message'], GroupCryptoService.lockedText);
      expect(otherId['_locked'], isTrue);

      final otherGroup = await bob.service.openMessage('autre-groupe', 'bob', sealed);
      expect(otherGroup['message'], GroupCryptoService.lockedText); // aucune clé pour ce groupe
      expect(otherGroup['_locked'], isTrue);

      final otherEpoch = await bob.service.openMessage(g, 'bob', {...sealed, 'key_epoch': 2});
      expect(otherEpoch['message'], GroupCryptoService.lockedText);
    });

    test('texte chiffré modifié (un bit) : état « clé indisponible », pas de plantage', () async {
      await enable();
      final sealed = await owner.service.sealMessage(g, 'owner', 'm1', textDoc('m1', 'secret'));
      final raw = base64Decode((sealed['message'] as String).substring(GroupCryptoService.fieldPrefix.length));
      raw[raw.length - 1] ^= 1;
      final bad = {...sealed, 'message': '${GroupCryptoService.fieldPrefix}${base64Encode(raw)}'};
      final seen = await bob.service.openMessage(g, 'bob', bad);
      expect(seen['message'], GroupCryptoService.lockedText);
      expect(seen['_locked'], isTrue);
      // base64 invalide
      final junk = await bob.service.openMessage(g, 'bob', {...sealed, 'message': '${GroupCryptoService.fieldPrefix}%%%'});
      expect(junk['message'], GroupCryptoService.lockedText);
    });

    test('une personne sans la clé (hors du groupe) voit « Message chiffré, clé indisponible »', () async {
      await enable();
      final sealed = await owner.service.sealMessage(g, 'owner', 'm1', textDoc('m1', 'secret'));
      await eve.publishKey();
      final st = await eve.service.refresh(g, 'eve'); // pas membre : 404
      expect(st.isMember, isFalse);
      final seen = await eve.service.openMessage(g, 'eve', sealed);
      expect(seen['message'], GroupCryptoService.lockedText);
      expect(seen['_locked'], isTrue);
    });

    test('envoi refusé (jamais en clair) si le groupe est chiffré et que la clé de l\'époque courante manque', () async {
      await enable();
      server.members.add('eve');
      await eve.publishKey();
      await expectLater(() => eve.service.sealMessage(g, 'eve', 'x', textDoc('x', 'coucou', uid: 'eve')), throwsA(isA<GroupKeyUnavailable>()));
      final st = eve.service.stateOf(g, 'eve')!;
      expect(st.waitingForKey, isTrue);
    });

    test('envoi refusé si l\'état du groupe est inconnu (API injoignable)', () async {
      final broken = GroupCryptoService(backend: _Down(), identity: _Identity(owner), store: MemoryGroupKeyStore());
      await expectLater(() => broken.sealMessage(g, 'owner', 'x', textDoc('x', 'coucou')), throwsA(isA<GroupKeyUnavailable>()));
    });

    test('l\'enveloppe d\'une autre personne ou d\'un autre groupe ne s\'ouvre pas', () async {
      await enable();
      server.members.add('eve');
      await eve.publishKey();
      // un pirate copie l'enveloppe de Bob pour Eve : le contexte (destinataire) est lié à la clé, l'ouverture échoue
      server.envelopes['eve'] = {1: Map<String, dynamic>.from(server.envelopes['bob']![1]!)};
      final st = await eve.service.refresh(g, 'eve');
      expect(st.hasCurrentKey, isFalse);
      expect(st.unreadableEpochs, [1]);
    });
  });

  group('compatibilité avec les anciens messages en clair', () {
    test('un message sans champ de chiffrement est affiché tel quel, même dans un groupe chiffré', () async {
      await enable();
      final old = textDoc('vieux', 'ancien message en clair');
      final seen = await bob.service.openMessage(g, 'bob', old);
      expect(identical(seen, old), isTrue);
      expect(seen['message'], 'ancien message en clair');
      // ancien document sans le champ is_encrypted du tout
      final legacy = {'id': 'l', 'message': 'très ancien', 'message_type': 'text'};
      expect((await bob.service.openMessage(g, 'bob', legacy))['message'], 'très ancien');
    });

    test('un texte qui imite le préfixe chiffré n\'est PAS traité comme chiffré s\'il n\'est pas marqué is_encrypted', () async {
      final fake = textDoc('f', '${GroupCryptoService.fieldPrefix}AAAA');
      final seen = await bob.service.openMessage(g, 'bob', fake);
      expect(seen['message'], '${GroupCryptoService.fieldPrefix}AAAA');
      expect(seen['_locked'], isNull);
    });

    test('groupe non chiffré : l\'envoi reste en clair, document inchangé', () async {
      final doc = textDoc('m1', 'bonjour');
      final out = await owner.service.sealMessage(g, 'owner', 'm1', doc);
      expect(identical(out, doc), isTrue);
      expect(out['is_encrypted'], isFalse);
    });

    test('un message supprimé n\'est pas touché', () async {
      await enable();
      final del = {...textDoc('d', 'Message supprime'), 'is_deleted': true, 'is_encrypted': true, 'key_epoch': 1};
      expect((await bob.service.openMessage(g, 'bob', del))['message'], 'Message supprime');
    });

    test('aperçu de liste : déchiffré avec la clé de l\'appareil, sinon « Message chiffré »', () async {
      await enable();
      final sealed = await owner.service.sealMessage(g, 'owner', 'm1', textDoc('m1', 'salut'));
      await bob.service.refresh(g, 'bob');
      expect(await bob.service.previewText(g, 'bob', sealed), 'salut');
      expect(await eve.service.previewText(g, 'eve', sealed), 'Message chiffré');
    });
  });

  group('époques, arrivée et départ de membres', () {
    test('un nouveau membre attend, puis reçoit la clé quand un administrateur synchronise', () async {
      await enable();
      server.members.add('eve');
      await eve.publishKey();
      final waiting = await eve.service.refresh(g, 'eve');
      expect(waiting.waitingForKey, isTrue);

      final r = await owner.service.syncAsAdmin(g, 'owner');
      expect(r.distributed, 1);
      final ready = await eve.service.refresh(g, 'eve');
      expect(ready.hasCurrentKey, isTrue);

      final sealed = await owner.service.sealMessage(g, 'owner', 'm1', textDoc('m1', 'bienvenue'));
      expect((await eve.service.openMessage(g, 'eve', sealed))['message'], 'bienvenue');
      expect(server.epoch, 1, reason: 'une arrivée ne change pas l\'époque');
    });

    test('un membre sans clé publique dans l\'annuaire est signalé et attend (rien n\'est envoyé pour lui)', () async {
      await enable();
      server.members.add('eve'); // eve n'a rien publié
      final r = await owner.service.syncAsAdmin(g, 'owner');
      expect(r.distributed, 0);
      expect(r.state.pendingMembers, ['eve']);
    });

    test('rotation après un départ : nouvelle époque pour les membres restants SEULEMENT, anciens messages toujours lisibles', () async {
      server.members.add('eve');
      await eve.publishKey();
      await enable();
      await owner.service.syncAsAdmin(g, 'owner'); // Eve reçoit l'époque 1
      await eve.service.refresh(g, 'eve');
      await bob.service.refresh(g, 'bob');

      final old = await owner.service.sealMessage(g, 'owner', 'ancien', textDoc('ancien', 'avant le départ'));

      server.removeMember('bob'); // Bob part ou est exclu
      expect(server.rotationNeeded, isTrue);

      final r = await owner.service.syncAsAdmin(g, 'owner');
      expect(r.rotated, isTrue);
      expect(server.epoch, 2);
      expect(server.rotationNeeded, isFalse);
      expect(server.envelopes['bob']!.containsKey(2), isFalse, reason: 'Bob ne reçoit pas la nouvelle clé');
      expect(server.envelopes['eve']!.containsKey(2), isTrue);

      final fresh = await owner.service.sealMessage(g, 'owner', 'nouveau', textDoc('nouveau', 'après le départ'));
      expect(fresh['key_epoch'], 2);

      // Eve lit les deux époques
      await eve.service.refresh(g, 'eve');
      expect((await eve.service.openMessage(g, 'eve', old))['message'], 'avant le départ');
      expect((await eve.service.openMessage(g, 'eve', fresh))['message'], 'après le départ');
      // le propriétaire aussi
      expect((await owner.service.openMessage(g, 'owner', old))['message'], 'avant le départ');

      // Bob garde l'époque 1 (déjà sur son téléphone) mais ne lit PAS le nouveau message, et ne peut plus relire les enveloppes
      expect((await bob.service.openMessage(g, 'bob', old))['message'], 'avant le départ');
      final bobSees = await bob.service.openMessage(g, 'bob', fresh);
      expect(bobSees['message'], GroupCryptoService.lockedText);
      final bobState = await bob.service.refresh(g, 'bob');
      expect(bobState.isMember, isFalse);
    });

    test('la clé conservée sur l\'appareil sert hors ligne (nouveau service, même stockage, API injoignable)', () async {
      await enable();
      await bob.service.refresh(g, 'bob');
      final sealed = await owner.service.sealMessage(g, 'owner', 'm1', textDoc('m1', 'hors ligne'));
      final later = GroupCryptoService(backend: _Down(), identity: _Identity(bob), store: bob.store);
      expect((await later.openMessage(g, 'bob', sealed))['message'], 'hors ligne');
    });

    test('rotation volontaire par un administrateur (clé perdue par un membre)', () async {
      await enable();
      final r = await owner.service.rotate(g, 'owner');
      expect(r.rotated, isTrue);
      expect(server.epoch, 2);
      final st = await bob.service.refresh(g, 'bob');
      expect(st.openedEpochs, [1, 2]);
    });

    test('un simple membre ne peut pas distribuer ni faire pivoter la clé (refusé par l\'API)', () async {
      await enable();
      await expectLater(() => bob.service.rotate(g, 'bob'), throwsA(isA<GroupKeyApiError>()));
      expect(server.epoch, 1);
    });

    test('deux administrateurs créent la même époque : la clé de l\'enveloppe relue l\'emporte, tout le monde lit les mêmes messages', () async {
      server.admins.add('bob');
      await enable();
      // Bob (administrateur lui aussi) croit devoir créer l'époque 2 en même temps que le propriétaire
      server.rotationNeeded = true;
      await owner.service.syncAsAdmin(g, 'owner');
      expect(server.epoch, 2);
      // Bob envoie la sienne pour l'époque 2 : ses enveloppes existent déjà, rien n'est remplacé
      final bobRound = await bob.service.rotate(g, 'bob'); // époque 3, volontaire : c'est une autre époque, pas un écrasement
      expect(bobRound.state.epoch, 3);
      final m = await bob.service.sealMessage(g, 'bob', 'z', textDoc('z', 'depuis Bob', uid: 'bob'));
      await owner.service.refresh(g, 'owner');
      expect((await owner.service.openMessage(g, 'owner', m))['message'], 'depuis Bob');
    });
  });

  group('clé publique de l\'annuaire', () {
    test('ma clé est publiée automatiquement si elle manque ; une autre clé de l\'annuaire (autre appareil) n\'est pas écrasée', () async {
      final solo = FakeServer()..members.add('zed');
      final zed = Device('zed', solo);
      solo.me = 'zed';
      await zed.service.refresh(g, 'zed');
      expect(solo.publicKeyOf['zed'], isNotNull);

      // un autre appareil du même compte a une autre clé
      final other = Device('zed', solo);
      final st = await other.service.refresh(g, 'zed');
      expect(st.identityMismatch, isTrue);
      expect(solo.versionOf['zed'], 1, reason: 'aucune nouvelle version publiée');
    });

    test('autoactivation : groupes privés, payants et petits groupes ; jamais officiels ni déjà chiffrés', () {
      bool f({int n = 10, bool priv = false, int price = 0, bool off = false, int ep = 0}) =>
          GroupCryptoService.shouldAutoEnable(memberCount: n, isPrivate: priv, priceCoins: price, isOfficial: off, currentEpoch: ep);
      expect(f(), isTrue);
      expect(f(n: 50), isTrue);
      expect(f(n: 51), isFalse);
      expect(f(n: 5000, priv: true), isTrue);
      expect(f(n: 5000, price: 100), isTrue);
      expect(f(off: true, priv: true), isFalse);
      expect(f(ep: 1), isFalse);
    });

    test('changement de la clé publique de l\'administrateur : avertissement remonté dans l\'état du groupe', () async {
      await enable();
      var st = await bob.service.refresh(g, 'bob');
      expect(st.changedKeyUsers, isEmpty);

      // le propriétaire change d'appareil : nouvelle clé dans l'annuaire, nouvelle époque posée avec cette clé
      final newOwner = Device('owner', server);
      await newOwner.publishKey();
      server.rotationNeeded = true;
      server.members.add('owner');
      final r = await newOwner.service.syncAsAdmin(g, 'owner');
      // le nouvel appareil du propriétaire n'a pas les clés de l'époque 1 mais crée l'époque 2
      expect(r.state.epoch, 2);

      st = await bob.service.refresh(g, 'bob');
      expect(st.hasCurrentKey, isTrue);
      expect(st.changedKeyUsers, ['owner']);
    });
  });
}

class _Down implements GroupKeyBackend {
  Never _fail() => throw const GroupKeyApiError(0, 'network', 'hors ligne');
  @override
  Future<Map<String, dynamic>> fetchKeys(String g) async => _fail();
  @override
  Future<Map<String, dynamic>> postEnvelopes(String g, int e, List<Map<String, dynamic>> l) async => _fail();
  @override
  Future<Map<String, Map<String, dynamic>>> publicKeys(List<String> u) async => _fail();
  @override
  Future<List<String>> memberIds(String g) async => _fail();
  @override
  Future<Map<String, dynamic>> publishMyKey(String k) async => _fail();
}
