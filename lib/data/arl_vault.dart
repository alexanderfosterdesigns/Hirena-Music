import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

/// Encrypts the ARL at rest with AES-256-GCM.
///
/// The key is a random per-install secret stored alongside the vault (so the
/// ARL is never plaintext on disk). NOTE: this is *not* OS-keychain-grade — the
/// Windows upgrade path is DPAPI (CryptProtectData) via the eventual Rust core
/// or a small win32 FFI. See docs/DEEZER_REFERENCE.md / PLAN.md §16.
final class ArlVault {
  ArlVault._(this._dir, this._key);

  final Directory _dir;
  final Uint8List _key;

  static const _ivLen = 12;

  static Future<ArlVault> open() async {
    final dir = await getApplicationSupportDirectory();
    final vaultDir = Directory(p.join(dir.path, '.vault'));
    await vaultDir.create(recursive: true);

    final keyFile = File(p.join(vaultDir.path, '.key'));
    Uint8List key;
    if (await keyFile.exists()) {
      key = Uint8List.fromList(await keyFile.readAsBytes());
    } else {
      final rng = Random.secure();
      key = Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
      await keyFile.writeAsBytes(key, flush: true);
    }
    return ArlVault._(vaultDir, key);
  }

  Future<void> write(String arl) async {
    final iv = Uint8List.fromList(
        List.generate(_ivLen, (_) => Random.secure().nextInt(256)));
    final ct = _encrypt(utf8.encode(arl), _key, iv);
    final file = File(p.join(_dir.path, 'arl.bin'));
    await file.writeAsBytes([...iv, ...ct], flush: true);
  }

  Future<String?> read() async {
    final file = File(p.join(_dir.path, 'arl.bin'));
    if (!await file.exists()) return null;
    final raw = await file.readAsBytes();
    if (raw.length <= _ivLen) return null;
    final iv = Uint8List.fromList(raw.sublist(0, _ivLen));
    final ct = raw.sublist(_ivLen);
    try {
      return utf8.decode(_decrypt(Uint8List.fromList(ct), _key, iv));
    } catch (_) {
      return null; // tampered/corrupt vault
    }
  }

  Future<void> clear() async {
    final file = File(p.join(_dir.path, 'arl.bin'));
    if (await file.exists()) await file.delete();
  }

  static Uint8List _encrypt(List<int> plain, Uint8List key, Uint8List iv) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    return cipher.process(Uint8List.fromList(plain));
  }

  static Uint8List _decrypt(Uint8List ct, Uint8List key, Uint8List iv) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    return cipher.process(ct);
  }
}
