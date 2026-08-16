import 'package:flutter_test/flutter_test.dart';
import 'package:hirena_music/deezer/models.dart';

void main() {
  test('Track.fromGw parses gw-light fields', () {
    final t = Track.fromGw({
      'SNG_ID': 3135556,
      'SNG_TITLE': 'Test Song',
      'DURATION': 210,
      'MD5_ORIGIN': 'abc123',
      'MEDIA_VERSION': 1,
      'TRACK_TOKEN': 'tok',
      'TRACK_TOKEN_EXPIRE': 0,
      'ALB_ID': 123,
      'ALB_TITLE': 'Album',
      'ALB_PICTURE': 'covermd5',
      'ART_ID': 456,
      'ART_NAME': 'Artist',
      'ART_PICTURE': 'artmd5',
      'GAIN': -8,
      'FILESIZE_MP3_320': 9000000,
    });
    expect(t.id, 3135556);
    expect(t.title, 'Test Song');
    expect(t.duration, 210);
    expect(t.albumTitle, 'Album');
    expect(t.artistName, 'Artist');
    expect(t.filesize320, 9000000);
  });

  test('SearchResults.fromGw parses sections', () {
    final s = SearchResults.fromGw({
      'TRACK': {
        'data': [
          {'SNG_ID': 1, 'SNG_TITLE': 'A'},
          {'SNG_ID': 2, 'SNG_TITLE': 'B'},
        ]
      },
      'ALBUM': {
        'data': [
          {'ALB_ID': 10, 'ALB_TITLE': 'X'},
        ]
      },
    });
    expect(s.tracks.length, 2);
    expect(s.albums.length, 1);
  });

  test('SessionInfo.maxFormat honors tier', () {
    expect(const SessionInfo(apiToken: 'a', licenseToken: 'l', canStreamHq: false, canStreamLossless: false).maxFormat, 1);
    expect(const SessionInfo(apiToken: 'a', licenseToken: 'l', canStreamHq: true, canStreamLossless: false).maxFormat, 3);
    expect(const SessionInfo(apiToken: 'a', licenseToken: 'l', canStreamHq: true, canStreamLossless: true).maxFormat, 9);
  });
}
