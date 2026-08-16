import '../core/result.dart';
import '../deezer/crypto.dart';
import '../deezer/gateway.dart';
import '../deezer/models.dart';
import 'stream_handle.dart';

/// Resolves a track id + quality into a decryptable [StreamHandle].
Future<StreamHandle?> resolveStreamFor(
  DeezerGateway gateway,
  int trackId,
  int quality,
) async {
  final t = await gateway.track(trackId);
  if (t is Err<Track>) return null;
  final track = (t as Ok<Track>).value;

  final r = await gateway.resolveStream(track, preferredFormat: quality);
  String url;
  int format;
  if (r is Ok<ResolvedStream>) {
    url = r.value.url;
    format = r.value.format;
  } else {
    url = gateway.fallbackStreamUrl(track, quality);
    format = quality;
  }

  final size = switch (format) {
    9 => track.filesizeFlac,
    3 => track.filesize320,
    _ => track.filesize128,
  };

  return StreamHandle(
    url: url,
    key: DeezerCrypto.blowfishKeyFor(trackId),
    contentType: format == 9 ? 'audio/flac' : 'audio/mpeg',
    size: size,
  );
}
