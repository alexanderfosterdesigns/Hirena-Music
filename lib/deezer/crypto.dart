import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Deezer stream cryptography (Blowfish-CBC "stripe") and the legacy
/// `cdns-proxy` stream-path obfuscation (AES-128-ECB).
///
/// Faithful port of deemix's `generateBlowfishKey` / `decryptChunk` and
/// `generateStreamPath`. Verified against cross-implementation golden vectors
/// in `docs/DEEZER_REFERENCE.md` (§7) and `test/deezer_crypto_test.dart`.
abstract final class DeezerCrypto {
  static const String _secret = 'g4el58wc0zvf9na1';
  static const String _urlKey = 'jo6aey6haid2Teih';

  /// Blowfish-CBC IV for each 2048-byte chunk (fixed, no chaining).
  static final Uint8List _bfIv = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);

  static const int chunkSize = 2048;
  static const int stripeWindow = chunkSize * 3;

  /// Derives the 16-byte Blowfish key from a track id.
  ///
  /// `key[i] = md5(trackId)[i] XOR md5(trackId)[i+16] XOR SECRET[i]`
  static Uint8List blowfishKeyFor(int trackId) {
    final idMd5 = md5.convert(utf8.encode('$trackId')).toString();
    final key = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      key[i] = idMd5.codeUnitAt(i) ^ idMd5.codeUnitAt(i + 16) ^ _secret.codeUnitAt(i);
    }
    return key;
  }

  /// Decrypts a single 2048-byte chunk with Blowfish-CBC (fixed IV, no padding).
  static Uint8List decryptChunk(Uint8List chunk, Uint8List key) {
    if (chunk.length != chunkSize) {
      throw ArgumentError('decryptChunk requires a $chunkSize-byte chunk');
    }
    final cipher = CBCBlockCipher(BlowfishEngine())
      ..init(false, ParametersWithIV<KeyParameter>(KeyParameter(key), _bfIv));
    return cipher.process(chunk);
  }

  /// True when the 2048-byte block at [blockIndex] is encrypted in the stripe
  /// (only every 3rd block, starting at index 0).
  static bool isBlockEncrypted(int blockIndex) => blockIndex % 3 == 0;

  /// Builds the legacy `cdns-proxy` stream path for a track.
  ///
  /// Returns the hex-encoded, AES-128-ECB encrypted path (lowercase).
  static String streamPath({
    required int sngId,
    required String md5Origin,
    required int mediaVersion,
    required int format,
  }) {
    const sep = '\u00A4'; // byte 0xA4 in latin-1
    final urlPart = '$md5Origin$sep$format$sep$sngId$sep$mediaVersion';
    final urlPartBytes = latin1.encode(urlPart);
    final md5val = md5.convert(urlPartBytes).toString();

    var step2 = '$md5val$sep$urlPart$sep';
    step2 += '.' * (16 - (step2.length % 16));
    final step2Bytes = latin1.encode(step2);

    final cipher = AESEngine()
      ..init(true, KeyParameter(latin1.encode(_urlKey)));
    final out = Uint8List(step2Bytes.length);
    for (var i = 0; i < step2Bytes.length; i += 16) {
      final block = Uint8List.sublistView(step2Bytes, i, i + 16);
      final enc = cipher.process(block);
      out.setRange(i, i + 16, enc);
    }
    return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Full legacy fallback URL (see reference §4b).
  static String cryptedStreamUrl({
    required int sngId,
    required String md5Origin,
    required int mediaVersion,
    required int format,
  }) {
    final path = streamPath(
      sngId: sngId,
      md5Origin: md5Origin,
      mediaVersion: mediaVersion,
      format: format,
    );
    final shard = md5Origin.isEmpty ? '0' : md5Origin[0];
    return 'https://e-cdns-proxy-$shard.dzcdn.net/mobile/1/$path';
  }
}

/// Streaming decryptor that reproduces deemix's stripe pattern:
/// process the encrypted stream in 6144-byte windows, decrypting the first
/// 2048-byte block of each window and passing the next 4096 bytes through.
final class StripeDecryptor {
  StripeDecryptor(this._key);

  final Uint8List _key;
  Uint8List _pending = Uint8List(0);

  /// Feeds encrypted bytes, returning the corresponding decrypted bytes.
  Uint8List push(Uint8List incoming) {
    final combined = _concat(_pending, incoming);
    final out = BytesBuilder(copy: false);
    var offset = 0;
    while (combined.length - offset >= DeezerCrypto.stripeWindow) {
      out.add(
        DeezerCrypto.decryptChunk(
          Uint8List.sublistView(combined, offset, offset + DeezerCrypto.chunkSize),
          _key,
        ),
      );
      out.add(Uint8List.sublistView(
        combined,
        offset + DeezerCrypto.chunkSize,
        offset + DeezerCrypto.stripeWindow,
      ));
      offset += DeezerCrypto.stripeWindow;
    }
    _pending = Uint8List.fromList(combined.sublist(offset));
    return out.toBytes();
  }

  /// Flushes any buffered tail (decrypting a full final block if present).
  Uint8List flush() {
    final out = BytesBuilder(copy: false);
    if (_pending.length >= DeezerCrypto.chunkSize) {
      out.add(
        DeezerCrypto.decryptChunk(
          Uint8List.sublistView(_pending, 0, DeezerCrypto.chunkSize),
          _key,
        ),
      );
      out.add(Uint8List.sublistView(_pending, DeezerCrypto.chunkSize));
    } else {
      out.add(_pending);
    }
    _pending = Uint8List(0);
    return out.toBytes();
  }

  static Uint8List _concat(Uint8List a, Uint8List b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return Uint8List.fromList([...a, ...b]);
  }
}

/// Decrypts a *random-access* range of a stripe stream.
///
/// Because decryption is length-preserving, a plaintext byte range maps 1:1 to
/// the encrypted byte range, but encrypted blocks must be fetched on 2048-byte
/// boundaries. Callers supply [fetchRange] (which returns encrypted bytes for
/// an aligned range) and get plaintext for [start, end).
abstract final class RangeDecryptor {
  static Future<Uint8List> decryptRange({
    required int start,
    required int end,
    required Uint8List key,
    required Future<Uint8List> Function(int start, int end) fetchRange,
  }) async {
    final blockStart = (start ~/ DeezerCrypto.chunkSize) * DeezerCrypto.chunkSize;
    final blockEnd = ((end - 1) ~/ DeezerCrypto.chunkSize + 1) * DeezerCrypto.chunkSize;

    final encrypted = await fetchRange(blockStart, blockEnd);
    if (encrypted.length != blockEnd - blockStart) {
      throw StateError('Range fetch size mismatch: '
          'wanted ${blockEnd - blockStart}, got ${encrypted.length}');
    }

    final plain = Uint8List(encrypted.length);
    final firstBlock = blockStart ~/ DeezerCrypto.chunkSize;
    for (var i = 0; i < encrypted.length; i += DeezerCrypto.chunkSize) {
      final blockIndex = firstBlock + (i ~/ DeezerCrypto.chunkSize);
      final block = Uint8List.sublistView(encrypted, i, i + DeezerCrypto.chunkSize);
      if (DeezerCrypto.isBlockEncrypted(blockIndex)) {
        plain.setRange(i, i + DeezerCrypto.chunkSize, DeezerCrypto.decryptChunk(block, key));
      } else {
        plain.setRange(i, i + DeezerCrypto.chunkSize, block);
      }
    }
    return Uint8List.sublistView(plain, start - blockStart, end - blockStart);
  }
}
