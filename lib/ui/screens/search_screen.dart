import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../deezer/models.dart';
import '../../state/providers.dart';
import '../widgets/media_row.dart';
import '../widgets/poster_card.dart';
import '../widgets/track_row.dart';
import 'detail_screens.dart';

/// Unified search across tracks, albums, artists and playlists.
final class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  SearchResults? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final app = ref.read(appControllerProvider);
    final r = await app.gateway.search(q.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r is Ok<SearchResults>) {
        _results = r.value;
      } else {
        _error = (r as Err).error.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final currentId = app.player.current?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Songs, albums, artists, playlists…',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
                  : _results == null
                      ? const _EmptyHint()
                      : _buildResults(context, app, currentId),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, dynamic app, int? currentId) {
    final r = _results!;
    if (r.tracks.isEmpty && r.albums.isEmpty && r.artists.isEmpty && r.playlists.isEmpty) {
      return const Center(child: Text('No results', style: TextStyle(color: Colors.white70)));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (r.tracks.isNotEmpty) ...[
          _sectionTitle('Songs'),
          for (final t in r.tracks)
            TrackRow(
              track: t,
              showAlbum: true,
              isCurrent: currentId == t.id,
              onPlay: () => app.playTracks(r.tracks, startIndex: r.tracks.indexOf(t)),
            ),
        ],
        if (r.albums.isNotEmpty) ...[
          _sectionTitle('Albums'),
          MediaRow(
            title: 'Albums',
            height: 220,
            children: [
              for (final a in r.albums)
                posterForAlbum(
                  a,
                  onTap: () => _open(context, AlbumScreen(albumId: a.id)),
                ),
            ],
          ),
        ],
        if (r.artists.isNotEmpty) ...[
          _sectionTitle('Artists'),
          MediaRow(
            title: 'Artists',
            height: 200,
            children: [
              for (final a in r.artists)
                posterForArtist(
                  a,
                  onTap: () => _open(context, ArtistScreen(artistId: a.id)),
                ),
            ],
          ),
        ],
        if (r.playlists.isNotEmpty) ...[
          _sectionTitle('Playlists'),
          MediaRow(
            title: 'Playlists',
            height: 200,
            children: [
              for (final p in r.playlists)
                PosterCard(
                  title: p.title,
                  subtitle: p.creatorName ?? 'Playlist',
                  coverMd5: p.pictureMd5,
                  onTap: () => _open(context, PlaylistScreen(playlistId: p.id)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Text(t,
            style: const TextStyle(
                fontFamily: 'Barlow', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      );

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Search the Deezer catalog', style: TextStyle(color: Colors.white.withOpacity(0.5))),
    );
  }
}
