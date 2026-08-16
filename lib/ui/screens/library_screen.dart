import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../deezer/models.dart';
import '../../state/providers.dart';
import '../widgets/track_row.dart';

/// Local library: tracks the user saved *inside Hirena* (never Deezer
/// favorites via the ARL).
final class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<Track> _tracks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = ref.read(appControllerProvider);
    final rows = await app.db.savedTracks();
    final tracks = rows.map((r) => Track.fromSaved(r)).toList();
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final currentId = app.player.current?.id;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tracks.isEmpty) {
      return const Center(
        child: Text('Your saved tracks will appear here.',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 120),
      itemCount: _tracks.length,
      itemBuilder: (context, i) {
        final t = _tracks[i];
        return TrackRow(
          track: t,
          index: i,
          showAlbum: true,
          isCurrent: currentId == t.id,
          saved: true,
          onPlay: () => app.playTracks(_tracks, startIndex: i),
          onToggleSave: () async {
            await app.toggleSave(t);
            _load();
          },
        );
      },
    );
  }
}
