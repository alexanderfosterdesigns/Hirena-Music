import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hirena_music/deezer/crypto.dart';
import 'package:pointycastle/export.dart';

String _hex(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _bytes(String hex) => Uint8List.fromList(
    List.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));

void main() {
  group('blowfish key derivation', () {
    test('matches reference vectors (docs §7a)', () {
      expect(_hex(DeezerCrypto.blowfishKeyFor(3135556)), '6c6c666b39662c37652575603c643439');
      expect(_hex(DeezerCrypto.blowfishKeyFor(137955757)), '62663031373a206a322c7d65393b6731');
    });

    test('is deterministic and 16 bytes', () {
      expect(DeezerCrypto.blowfishKeyFor(42).length, 16);
      expect(DeezerCrypto.blowfishKeyFor(42), DeezerCrypto.blowfishKeyFor(42));
    });
  });

  group('decryptChunk (Blowfish-CBC, IV 0..7, no padding)', () {
    test('round-trips through the same cipher', () {
      final key = DeezerCrypto.blowfishKeyFor(3135556);
      final plain = Uint8List.fromList(List.generate(2048, (i) => (i * 7 + 3) & 0xFF));

      final enc = CBCBlockCipher(BlowfishEngine())
        ..init(true, ParametersWithIV<KeyParameter>(KeyParameter(key),
            Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7])));
      final cipher = enc.process(plain);
      expect(DeezerCrypto.decryptChunk(cipher, key), plain);
    });

    test('matches the OpenSSL bf-cbc golden vector (docs §7b)', () async {
      final key = _bytes('6c6c666b39662c37652575603c643439');
      final b64 =
          (await File('test/fixtures/cipher2048.b64').readAsString()).trim();
      final cipher = base64.decode(b64);
      expect(cipher.length, 2048);

      final plain = DeezerCrypto.decryptChunk(Uint8List.fromList(cipher), key);
      final expected =
          Uint8List.fromList(List.generate(2048, (i) => (i * 7 + 3) & 0xFF));
      expect(plain, expected);
    });
  });

  group('stripe decryptor', () {
    test('decrypts every 3rd block, passes the rest', () {
      final key = DeezerCrypto.blowfishKeyFor(3135556);
      final iv = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      final p0 = Uint8List.fromList(List.generate(2048, (i) => (i * 3) & 0xFF));
      final p1 = Uint8List.fromList(List.generate(2048, (i) => (i * 5 + 1) & 0xFF));
      final p2 = Uint8List.fromList(List.generate(2048, (i) => (i * 9 + 7) & 0xFF));

      Uint8List enc(Uint8List p) => (CBCBlockCipher(BlowfishEngine())
            ..init(true, ParametersWithIV<KeyParameter>(KeyParameter(key), iv)))
          .process(p);

      final dec = StripeDecryptor(key);
      final fed = <int>[...enc(p0), ...p1, ...p2]; // window 1: c0|p1|p2
      final out = dec.push(Uint8List.fromList(fed));
      expect(out, Uint8List.fromList([...p0, ...p1, ...p2]));
    });

    test('block index encryption follows i % 3 == 0', () {
      expect(DeezerCrypto.isBlockEncrypted(0), true);
      expect(DeezerCrypto.isBlockEncrypted(1), false);
      expect(DeezerCrypto.isBlockEncrypted(2), false);
      expect(DeezerCrypto.isBlockEncrypted(3), true);
      expect(DeezerCrypto.isBlockEncrypted(3000), true);
    });
  });

  group('stream path (AES-128-ECB, legacy cdns-proxy)', () {
    test('matches the golden vector (docs §7c)', () {
      final path = DeezerCrypto.streamPath(
        sngId: 3135556,
        md5Origin: 'e94eb1dc104d24a6ad96f0a1a0a2d0a2',
        mediaVersion: 0,
        format: 3,
      );
      expect(
        path,
        'f2fffb0f43dfc3e4dd4a200b7d1a68fcf662bac9035a395e444608ddc3c6f33e'
        '77669f7da33fb9609081b54ac9f2e1082e7380d37b3adefca97e42a0b1ddb9b'
        'cdfc79bba5700431b98ebd3522f101497',
      );
    });

    test('builds a sharded URL', () {
      final url = DeezerCrypto.cryptedStreamUrl(
        sngId: 3135556,
        md5Origin: 'e94eb1dc104d24a6ad96f0a1a0a2d0a2',
        mediaVersion: 0,
        format: 3,
      );
      expect(url, startsWith('https://e-cdns-proxy-e.dzcdn.net/mobile/1/'));
    });
  });
}
