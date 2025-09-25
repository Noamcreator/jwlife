import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<File> decryptJwdatFile() async {
  // 1. Charger le fichier .jwdat depuis les assets
  final byteData = await rootBundle.load('');
  final archive = ZipDecoder().decodeBytes(byteData.buffer.asUint8List());

  // 2. Trouver manifest.json et contents
  final manifestFile = archive.firstWhere((f) => f.name == 'manifest.json');
  final contentsFile = archive.firstWhere((f) => f.name == 'contents');

  final manifestJson = json.decode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;

  // 3. Lire le hash pour dériver la clé
  final hash = manifestJson['hash'] as String;
  final hashBytes = hexToBytes(hash);

  // 4. Séparer en clé et IV puis scramble les deux
  final halfLength = hashBytes.length ~/ 2;
  final key = Uint8List(halfLength);
  final iv = Uint8List(halfLength);
  scrambleKeyIv(hashBytes, key, iv);

  // 5. Déchiffrer le contenu
  final encrypter = encrypt.Encrypter(
    encrypt.AES(
      encrypt.Key(key),
      mode: encrypt.AESMode.cbc,
      padding: 'PKCS7',
    ),
  );

  final encryptedContent = contentsFile.content;
  final decrypted = encrypter.decryptBytes(
    encrypt.Encrypted(encryptedContent),
    iv: encrypt.IV(iv),
  );

  // 6. Sauvegarder le fichier SQLite dans un dossier temporaire
  final tempDir = await getTemporaryDirectory();
  final dbFile = File('${tempDir.path}/mepsunit.db');
  await dbFile.writeAsBytes(decrypted);

  return dbFile;
}

Uint8List hexToBytes(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(result);
}

void scrambleKeyIv(Uint8List input, Uint8List keyOut, Uint8List ivOut) {
  final half = input.length ~/ 2;
  for (int i = 0; i < half; i++) {
    keyOut[i] = input[i];
    ivOut[i] = input[i + half];
  }

  final prng = _PRNG(1318765823, -1170915321);
  int rnd = 0;

  for (int i = 0; i < keyOut.length; i++) {
    if (i % 4 == 0) rnd = prng.next();
    keyOut[i] ^= (rnd & 0xFF);
    rnd >>= 8;
  }

  for (int i = 0; i < ivOut.length; i++) {
    if (i % 4 == 0) rnd = prng.next();
    ivOut[i] ^= (rnd & 0xFF);
    rnd >>= 8;
  }
}

class _PRNG {
  int _a;
  int _b;

  _PRNG(int aInit, int bInit)
      : _a = _mask32(aInit),
        _b = _mask32(bInit);

  int next() {
    _a = _mask32((_mask16(_a) * 36969) + (_a >> 16));
    _b = _mask32((_mask16(_b) * 18000) + (_b >> 16));
    return _mask32((_a << 16) + (_b & 0xFFFF));
  }

  static int _mask16(int n) => n & 0xFFFF;
  static int _mask32(int n) => n & 0xFFFFFFFF;
}
