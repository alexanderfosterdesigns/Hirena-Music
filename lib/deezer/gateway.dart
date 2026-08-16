import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/constants.dart';
import '../core/result.dart';
import 'crypto.dart';
import 'models.dart';

/// Error codes surfaced by the gateway.
abstract final class GatewayError {
  static const invalidArl = 'invalid_arl';
  static const notAuthed = 'not_authed';
  static const network = 'network';
  static const geolocked = 'geolocked';
  static const noStream = 'no_stream';
  static const http = 'http';
}

/// A resolved, playable stream.
final class ResolvedStream {
  const ResolvedStream({required this.url, required this.format, required this.encrypted});

  final String url;
  final int format; // 9=FLAC, 3=MP3_320, 1=MP3_128
  final bool encrypted; // BF_CBC_STRIPE
}

/// Deezer gateway: ARL auth (streaming-key only), gw-light catalog calls, and
/// stream URL resolution. Implements the privacy firewall — the ARL is used
/// exclusively to obtain the tokens required to stream; no user profile data
/// is ever returned or persisted.
final class DeezerGateway {
  DeezerGateway({Dio? dio}) : _dio = dio ?? Dio(_baseOptions());

  final Dio _dio;

  SessionInfo? _session;
  String? _arl;

  bool get isAuthed => _session != null;

  /// Highest quality the current session may stream (9=FLAC, 3=MP3_320, 1=MP3_128).
  int get maxFormat => _session?.maxFormat ?? 1;

  static BaseOptions _baseOptions() => BaseOptions(
        headers: {'User-Agent': HConstants.userAgent},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
      );

  /// Logs in with an ARL. Returns [SessionInfo] on success (containing only
  /// streaming tokens + tier flags).
  Future<Result<SessionInfo>> loginWithArl(String arl) async {
    final token = arl.trim();
    if (token.isEmpty) {
      return const Err(AppError(GatewayError.invalidArl, message: 'Empty ARL'));
    }
    _arl = token;
    _session = null;

    final res = await _gwCall('deezer.getUserData', {}, apiToken: null);
    if (res is Err) return Err(res.error);

    final results = (res as Ok<Map<String, dynamic>>).value;
    final user = results['USER'];
    if (user is! Map || _asInt(user['USER_ID']) == 0) {
      _arl = null;
      return const Err(AppError(GatewayError.invalidArl, message: 'Invalid or expired ARL'));
    }

    final checkForm = results['checkForm'];
    final options = (user['OPTIONS'] as Map?)?.cast<String, dynamic>() ?? const {};
    final session = SessionInfo(
      apiToken: _asString(checkForm),
      licenseToken: _asString(options['license_token']),
      canStreamHq: _asBool(options['web_hq']) || _asBool(options['mobile_hq']),
      canStreamLossless:
          _asBool(options['web_lossless']) || _asBool(options['mobile_lossless']),
      country: _asString(options['license_country']),
    );
    if (session.apiToken.isEmpty) {
      _arl = null;
      return const Err(AppError(GatewayError.invalidArl, message: 'Missing api token'));
    }
    _session = session;
    return Ok(session);
  }

  void logout() {
    _arl = null;
    _session = null;
  }

  // --- Catalog --------------------------------------------------------------

  Future<Result<Track>> track(int id) async {
    final res = await _gwCall('deezer.pageTrack', {'SNG_ID': id});
    if (res is Err) return Err(res.error);
    final results = (res as Ok<Map<String, dynamic>>).value;
    final data = results['DATA'];
    if (data is! Map) {
      return const Err(AppError(GatewayError.http, message: 'Track not found'));
    }
    return Ok(Track.fromGw(data.cast<String, dynamic>()));
  }

  Future<Result<List<Track>>> tracks(List<int> ids) async {
    final res = await _gwCall('song.getListData', {'SNG_IDS': ids});
    if (res is Err) return Err(res.error);
    final results = (res as Ok<Map<String, dynamic>>).value;
    final data = results['data'];
    if (data is! List) return const Ok([]);
    return Ok(data.whereType<Map>().map((e) => Track.fromGw(e.cast<String, dynamic>())).toList());
  }

  Future<Result<(Album, List<Track>)>> album(int id) async {
    final res = await _gwCall('deezer.pageAlbum',
        {'ALB_ID': id, 'lang': 'en', 'header': true, 'tab': 0});
    if (res is Err) return Err(res.error);
    final results = (res as Ok<Map<String, dynamic>>).value;
    final data = results['DATA'];
    final songs = results['SONGS'];
    final tracks = _parseTrackList(songs);
    if (data is! Map) {
      return const Err(AppError(GatewayError.http, message: 'Album not found'));
    }
    return Ok((Album.fromGw(data.cast<String, dynamic>()), tracks));
  }

  Future<Result<(Artist, List<Track>, List<Album>)>> artist(int id) async {
    final res = await _gwCall('deezer.pageArtist',
        {'ART_ID': id, 'lang': 'en', 'header': true, 'tab': 0});
    if (res is Err) return Err(res.error);
    final results = (res as Ok<Map<String, dynamic>>).value;
    final artistData = results['ARTIST'];
    if (artistData is! Map) {
      return const Err(AppError(GatewayError.http, message: 'Artist not found'));
    }
    final artist = Artist.fromGw(artistData.cast<String, dynamic>());
    final top = _parseTrackList(results['TOP']);
    final albumsData = results['ALBUMS'];
    final albums = _parseList(albumsData, Album.fromGw);
    return Ok((artist, top, albums));
  }

  Future<Result<(Playlist, List<Track>)>> playlist(int id) async {
    final res = await _gwCall('deezer.pagePlaylist',
        {'PLAYLIST_ID': id, 'lang': 'en', 'header': true, 'tab': 0});
    if (res is Err) return Err(res.error);
    final results = (res as Ok<Map<String, dynamic>>).value;
    final data = results['DATA'];
    if (data is! Map) {
      return const Err(AppError(GatewayError.http, message: 'Playlist not found'));
    }
    return Ok((Playlist.fromGw(data.cast<String, dynamic>()), _parseTrackList(results['SONGS'])));
  }

  Future<Result<SearchResults>> search(String query, {int limit = 25}) async {
    final res = await _gwCall('deezer.pageSearch', {
      'query': query,
      'start': 0,
      'nb': limit,
      'suggest': true,
      'artist_suggest': true,
      'top_tracks': true,
    });
    if (res is Err) return Err(res.error);
    return Ok(SearchResults.fromGw((res as Ok<Map<String, dynamic>>).value));
  }

  Future<Result<Charts>> charts() async {
    final res = await _gwCall('deezer.getCharts', {});
    if (res is Err) return Err(res.error);
    return Ok(Charts.fromGw((res as Ok<Map<String, dynamic>>).value));
  }

  Future<Result<List<Album>>> discography(int artistId) async {
    final res = await _gwCall('album.getDiscography',
        {'ART_ID': artistId, 'discography_mode': 'all', 'nb': 200, 'nb_songs': 0, 'start': 0});
    if (res is Err) return Err(res.error);
    final results = (res as Ok<Map<String, dynamic>>).value;
    return Ok(_parseList(results['data'], Album.fromGw));
  }

  /// Deezer's own "similar tracks" signal (used as a recommendation nominator).
  Future<Result<List<Track>>> similarTracks(int trackId) async {
    final res = await _gwCall('deezer.pageTrack', {'SNG_ID': trackId});
    if (res is Err) return Err(res.error);
    final results = (res as Ok<Map<String, dynamic>>).value;
    final similar = results['SIMILAR_TRACKS'];
    return Ok(_parseTrackList(similar));
  }

  // --- Streams --------------------------------------------------------------

  /// Resolves a playable stream for [track], trying [preferredFormat] then
  /// falling back down the quality ladder.
  Future<Result<ResolvedStream>> resolveStream(Track track, {int? preferredFormat}) async {
    final session = _session;
    if (session == null) {
      return const Err(AppError(GatewayError.notAuthed));
    }

    final ladder = <int>[];
    if (preferredFormat != null) {
      ladder.add(preferredFormat);
    }
    for (final f in const [9, 3, 1]) {
      if (!ladder.contains(f)) ladder.add(f);
    }

    AppError? lastError;
    for (final format in ladder) {
      if (format > session.maxFormat) continue;
      final r = await _resolveViaGetUrl(track, format);
      if (r.isOk) return r;
      lastError = (r as Err<ResolvedStream>).error;
    }
    return Err(lastError ?? const AppError(GatewayError.noStream));
  }

  Future<Result<ResolvedStream>> _resolveViaGetUrl(Track track, int format) async {
    final session = _session!;
    if (track.trackToken.isEmpty) {
      return const Err(AppError(GatewayError.noStream, message: 'No track token'));
    }
    final name = _formatName(format);
    try {
      final resp = await _dio.post<dynamic>(
        HConstants.mediaGetUrl,
        data: {
          'license_token': session.licenseToken,
          'media': [
            {
              'type': 'FULL',
              'formats': [
                {'cipher': 'BF_CBC_STRIPE', 'format': name},
              ],
            },
          ],
          'track_tokens': [track.trackToken],
        },
        options: Options(
          headers: _cookieHeader,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );
      final data = resp.data;
      if (data is! Map || data['data'] is! List) {
        return const Err(AppError(GatewayError.noStream));
      }
      final entry = (data['data'] as List).firstOrNull;
      if (entry is! Map) return const Err(AppError(GatewayError.noStream));
      if (entry['errors'] != null) {
        final errors = entry['errors'] as List;
        final code = errors.isNotEmpty && errors.first is Map
            ? _asInt((errors.first as Map)['code'])
            : 0;
        if (code == 2002) {
          return const Err(AppError(GatewayError.geolocked, message: 'Not available in your region'));
        }
        return const Err(AppError(GatewayError.noStream, message: 'Stream unavailable'));
      }
      final media = entry['media'];
      if (media is! List || media.isEmpty) {
        return const Err(AppError(GatewayError.noStream, message: 'No media'));
      }
      final sources = (media.first as Map)['sources'];
      if (sources is! List || sources.isEmpty) {
        return const Err(AppError(GatewayError.noStream, message: 'No source'));
      }
      final url = _asString((sources.first as Map)['url']);
      if (url.isEmpty) return const Err(AppError(GatewayError.noStream));
      return Ok(ResolvedStream(url: url, format: format, encrypted: true));
    } on DioException catch (e) {
      return Err(AppError(GatewayError.http,
          message: e.message ?? 'get_url failed', cause: e));
    }
  }

  /// Legacy fallback URL (no token exchange) — used when get_url returns
  /// nothing but track fields are present.
  String fallbackStreamUrl(Track track, int format) => DeezerCrypto.cryptedStreamUrl(
        sngId: track.id,
        md5Origin: track.md5Origin,
        mediaVersion: track.mediaVersion,
        format: format,
      );

  // --- Low-level ------------------------------------------------------------

  Map<String, String> get _cookieHeader =>
      _arl == null ? const {} : {'Cookie': 'arl=$_arl'};

  Future<Result<Map<String, dynamic>>> _gwCall(
    String method,
    Map<String, dynamic> args, {
    String? apiToken,
  }) async {
    final session = _session;
    final token = apiToken ?? session?.apiToken;
    try {
      return await _gwAttempt(method, args, token);
    } on DioException catch (e) {
      return Err(AppError(GatewayError.network,
          message: e.message ?? 'gw-light failed', cause: e));
    }
  }

  Future<Result<Map<String, dynamic>>> _gwAttempt(
    String method,
    Map<String, dynamic> args,
    String? token,
  ) async {
    final resp = await _dio.post<dynamic>(
      HConstants.gwLight,
      queryParameters: {
        'api_version': '1.0',
        'api_token': token ?? 'null',
        'input': '3',
        'method': method,
      },
      data: args,
      options: Options(
        headers: _cookieHeader,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    final body = resp.data;
    if (body is! Map) {
      throw DioException(
          requestOptions: resp.requestOptions, message: 'Unexpected gw-light response');
    }
    final error = body['error'];
    if (error is Map && error.isNotEmpty) {
      final raw = jsonEncode(error);
      if (raw.contains('invalid api token') || raw.contains('Invalid CSRF token')) {
        if (token != null) {
          final refreshed = await _refreshToken();
          if (refreshed) return _gwAttempt(method, args, _session!.apiToken);
        }
      }
      throw DioException(requestOptions: resp.requestOptions, message: 'gw error: $raw');
    }
    final results = body['results'];
    if (results is! Map) {
      throw DioException(requestOptions: resp.requestOptions, message: 'No results');
    }
    return Ok(results.cast<String, dynamic>());
  }

  Future<bool> _refreshToken() async {
    if (_arl == null) return false;
    final res = await _gwCall('deezer.getUserData', {}, apiToken: null);
    if (res is Err) return false;
    final results = (res as Ok<Map<String, dynamic>>).value;
    final checkForm = results['checkForm'];
    if (checkForm == null) return false;
    final options = ((results['USER'] as Map?)?['OPTIONS'] as Map?)?.cast<String, dynamic>() ?? const {};
    _session = SessionInfo(
      apiToken: _asString(checkForm),
      licenseToken: _asString(options['license_token']),
      canStreamHq: _asBool(options['web_hq']) || _asBool(options['mobile_hq']),
      canStreamLossless:
          _asBool(options['web_lossless']) || _asBool(options['mobile_lossless']),
      country: _asString(options['license_country']),
    );
    return true;
  }

  // --- Helpers --------------------------------------------------------------

  static String _formatName(int format) => switch (format) {
        9 => 'FLAC',
        3 => 'MP3_320',
        1 => 'MP3_128',
        _ => 'MP3_128',
      };

  static List<Track> _parseTrackList(dynamic v) => _parseList(v, Track.fromGw);

  static List<T> _parseList<T>(dynamic v, T Function(Map<String, dynamic>) f) {
    if (v is! Map) return const [];
    final data = v['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList();
  }
}

int _asInt(dynamic v, [int fallback = 0]) =>
    v is int ? v : (v is String ? int.tryParse(v) ?? fallback : fallback);

String _asString(dynamic v, [String fallback = '']) =>
    v is String ? v : (v == null ? fallback : v.toString());

bool _asBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
