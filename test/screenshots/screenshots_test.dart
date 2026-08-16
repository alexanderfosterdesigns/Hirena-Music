import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hirena_music/design/theme.dart';
import 'package:hirena_music/design/tokens.dart';
import 'package:hirena_music/deezer/models.dart';
import 'package:hirena_music/ui/widgets/artwork.dart';
import 'package:hirena_music/ui/widgets/hero_billboard.dart';
import 'package:hirena_music/ui/widgets/media_row.dart';
import 'package:hirena_music/ui/widgets/poster_card.dart';
import 'package:hirena_music/ui/widgets/track_row.dart';

/// Screenshot harness.
///
/// Renders the app's REAL widgets through Flutter's own rendering engine and
/// writes PNG files to `screenshots/`. Run with:
///
///     flutter test test/screenshots/screenshots_test.dart
///
/// (This test always "passes" — its purpose is to emit the PNGs.)
Future<void> main() async {
  goldenFileComparator = _ScreenshotComparator('screenshots');

  await _loadFonts();

  testWidgets('capture all screens', (tester) async {
    tester.view.physicalSize = const Size(2880, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final covers = await _makeCovers();

    final screens = <String, Widget>{
      '01-home.png': _home(covers),
      '02-search.png': _search(covers),
      '03-album.png': _album(covers),
      '04-player.png': _player(covers),
      '05-auth.png': _auth(),
      '06-settings.png': _settings(),
      '07-library.png': _library(),
    };

    for (final entry in screens.entries) {
      await _capture(tester, entry.key, entry.value);
    }
  });
}

/// Writes every captured image to `screenshots/<basename>` and always passes.
class _ScreenshotComparator implements GoldenFileComparator {
  _ScreenshotComparator(this.outDir);

  final String outDir;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final name = golden.pathSegments.isEmpty ? 'capture.png' : golden.pathSegments.last;
    final file = File('$outDir/$name');
    await file.create(recursive: true);
    await file.writeAsBytes(imageBytes);
    // ignore: avoid_print
    print('wrote $outDir/$name (${imageBytes.length} bytes)');
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) => compare(imageBytes, golden);
}

Future<void> _capture(WidgetTester tester, String name, Widget widget) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: HTheme.dark(),
        home: Scaffold(
          backgroundColor: HColors.canvas,
          body: RepaintBoundary(
            key: ValueKey(name),
            child: SizedBox(width: 1440, height: 900, child: widget),
          ),
        ),
      ),
    );
    await tester.pump();
    // Let MemoryImage covers decode and the hero's Ken Burns tick once.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
  });
  await expectLater(find.byKey(ValueKey(name)), matchesGoldenFile(name));
}

// ---------------------------------------------------------------- fonts
Future<void> _loadFonts() async {
  try {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await inter.load();
  } catch (_) {/* renders fall back to the test font */}
  try {
    final barlow = FontLoader('Barlow')
      ..addFont(rootBundle.load('assets/fonts/Barlow-Black.ttf'));
    await barlow.load();
  } catch (_) {/* renders fall back to the test font */}
}

// ---------------------------------------------------------------- cover art
Future<List<MemoryImage>> _makeCovers() async {
  const palettes = <List<Color>>[
    [Color(0xFFFF7E5F), Color(0xFFFEB47B), Color(0xFF6A11CB)],
    [Color(0xFF0F2027), Color(0xFF2C5364), Color(0xFF203A43)],
    [Color(0xFFB20710), Color(0xFF7A0A14), Color(0xFF1A0000)],
    [Color(0xFF0575E6), Color(0xFF00F260), Color(0xFF000000)],
    [Color(0xFFFDCBF1), Color(0xFFE6DEE9), Color(0xFF9A86C9)],
    [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
    [Color(0xFF141E30), Color(0xFF243B55), Color(0xFF00C9FF)],
    [Color(0xFF232526), Color(0xFF414345), Color(0xFFBF953F)],
  ];
  final out = <MemoryImage>[];
  for (final palette in palettes) {
    out.add(await _gradientCover(palette));
  }
  return out;
}

Future<MemoryImage> _gradientCover(List<Color> colors) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const size = 512.0;
  final rect = const Rect.fromLTWH(0, 0, size, size);
  canvas.drawRect(
    rect,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(size, size),
        colors,
      ),
  );
  // A soft highlight for visual interest.
  canvas.drawCircle(
    const Offset(400, 140),
    130,
    ui.Paint()..color = const Color(0x2EFFFFFF),
  );
  canvas.drawCircle(
    const Offset(120, 420),
    90,
    ui.Paint()..color = const Color(0x1A000000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return MemoryImage(bytes!.buffer.asUint8List());
}

// ---------------------------------------------------------------- sample data
Track _track(int id, String title, String artist, String album, {int? bpm}) => Track(
      id: id,
      title: title,
      duration: 210 + (id % 40),
      md5Origin: '',
      mediaVersion: 0,
      trackToken: '',
      trackTokenExpire: 0,
      albumId: id,
      albumTitle: album,
      albumCoverMd5: '',
      artistId: id,
      artistName: artist,
      artistPictureMd5: '',
      bpm: bpm,
    );

const _artists = ['Midnight Avenue', 'Azure Theory', 'Velvet Saint', 'Nova Circuit', 'Mirage Hotel', 'Orion Fields'];

// ---------------------------------------------------------------- screens
Widget _home(List<MemoryImage> covers) {
  final tracks = [
    _track(1, 'Neon Skyline', 'Midnight Avenue', 'Neon Skyline'),
    _track(2, 'Deep Currents', 'Azure Theory', 'Deep Currents'),
    _track(3, 'Crimson Smoke', 'Velvet Saint', 'Crimson Smoke'),
    _track(4, 'Chrome Dreams', 'Nova Circuit', 'Chrome Dreams'),
    _track(5, 'Pastel Skies', 'Mirage Hotel', 'Pastel Skies'),
    _track(6, 'Nebula Garden', 'Orion Fields', 'Nebula Garden'),
  ];
  return Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              HeroBillboard(
                title: 'Neon Skyline',
                subtitle: 'Midnight Avenue · Neon Skyline',
                image: covers[0],
              ),
              MediaRow(
                title: 'Made for you',
                height: 280,
                children: [
                  for (final t in tracks)
                    PosterCard(
                      title: t.title,
                      subtitle: t.artistName,
                      image: covers[tracks.indexOf(t) % covers.length],
                      width: 148,
                    ),
                ],
              ),
              MediaRow(
                title: 'Top charts',
                height: 280,
                children: [
                  for (final t in tracks.reversed)
                    PosterCard(
                      title: t.title,
                      subtitle: t.artistName,
                      image: covers[(tracks.length - 1 - tracks.indexOf(t)) % covers.length],
                      width: 148,
                    ),
                ],
              ),
              MediaRow(
                title: 'Popular albums',
                height: 320,
                children: [
                  for (var i = 0; i < 6; i++)
                    PosterCard(
                      title: tracks[i].albumTitle,
                      subtitle: tracks[i].artistName,
                      image: covers[i % covers.length],
                      width: 168,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      _bottomBar(covers),
    ],
  );
}

Widget _search(List<MemoryImage> covers) {
  final songs = [
    _track(1, 'Neon Skyline', 'Midnight Avenue', 'Neon Skyline'),
    _track(2, 'Neon Nights', 'Static Bloom', 'Neon Nights'),
    _track(3, 'Neon Rain', 'Juno Wave', 'Neon Rain'),
    _track(4, 'Neon Skyline (Remix)', 'Midnight Avenue', 'Neon Skyline'),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'neon',
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Songs'),
              for (final t in songs) TrackRow(track: t, index: songs.indexOf(t), showAlbum: true),
              _sectionTitle('Albums'),
              MediaRow(
                title: 'Albums',
                height: 280,
                children: [
                  for (var i = 0; i < 5; i++)
                    PosterCard(
                      title: _track(i, 'Album ${i + 1}', _artists[i % 6], 'Album ${i + 1}').albumTitle,
                      subtitle: _artists[i % 6],
                      image: covers[i % covers.length],
                      width: 148,
                    ),
                ],
              ),
              _sectionTitle('Artists'),
              MediaRow(
                title: 'Artists',
                height: 260,
                children: [
                  for (var i = 0; i < 4; i++)
                    PosterCard(
                      title: _artists[i],
                      subtitle: 'Artist',
                      image: covers[(i + 3) % covers.length],
                      width: 130,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      _bottomBar(covers),
    ],
  );
}

Widget _album(List<MemoryImage> covers) {
  const titles = [
    'Neon Skyline', 'Electric Horizon', 'Midnight Avenue', 'Cobalt Nights',
    'Laser Bloom', 'Afterglow', 'Glass City', 'Voltage', 'Sunset Circuit',
    'Echo Chamber',
  ];
  final tracks = [
    for (var i = 0; i < titles.length; i++)
      _track(i, titles[i], 'Midnight Avenue', 'Neon Skyline'),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Artwork(image: covers[0], borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(width: 24),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Neon Skyline',
                    style: TextStyle(fontFamily: 'Barlow', fontSize: 40, fontWeight: FontWeight.w900, height: 1.05, color: Colors.white)),
                SizedBox(height: 8),
                Text('Midnight Avenue · 2024 · 10 tracks', style: TextStyle(color: Colors.white70)),
                SizedBox(height: 20),
                Row(
                  children: [
                    _PlayButton(),
                    SizedBox(width: 12),
                    _ShuffleButton(),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              for (var i = 0; i < tracks.length; i++)
                TrackRow(track: tracks[i], index: i, isCurrent: i == 0, showAlbum: false),
            ],
          ),
        ),
      ),
      _bottomBar(covers),
    ],
  );
}

Widget _player(List<MemoryImage> covers) {
  const queue = [
    ('Electric Horizon', 'Midnight Avenue'),
    ('Cobalt Nights', 'Midnight Avenue'),
    ('Laser Bloom', 'Midnight Avenue'),
    ('Afterglow', 'Midnight Avenue'),
    ('Glass City', 'Midnight Avenue'),
  ];
  return Row(
    children: [
      Expanded(
        flex: 5,
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              width: 340,
              height: 340,
              child: Artwork(image: covers[0], borderRadius: BorderRadius.circular(12)),
            ),
            const Spacer(),
            const Text('AUTO-ENHANCED',
                style: TextStyle(fontFamily: 'Barlow', fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: HColors.brandRed)),
            const SizedBox(height: 6),
            const Text('Neon Skyline',
                style: TextStyle(fontFamily: 'Barlow', fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('Midnight Avenue', style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 24),
            SizedBox(
              width: 400,
              child: Column(
                children: [
                  Slider(value: 88, max: 222, onChanged: (_) {}, activeColor: HColors.brandRed),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1:28', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      Text('3:42', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shuffle_rounded, color: Colors.white70),
                SizedBox(width: 28),
                Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
                SizedBox(width: 24),
                Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 56),
                SizedBox(width: 24),
                Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
                SizedBox(width: 28),
                Icon(Icons.repeat_rounded, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      Container(
        width: 360,
        color: HColors.surface.withOpacity(0.5),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Up next',
                style: TextStyle(fontFamily: 'Barlow', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            for (var i = 0; i < queue.length; i++)
              ListTile(
                dense: true,
                leading: Text('${i + 1}', style: const TextStyle(color: Colors.white70)),
                title: Text(queue[i].$1, style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(queue[i].$2, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: HColors.surfaceRaised, borderRadius: BorderRadius.circular(6)),
              child: const Row(
                children: [
                  Text('AUTO', style: TextStyle(fontFamily: 'Barlow', fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: HColors.brandRed)),
                  SizedBox(width: 10),
                  Expanded(child: Text('Smart Shuffle will add similar tracks', style: TextStyle(fontSize: 13, color: Colors.white70))),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _auth() {
  return Center(
    child: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('HIRENA', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Barlow', fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: 2, color: HColors.brandRed)),
          const SizedBox(height: 20),
          const Text(
            'Stream the Deezer catalog with your own ARL — used only as a streaming key. Your profile is never read.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 40),
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Deezer ARL token',
              hintText: 'Paste your 192-character ARL',
              suffixIcon: Icon(Icons.visibility_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {},
            child: const Text('Start listening'),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: HColors.surfaceRaised, borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'How to get your ARL: log in at deezer.com → DevTools (F12) → Application → Cookies → deezer.com → copy the “arl” cookie value.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _settings() {
  return SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Settings', style: TextStyle(fontFamily: 'Barlow', fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 24),
        const Text('Playback', style: TextStyle(fontFamily: 'Barlow', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Streaming quality'),
          trailing: const Text('MP3 320 kbps', style: TextStyle(color: Colors.white70)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Crossfade'),
          subtitle: Slider(value: 120, max: 360, onChanged: (_) {}, activeColor: HColors.brandRed),
          trailing: const Text('4000 ms', style: TextStyle(color: Colors.white70)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Automix'),
          subtitle: const Text('Beat-matched, seamless transitions'),
          value: true,
          onChanged: (_) {},
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Default shuffle'),
          trailing: const Text('Standard', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(height: 16),
        const Text('Account', style: TextStyle(fontFamily: 'Barlow', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.key_rounded),
          title: Text('Deezer ARL: valid'),
          subtitle: Text('Streaming key only — profile data is never read.'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.logout_rounded),
          title: Text('Sign out'),
        ),
      ],
    ),
  );
}

Widget _library() {
  final tracks = [
    _track(1, 'Neon Skyline', 'Midnight Avenue', 'Neon Skyline'),
    _track(2, 'Deep Currents', 'Azure Theory', 'Deep Currents'),
    _track(3, 'Crimson Smoke', 'Velvet Saint', 'Crimson Smoke'),
    _track(4, 'Chrome Dreams', 'Nova Circuit', 'Chrome Dreams'),
    _track(5, 'Pastel Skies', 'Mirage Hotel', 'Pastel Skies'),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(32, 32, 32, 8),
        child: Text('Library', style: TextStyle(fontFamily: 'Barlow', fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, 8),
        child: Text('Your saved tracks', style: TextStyle(fontFamily: 'Barlow', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white70)),
      ),
      Expanded(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              for (var i = 0; i < tracks.length; i++)
                TrackRow(track: tracks[i], index: i, showAlbum: true),
            ],
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------- helpers
Widget _bottomBar(List<MemoryImage> covers) {
  return Container(
    height: 76,
    color: HColors.surface,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        SizedBox(width: 44, height: 44, child: Artwork(image: covers[0], borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Neon Skyline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              Text('Midnight Avenue', style: TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
        ),
        const Icon(Icons.pause_rounded, color: Colors.white),
        const SizedBox(width: 16),
        const Icon(Icons.skip_next_rounded, color: Colors.white),
      ],
    ),
  );
}

Widget _sectionTitle(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(t,
          style: const TextStyle(fontFamily: 'Barlow', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
    );

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Play'),
    );
  }
}

class _ShuffleButton extends StatelessWidget {
  const _ShuffleButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.shuffle_rounded),
      label: const Text('Shuffle'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
      ),
    );
  }
}
