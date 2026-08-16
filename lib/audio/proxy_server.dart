import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../deezer/crypto.dart';
import 'stream_handle.dart';

/// A loopback HTTP server that decrypts Deezer streams on the fly and serves
/// plain audio to the audio engine. Supports `Range` for seeking.
///
/// Requests: `GET /track/{id}?q={quality}` where quality is 9 (FLAC),
/// 3 (MP3_320) or 1 (MP3_128).
final class StreamProxyServer {
  StreamProxyServer({
    required Future<StreamHandle?> Function(int trackId, int quality) resolve,
    Dio? dio,
  })  : _resolve = resolve,
        _dio = dio ?? Dio();

  final Future<StreamHandle?> Function(int trackId, int quality) _resolve;
  final Dio _dio;
  HttpServer? _server;

  int get port => _server?.port ?? 0;
  bool get running => _server != null;

  String urlFor(int trackId, int quality) =>
      'http://${HConstants.proxyHost}:$port/track/$trackId?q=$quality';

  Future<int> start() async {
    if (_server != null) return port;
    HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        HConstants.proxyPort,
      );
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    _server = server;
    server.listen(_handle, onError: (Object e) {
      HLog.w('proxy error: $e');
    });
    HLog.i('stream proxy listening on ${server.address.address}:${server.port}');
    return server.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    final segments = req.uri.pathSegments;
    try {
      if (segments.length < 2 || segments[0] != 'track') {
        await _sendStatus(req, HttpStatus.notFound);
        return;
      }
      final id = int.tryParse(segments[1]);
      final quality = int.tryParse(req.uri.queryParameters['q'] ?? '') ?? 3;
      if (id == null) {
        await _sendStatus(req, HttpStatus.badRequest);
        return;
      }
      final handle = await _resolve(id, quality);
      if (handle == null) {
        await _sendStatus(req, HttpStatus.notFound);
        return;
      }
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        await _serveRange(req, handle, range);
      } else {
        await _serveFull(req, handle);
      }
    } catch (e, st) {
      HLog.e('proxy serve failed', e, st);
      try {
        await _sendStatus(req, HttpStatus.internalServerError);
      } catch (_) {/* ignore */}
    }
  }

  Future<void> _serveFull(HttpRequest req, StreamHandle handle) async {
    final res = req.response;
    _setContentType(res, handle.contentType);
    if (handle.size != null) {
      res.headers.set(HttpHeaders.contentLengthHeader, handle.size!);
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    }
    try {
      final resp = await _dio.get<ResponseBody>(
        handle.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'User-Agent': HConstants.userAgent},
        ),
      );
      final body = resp.data;
      if (body == null) throw StateError('empty stream');
      final decryptor = StripeDecryptor(handle.key);
      await res.addStream(_decrypting(body.stream, decryptor));
      await res.close();
    } on DioException catch (e) {
      HLog.w('upstream stream failed: ${e.message}');
      await res.close();
    }
  }

  Future<void> _serveRange(
    HttpRequest req,
    StreamHandle handle,
    String rangeHeader,
  ) async {
    final size = handle.size;
    final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rangeHeader);
    if (match == null || size == null) {
      // Unknown length or malformed range — stream from the beginning.
      await _serveFull(req, handle);
      return;
    }
    var start = match.group(1)!.isEmpty ? 0 : int.parse(match.group(1)!);
    var end = match.group(2)!.isEmpty
        ? size - 1
        : int.parse(match.group(2)!).clamp(0, size - 1);
    if (start > end || start >= size) {
      req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size');
      await req.response.close();
      return;
    }
    end = end.clamp(0, size - 1);

    final res = req.response;
    res.statusCode = HttpStatus.partialContent;
    _setContentType(res, handle.contentType);
    res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$size');
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.headers.set(HttpHeaders.contentLengthHeader, end - start + 1);

    try {
      final plain = await RangeDecryptor.decryptRange(
        start: start,
        end: end + 1,
        key: handle.key,
        fetchRange: (from, to) => _fetchUpstreamRange(handle.url, from, to),
      );
      res.add(plain);
      await res.close();
    } catch (e) {
      HLog.w('range decrypt failed ($e); falling back to sequential skip');
      await _serveWithSkip(req, handle, start);
    }
  }

  /// Sequential fallback for seeking: stream from byte 0, discard the prefix.
  Future<void> _serveWithSkip(HttpRequest req, StreamHandle handle, int skip) async {
    final res = req.response;
    res.statusCode = HttpStatus.ok;
    _setContentType(res, handle.contentType);
    try {
      final resp = await _dio.get<ResponseBody>(
        handle.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'User-Agent': HConstants.userAgent},
        ),
      );
      final body = resp.data;
      if (body == null) throw StateError('empty stream');
      final decryptor = StripeDecryptor(handle.key);
      var skipped = 0;
      final out = _decrypting(body.stream, decryptor).map((chunk) {
        if (skipped >= skip) return chunk;
        final remaining = skip - skipped;
        skipped += chunk.length;
        if (skipped <= skip) return const <int>[];
        return chunk.sublist(chunk.length - (skipped - skip));
      });
      await res.addStream(out);
      await res.close();
    } catch (_) {
      await res.close();
    }
  }

  Future<Uint8List> _fetchUpstreamRange(String url, int from, int to) async {
    final resp = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'User-Agent': HConstants.userAgent,
          'Range': 'bytes=$from-${to - 1}',
        },
      ),
    );
    final bytes = Uint8List.fromList(resp.data ?? const []);
    if (bytes.length != to - from) {
      throw StateError('Range fetch size mismatch: wanted ${to - from}, got ${bytes.length}');
    }
    return bytes;
  }

  Stream<List<int>> _decrypting(Stream<List<int>> src, StripeDecryptor dec) async* {
    await for (final chunk in src) {
      final out = dec.push(Uint8List.fromList(chunk));
      if (out.isNotEmpty) yield out;
    }
    final tail = dec.flush();
    if (tail.isNotEmpty) yield tail;
  }

  void _setContentType(HttpResponse res, String contentType) {
    final i = contentType.indexOf('/');
    if (i > 0) {
      res.headers.contentType =
          ContentType(contentType.substring(0, i), contentType.substring(i + 1));
    }
  }

  Future<void> _sendStatus(HttpRequest req, int code) async {
    req.response.statusCode = code;
    await req.response.close();
  }
}
