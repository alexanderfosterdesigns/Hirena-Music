import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/player_controller.dart';
import '../../core/duration_format.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../recsys/shuffle.dart';
import '../../state/providers.dart';
import '../widgets/artwork.dart';
import '../widgets/track_row.dart';

/// Full-screen player: artwork, scrubber, transport, queue, shuffle modes.
final class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.read(appControllerProvider);
    final player = ref.watch(playerProvider);
    final current = player.current;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: HColors.bottomScrim),
        child: SafeArea(
          child: Row(
            children: [
              // Left: artwork + track info
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: current == null
                      ? const Center(child: Text('Nothing playing'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Center(
                              child: Artwork(
                                coverMd5: current.track.albumCoverMd5,
                                width: 380,
                                height: 380,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const Spacer(),
                            if (current.smart)
                              const Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 14, color: HColors.brandRed),
                                  SizedBox(width: 6),
                                  Text('Smart Shuffle', style: HType.eyebrow),
                                ],
                              ),
                            Text(current.track.title, style: HType.screenTitle),
                            const SizedBox(height: 6),
                            Text(current.track.artistName, style: HType.metadata),
                            const SizedBox(height: 24),
                            _Scrubber(player: player),
                            const SizedBox(height: 8),
                            _Transport(player: player, app: app),
                          ],
                        ),
                ),
              ),
              // Right: up next
              Container(
                width: 360,
                color: HColors.surface.withOpacity(0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Up next', style: HType.rowTitle),
                    ),
                    Expanded(child: _QueueList(player: player, app: app)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final dur = player.duration.inMilliseconds;
    final pos = player.position.inMilliseconds;
    return Column(
      children: [
        Slider(
          value: dur == 0 ? 0 : pos.clamp(0, dur).toDouble(),
          max: dur == 0 ? 1 : dur.toDouble(),
          onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatClock(player.position), style: HType.caption),
            Text(formatClock(player.duration), style: HType.caption),
          ],
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.player, required this.app});

  final PlayerController player;
  final dynamic app;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeButton(
          active: player.shuffle != ShuffleMode.sequential,
          icon: _shuffleIcon(player.shuffle),
          tooltip: 'Shuffle',
          onTap: _cycleShuffle,
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous_rounded, color: HColors.inkPrimary),
          onPressed: player.previous,
        ),
        IconButton(
          iconSize: 56,
          icon: Icon(
            player.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            color: HColors.inkPrimary,
          ),
          onPressed: player.togglePlayPause,
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next_rounded, color: HColors.inkPrimary),
          onPressed: player.next,
        ),
        _ModeButton(
          active: player.repeat != RepeatMode.off,
          icon: player.repeat == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          tooltip: 'Repeat',
          onTap: _cycleRepeat,
        ),
      ],
    );
  }

  IconData _shuffleIcon(ShuffleMode m) => m == ShuffleMode.smart
      ? Icons.auto_awesome_rounded
      : Icons.shuffle_rounded;

  void _cycleShuffle() {
    final next = switch (player.shuffle) {
      ShuffleMode.sequential => ShuffleMode.trueShuffle,
      ShuffleMode.trueShuffle => ShuffleMode.standard,
      ShuffleMode.standard => ShuffleMode.sequential,
      ShuffleMode.smart => ShuffleMode.sequential,
    };
    player.setShuffle(next);
  }

  void _cycleRepeat() {
    final next = switch (player.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    player.setRepeat(next);
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.active,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: active ? HColors.brandRed : HColors.inkSecondary),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList({required this.player, required this.app});

  final PlayerController player;
  final dynamic app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = player.pool;
    if (order.isEmpty) {
      return const Center(child: Text('Queue is empty', style: TextStyle(color: Colors.white54)));
    }
    // Show the base pool in play order.
    return ListView.builder(
      itemCount: order.length,
      itemBuilder: (context, i) {
        final item = order[i];
        return TrackRow(
          track: item.track,
          isCurrent: player.current?.id == item.id,
          onPlay: () => app.playTracks(order.map((e) => e.track).toList(), startIndex: i),
        );
      },
    );
  }
}
