import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chiffrement de bout en bout (au repos) des messages texte des chats privés.
///
/// Principe (Option A simplifiée) :
/// - chaque utilisateur génère, à la première utilisation sur l'appareil, une
///   paire de clés X25519. La clé privée reste sur l'appareil
///   (flutter_secure_storage), la clé publique est publiée dans
///   `UserKeys/{userId}.public_key`.
/// - pour une conversation entre A et B, les deux peuvent calculer le même
///   secret partagé via Diffie-Hellman (ECDH(privA, pubB) == ECDH(privB, pubA)),
///   puis en dériver (HKDF) une clé AES-256 propre à ce chat.
/// - le texte des messages est chiffré (AES-256-GCM) avec cette clé avant
///   d'être stocké dans Firestore, et déchiffré à la lecture.
class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static const String _cipherPrefix = 'enc:v1:';

  static final Map<String, SecretKey> _chatKeyCache = {};

  static String _privateKeyStorageKey(String userId) => 'chat_private_key_$userId';

  /// Récupère (ou génère) la paire de clés X25519 de [userId] et publie sa
  /// clé publique dans Firestore si nécessaire.
  static Future<SimpleKeyPair> _getOrCreateKeyPair(String userId) async {
    final storageKey = _privateKeyStorageKey(userId);
    final existing = await _storage.read(key: storageKey);

    if (existing != null) {
      final seed = base64Decode(existing);
      return _x25519.newKeyPairFromSeed(seed);
    }

    final keyPair = await _x25519.newKeyPair();
    final keyPairData = await keyPair.extract();
    await _storage.write(key: storageKey, value: base64Encode(keyPairData.bytes));

    final publicKey = await keyPair.extractPublicKey();
    await FirebaseFirestore.instance.collection('UserKeys').doc(userId).set({
      'public_key': base64Encode(publicKey.bytes),
    }, SetOptions(merge: true));

    return keyPair;
  }

  /// Calcule (et met en cache) la clé AES-256 dérivée pour la conversation
  /// [chatId] entre [myUserId] et [otherUserId].
  ///
  /// Retourne `null` si [otherUserId] n'a pas encore de clé publique publiée
  /// (premier lancement de l'app sur son appareil) : dans ce cas, les
  /// messages sont envoyés en clair jusqu'à ce que sa clé soit disponible.
  static Future<SecretKey?> getChatKey(String chatId, String myUserId, String otherUserId) async {
    final cached = _chatKeyCache[chatId];
    if (cached != null) return cached;

    try {
      final myKeyPair = await _getOrCreateKeyPair(myUserId);

      final otherDoc = await FirebaseFirestore.instance.collection('UserKeys').doc(otherUserId).get();
      final otherPublicB64 = otherDoc.data()?['public_key'] as String?;
      if (otherPublicB64 == null) return null;

      final otherPublicKey = SimplePublicKey(base64Decode(otherPublicB64), type: KeyPairType.x25519);
      final sharedSecret = await _x25519.sharedSecretKey(keyPair: myKeyPair, remotePublicKey: otherPublicKey);
      final sharedBytes = await sharedSecret.extractBytes();

      final derived = await _hkdf.deriveKey(
        secretKey: SecretKey(sharedBytes),
        nonce: utf8.encode(chatId),
        info: utf8.encode('afrolook_chat_key'),
      );

      _chatKeyCache[chatId] = derived;
      return derived;
    } catch (e) {
      print('⚠️ EncryptionService.getChatKey error ($chatId): $e');
      return null;
    }
  }

  /// Chiffre [plainText] avec [key] (AES-256-GCM), encodé en base64 avec un
  /// préfixe de version.
  static Future<String> encryptText(SecretKey key, String plainText) async {
    final secretBox = await _aesGcm.encrypt(utf8.encode(plainText), secretKey: key);
    return '$_cipherPrefix${base64Encode(secretBox.concatenation())}';
  }

  /// Déchiffre un texte produit par [encryptText]. Les textes non préfixés
  /// (anciens messages envoyés avant l'activation du chiffrement) sont
  /// retournés tels quels.
  static Future<String> decryptText(SecretKey key, String cipherText) async {
    if (!cipherText.startsWith(_cipherPrefix)) return cipherText;

    final raw = base64Decode(cipherText.substring(_cipherPrefix.length));
    final secretBox = SecretBox.fromConcatenation(
      raw,
      nonceLength: _aesGcm.nonceLength,
      macLength: _aesGcm.macAlgorithm.macLength,
    );
    final clear = await _aesGcm.decrypt(secretBox, secretKey: key);
    return utf8.decode(clear);
  }
}
