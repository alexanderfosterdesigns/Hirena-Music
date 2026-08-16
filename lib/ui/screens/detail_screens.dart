import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../deezer/models.dart';
import '../../recsys/shuffle.dart';
import '../../state/providers.dart';
import '../widgets/artwork.dart';
import '../widgets/media_row.dart';
import '../widgets/poster_card.dart';
import '../widgets/track_row.dart';

// --- Shared track-list page ------------------------------------------------

class _TrackListPage extends ConsumerWidget {
  const _TrackListPage({
    required this.title,
    required this.subtitle,
    required this.tracks,
    this.coverMd5,
    this.artistMd5,
    this.headerChildren = const [],
  });

  final String title;
  final String subtitle;
  final List<Track> tracks;
  final String? coverMd5;
  final String? artistMd5;
  final List<Widget> headerChildren;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.read(appControllerProvider);
    final currentId = ref.watch(playerProvider).current?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Artwork(
                      coverMd5: coverMd5,
                      artistMd5: artistMd5,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Barlow',
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(subtitle, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: tracks.isEmpty ? null : () => app.playTracks(tracks),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: tracks.isEmpty
                                  ? null
                                  : () => app.playTracks(tracks,
                                      shuffleMode: ShuffleMode.trueShuffle),
                              icon: const Icon(Icons.shuffle_rounded),
                              label: const Text('Shuffle'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                              ),
                            ),
                          ],
                        ),
                        if (headerChildren.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ...headerChildren,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (context, i) {
              final t = tracks[i];
              return FutureBuilder<bool>(
                future: app.isSaved(t.id),
                initialData: false,
                builder: (context, snap) => TrackRow(
                  track: t,
                  index: i,
                  showAlbum: true,
                  isCurrent: currentId == t.id,
                  saved: snap.data ?? false,
                  onPlay: () => app.playTracks(tracks, startIndex: i),
                  onToggleSave: () => app.toggleSave(t),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// --- Album -----------------------------------------------------------------

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key, required this.albumId});

  final int albumId;

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  (Album, List<Track>)? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = ref.read(appControllerProvider);
    final r = await app.gateway.album(widget.albumId);
    if (!mounted) return;
    setState(() {
      if (r is Ok<(Album, List<Track>)>) {
        _data = r.value;
      } else {
        _error = (r as Err).error.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    }
    final d = _data;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _TrackListPage(
      title: d.$1.title,
      subtitle: '${d.$1.artistName} · ${d.$1.releaseDate ?? ''} · ${d.$2.length} tracks',
      tracks: d.$2,
      coverMd5: d.$1.coverMd5,
    );
  }
}

// --- Artist ----------------------------------------------------------------

class ArtistScreen extends ConsumerStatefulWidget {
  const ArtistScreen({super.key, required this.artistId});

  final int artistId;

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  (Artist, List<Track>, List<Album>)? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = ref.read(appControllerProvider);
    final r = await app.gateway.artist(widget.artistId);
    if (!mounted) return;
    setState(() {
      if (r is Ok<(Artist, List<Track>, List<Album>)>) {
        _data = r.value;
      } else {
        _error = (r as Err).error.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    }
    final d = _data;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _TrackListPage(
      title: d.$1.name,
      subtitle: 'Top tracks',
      tracks: d.$2,
      artistMd5: d.$1.pictureMd5,
      headerChildren: [
        if (d.$3.isNotEmpty)
          MediaRow(
            title: 'Albums',
            height: 220,
            children: [
              for (final a in d.$3.take(25))
                posterForAlbum(
                  a,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AlbumScreen(albumId: a.id)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// --- Playlist --------------------------------------------------------------

class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  (Playlist, List<Track>)? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = ref.read(appControllerProvider);
    final r = await app.gateway.playlist(widget.playlistId);
    if (!mounted) return;
    setState(() {
      if (r is Ok<(Playlist, List<Track>)>) {
        _data = r.value;
      } else {
        _error = (r as Err).error.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    }
    final d = _data;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _TrackListPage(
      title: d.$1.title,
      subtitle: '${d.$1.creatorName ?? ''} · ${d.$2.length} tracks',
      tracks: d.$2,
      coverMd5: d.$1.pictureMd5,
    );
  }
}
