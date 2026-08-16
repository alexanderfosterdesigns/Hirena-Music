import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../state/providers.dart';
import '../screens/player_screen.dart';
import 'artwork.dart';

/// Compact persistent player bar (bottom).
final class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final current = player.current;
    if (current == null) return const SizedBox.shrink();

    final progress = player.duration.inMilliseconds == 0
        ? 0.0
        : (player.position.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0);

    return Material(
      color: HColors.surface,
      child: InkWell(
        onTap: () => _openPlayer(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress, minHeight: 2, color: HColors.brandRed),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HSpacing.s4, vertical: HSpacing.s2),
              child: Row(
                children: [
                  Artwork(
                    coverMd5: current.track.albumCoverMd5,
                    width: 44,
                    height: 44,
                    borderRadius: BorderRadius.circular(HRadii.chip),
                  ),
                  const SizedBox(width: HSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (current.smart) ...[
                              const Icon(Icons.auto_awesome_rounded,
                                  size: 12, color: HColors.brandRed),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(current.track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HType.cardTitle),
                            ),
                          ],
                        ),
                        Text(current.track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HType.metadata),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: player.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onTap: () => player.togglePlayPause(),
                  ),
                  _IconBtn(icon: Icons.skip_next_rounded, onTap: () => player.next()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const _PlayerScreenHost(),
    ));
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: HColors.inkPrimary),
      onPressed: onTap,
      tooltip: icon == Icons.play_arrow_rounded ? 'Play' : icon == Icons.pause_rounded ? 'Pause' : 'Next',
    );
  }
}

class _PlayerScreenHost extends StatelessWidget {
  const _PlayerScreenHost();

  @override
  Widget build(BuildContext context) => const PlayerScreen();
}
