import 'dart:typed_data';

/// A resolved, decryptable stream plus metadata needed to serve it.
final class StreamHandle {
  const StreamHandle({
    required this.url,
    required this.key,
    required this.contentType,
    this.size,
  });

  final String url;
  final Uint8List key;
  final String contentType; // e.g. "audio/mpeg"
  final int? size; // total decrypted byte length (== encrypted length)
}
