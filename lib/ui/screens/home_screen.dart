import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../deezer/models.dart';
import '../../recsys/shuffle.dart';
import '../../state/providers.dart';
import '../widgets/hero_billboard.dart';
import '../widgets/media_row.dart';
import '../widgets/poster_card.dart';
import 'detail_screens.dart';

/// Home: hero billboard + personalized/chart rows.
final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = ref.read(appControllerProvider);
    try {
      final charts = await app.gateway.charts();
      var forYou = <Track>[];
      try {
        final rec = app.rec;
        final seeds = rec.profile.recentTracks.take(10).toList();
        if (seeds.isNotEmpty) {
          forYou = await rec.recommendations(seedTrackIds: seeds, limit: 24);
        }
      } catch (_) {/* cold start — skip */}
      if (!mounted) return;
      final c = charts.isOk ? (charts as Ok<Charts>).value : const Charts();
      setState(() {
        _data = _HomeData(
          hero: c.tracks.isNotEmpty ? c.tracks.first : null,
          charts: c,
          forYou: forYou,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _data == null) {
      return _Retry(message: _error, onRetry: _load);
    }
    final d = _data!;
    final app = ref.watch(appControllerProvider);

    return CustomScrollView(
      slivers: [
        if (d.hero != null)
          SliverToBoxAdapter(
            child: heroForTrack(
              d.hero!,
              onPlay: () => app.playTrack(d.hero!),
              onShuffle: () => app.playTracks(d.charts.tracks, shuffleMode: ShuffleMode.trueShuffle),
            ),
          ),
        SliverList.list(
          children: [
            const SizedBox(height: 8),
            if (d.forYou.isNotEmpty)
              MediaRow(
                title: 'Made for you',
                children: [
                  for (final t in d.forYou)
                    PosterCard(
                      title: t.title,
                      subtitle: t.artistName,
                      coverMd5: t.albumCoverMd5,
                      onTap: () => _openAlbum(context, t.albumId),
                      onPlay: () => app.playTrack(t),
                    ),
                ],
              ),
            if (d.charts.tracks.isNotEmpty)
              MediaRow(
                title: 'Top charts',
                children: [
                  for (final t in d.charts.tracks.take(30))
                    PosterCard(
                      title: t.title,
                      subtitle: t.artistName,
                      coverMd5: t.albumCoverMd5,
                      onTap: () => _openAlbum(context, t.albumId),
                      onPlay: () => app.playTrack(t),
                    ),
                ],
              ),
            if (d.charts.albums.isNotEmpty)
              MediaRow(
                title: 'Popular albums',
                height: 260,
                children: [
                  for (final a in d.charts.albums.take(30))
                    posterForAlbum(a, onTap: () => _openAlbum(context, a.id)),
                ],
              ),
            if (d.charts.artists.isNotEmpty)
              MediaRow(
                title: 'Popular artists',
                height: 230,
                children: [
                  for (final a in d.charts.artists.take(30))
                    posterForArtist(a, onTap: () => _openArtist(context, a.id)),
                ],
              ),
            const SizedBox(height: 120),
          ],
        ),
      ],
    );
  }

  void _openAlbum(BuildContext context, int id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumScreen(albumId: id)));
  }

  void _openArtist(BuildContext context, int id) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistScreen(artistId: id)));
  }
}

class _HomeData {
  const _HomeData({required this.hero, required this.charts, required this.forYou});

  final Track? hero;
  final Charts charts;
  final List<Track> forYou;
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message ?? 'Could not load', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
