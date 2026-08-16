/// Deezer domain models, parsed leniently from gw-light responses.
library;

// --- Lenient JSON helpers ---------------------------------------------------

int _i(dynamic v, [int fallback = 0]) =>
    v is int ? v : (v is String ? int.tryParse(v) ?? fallback : fallback);

String _s(dynamic v, [String fallback = '']) =>
    v is String ? v : (v == null ? fallback : v.toString());

// --- Track ------------------------------------------------------------------

final class Track {
  const Track({
    required this.id,
    required this.title,
    required this.duration,
    required this.md5Origin,
    required this.mediaVersion,
    required this.trackToken,
    required this.trackTokenExpire,
    required this.albumId,
    required this.albumTitle,
    required this.albumCoverMd5,
    required this.artistId,
    required this.artistName,
    required this.artistPictureMd5,
    this.trackNumber,
    this.diskNumber,
    this.genreId,
    this.gain,
    this.bpm,
    this.isrc,
    this.explicit = false,
    this.filesize128,
    this.filesize320,
    this.filesizeFlac,
  });

  final int id;
  final String title;
  final int duration; // seconds
  final String md5Origin;
  final int mediaVersion;
  final String trackToken;
  final int trackTokenExpire;
  final int albumId;
  final String albumTitle;
  final String albumCoverMd5;
  final int artistId;
  final String artistName;
  final String artistPictureMd5;
  final int? trackNumber;
  final int? diskNumber;
  final int? genreId;
  final int? gain;
  final int? bpm;
  final String? isrc;
  final bool explicit;
  final int? filesize128;
  final int? filesize320;
  final int? filesizeFlac;

  /// Parses a gw-light GWTrack object (uppercase keys).
  factory Track.fromGw(Map<String, dynamic> j) {
    return Track(
      id: _i(j['SNG_ID']),
      title: _s(j['SNG_TITLE']),
      duration: _i(j['DURATION']),
      md5Origin: _s(j['MD5_ORIGIN']),
      mediaVersion: _i(j['MEDIA_VERSION']),
      trackToken: _s(j['TRACK_TOKEN']),
      trackTokenExpire: _i(j['TRACK_TOKEN_EXPIRE']),
      albumId: _i(j['ALB_ID']),
      albumTitle: _s(j['ALB_TITLE']),
      albumCoverMd5: _s(j['ALB_PICTURE']),
      artistId: _i(j['ART_ID']),
      artistName: _s(j['ART_NAME']),
      artistPictureMd5: _s(j['ART_PICTURE']),
      trackNumber: _i(j['TRACK_NUMBER'], -1) == -1 ? null : _i(j['TRACK_NUMBER']),
      diskNumber: _i(j['DISK_NUMBER'], -1) == -1 ? null : _i(j['DISK_NUMBER']),
      genreId: _i(j['GENRE_ID'], -1) == -1 ? null : _i(j['GENRE_ID']),
      gain: _i(j['GAIN'], -1) == -1 ? null : _i(j['GAIN']),
      bpm: _i(j['BPM'], -1) == -1 ? null : _i(j['BPM']),
      isrc: _s(j['ISRC']),
      explicit: _i(j['EXPLICIT_LYRICS']) == 1,
      filesize128: _i(j['FILESIZE_MP3_128'], -1) == -1 ? null : _i(j['FILESIZE_MP3_128']),
      filesize320: _i(j['FILESIZE_MP3_320'], -1) == -1 ? null : _i(j['FILESIZE_MP3_320']),
      filesizeFlac: _i(j['FILESIZE_FLAC'], -1) == -1 ? null : _i(j['FILESIZE_FLAC']),
    );
  }

  /// Parses Hirena's flat local-library JSON (see AppController._trackJson).
  factory Track.fromSaved(Map<String, dynamic> j) => Track(
        id: _i(j['id']),
        title: _s(j['title']),
        duration: _i(j['duration']),
        md5Origin: '',
        mediaVersion: 0,
        trackToken: '',
        trackTokenExpire: 0,
        albumId: _i(j['album_id']),
        albumTitle: _s(j['album']),
        albumCoverMd5: _s(j['cover']),
        artistId: _i(j['artist_id']),
        artistName: _s(j['artist']),
        artistPictureMd5: '',
        bpm: _i(j['bpm'], -1) == -1 ? null : _i(j['bpm']),
        genreId: _i(j['genre_id'], -1) == -1 ? null : _i(j['genre_id']),
      );

  /// Parses a public-api track (lowercase keys; used to enrich BPM).
  factory Track.fromPublicApi(Map<String, dynamic> j) {
    final album = (j['album'] as Map?)?.cast<String, dynamic>() ?? const {};
    final artist = (j['artist'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Track(
      id: _i(j['id']),
      title: _s(j['title']),
      duration: _i(j['duration']),
      md5Origin: _s(j['md5_origin']),
      mediaVersion: _i(j['media_version']),
      trackToken: _s(j['track_token']),
      trackTokenExpire: _i(j['track_token_expire']),
      albumId: _i(album['id']),
      albumTitle: _s(album['title']),
      albumCoverMd5: _s(album['md5_image']),
      artistId: _i(artist['id']),
      artistName: _s(artist['name']),
      artistPictureMd5: _s(artist['md5_image']),
      trackNumber: _i(j['track_position'], -1) == -1 ? null : _i(j['track_position']),
      diskNumber: _i(j['disk_number'], -1) == -1 ? null : _i(j['disk_number']),
      genreId: null,
      gain: _i(j['gain'], -1) == -1 ? null : _i(j['gain']),
      bpm: _i(j['bpm'], -1) == -1 ? null : _i(j['bpm']),
      isrc: _s(j['isrc']),
      explicit: j['explicit_lyrics'] == true,
    );
  }
}

// --- Album ------------------------------------------------------------------

final class Album {
  const Album({
    required this.id,
    required this.title,
    required this.coverMd5,
    required this.artistId,
    required this.artistName,
    required this.artistPictureMd5,
    this.nbTracks,
    this.label,
    this.releaseDate,
    this.genreId,
  });

  final int id;
  final String title;
  final String coverMd5;
  final int artistId;
  final String artistName;
  final String artistPictureMd5;
  final int? nbTracks;
  final String? label;
  final String? releaseDate;
  final int? genreId;

  factory Album.fromGw(Map<String, dynamic> j) => Album(
        id: _i(j['ALB_ID']),
        title: _s(j['ALB_TITLE']),
        coverMd5: _s(j['ALB_PICTURE']),
        artistId: _i(j['ART_ID']),
        artistName: _s(j['ART_NAME']),
        artistPictureMd5: _s(j['ART_PICTURE']),
        nbTracks: _i(j['NUMBER_TRACK'], -1) == -1 ? null : _i(j['NUMBER_TRACK']),
        label: _s(j['LABEL_NAME']),
        releaseDate: _s(j['PHYSICAL_RELEASE_DATE']),
        genreId: _i(j['GENRE_ID'], -1) == -1 ? null : _i(j['GENRE_ID']),
      );
}

// --- Artist -----------------------------------------------------------------

final class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.pictureMd5,
    this.nbFan,
    this.nbAlbum,
    this.bio,
  });

  final int id;
  final String name;
  final String pictureMd5;
  final int? nbFan;
  final int? nbAlbum;
  final String? bio;

  factory Artist.fromGw(Map<String, dynamic> j) => Artist(
        id: _i(j['ART_ID']),
        name: _s(j['ART_NAME']),
        pictureMd5: _s(j['ART_PICTURE']),
        nbFan: _i(j['NB_FAN'], -1) == -1 ? null : _i(j['NB_FAN']),
        nbAlbum: _i(j['NB_ALBUM'], -1) == -1 ? null : _i(j['NB_ALBUM']),
        bio: _s(j['BIO']),
      );
}

// --- Playlist ---------------------------------------------------------------

final class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.pictureMd5,
    this.nbTracks,
    this.duration,
    this.creatorName,
  });

  final int id;
  final String title;
  final String? description;
  final String? pictureMd5;
  final int? nbTracks;
  final int? duration;
  final String? creatorName;

  factory Playlist.fromGw(Map<String, dynamic> j) => Playlist(
        id: _i(j['PLAYLIST_ID']),
        title: _s(j['TITLE']),
        description: _s(j['DESCRIPTION']),
        pictureMd5: _s(j['PICTURE']),
        nbTracks: _i(j['NB_SONG'], -1) == -1 ? null : _i(j['NB_SONG']),
        duration: _i(j['DURATION'], -1) == -1 ? null : _i(j['DURATION']),
        creatorName: _s(j['PARENT_USERNAME']),
      );
}

// --- Search results ---------------------------------------------------------

final class SearchResults {
  const SearchResults({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.playlists = const [],
  });

  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;
  final List<Playlist> playlists;

  static SearchResults fromGw(Map<String, dynamic> results) {
    List<T> parseList<T>(dynamic v, T Function(Map<String, dynamic>) f) {
      if (v is! Map) return const [];
      final data = v['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => f(e.cast<String, dynamic>()))
          .toList();
    }

    return SearchResults(
      tracks: parseList(results['TRACK'], Track.fromGw),
      albums: parseList(results['ALBUM'], Album.fromGw),
      artists: parseList(results['ARTIST'], Artist.fromGw),
      playlists: parseList(results['PLAYLIST'], Playlist.fromGw),
    );
  }
}

// --- Charts -----------------------------------------------------------------

final class Charts {
  const Charts({this.tracks = const [], this.albums = const [], this.artists = const []});

  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;

  static Charts fromGw(Map<String, dynamic> results) {
    List<T> parse<T>(dynamic v, T Function(Map<String, dynamic>) f) {
      if (v is! Map) return const [];
      final data = v['data'];
      if (data is! List) return const [];
      return data.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList();
    }

    return Charts(
      tracks: parse(results['TRACKS'], Track.fromGw),
      albums: parse(results['ALBUMS'], Album.fromGw),
      artists: parse(results['ARTISTS'], Artist.fromGw),
    );
  }
}

// --- Session (privacy firewall: only streaming-relevant fields) -------------

final class SessionInfo {
  const SessionInfo({
    required this.apiToken,
    required this.licenseToken,
    required this.canStreamHq,
    required this.canStreamLossless,
    this.country,
  });

  final String apiToken;
  final String licenseToken;
  final bool canStreamHq;
  final bool canStreamLossless;
  final String? country;

  /// Highest quality this session may stream: 9=FLAC, 3=MP3_320, 1=MP3_128.
  int get maxFormat {
    if (canStreamLossless) return 9;
    if (canStreamHq) return 3;
    return 1;
  }
}
