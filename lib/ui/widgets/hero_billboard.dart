import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../deezer/models.dart';
import 'artwork.dart';

/// Cinematic hero billboard: backdrop artwork, left scrim, title lockup, and
/// Play/Shuffle actions.
final class HeroBillboard extends StatelessWidget {
  const HeroBillboard({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverMd5,
    this.image,
    this.onPlay,
    this.onShuffle,
  });

  final String title;
  final String subtitle;
  final String? coverMd5;
  final ImageProvider? image;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final height = (w * 0.42).clamp(360.0, 620.0);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HMotionHelpers.kenBurns(
            key: const ValueKey('hero-art'),
            child: Artwork(
              coverMd5: coverMd5,
              image: image,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            ),
          ),
          // Left scrim
          const DecoratedBox(
            decoration: BoxDecoration(gradient: HColors.heroScrim),
          ),
          // Bottom fade into the canvas
          const DecoratedBox(
            decoration: BoxDecoration(gradient: HColors.bottomScrim),
          ),
          Positioned(
            left: HSpacing.s8,
            bottom: HSpacing.s6,
            right: HSpacing.s6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('HIRENA ORIGINAL', style: HType.eyebrow),
                const SizedBox(height: HSpacing.s2),
                Text(title, style: HType.hero, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: HSpacing.s2),
                Text(subtitle, style: HType.metadata, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: HSpacing.s5),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play'),
                    ),
                    const SizedBox(width: HSpacing.s3),
                    OutlinedButton.icon(
                      onPressed: onShuffle,
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Shuffle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HColors.inkPrimary,
                        side: const BorderSide(color: HColors.hairline),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds a hero for a featured [Track].
Widget heroForTrack(Track t, {VoidCallback? onPlay, VoidCallback? onShuffle}) => HeroBillboard(
      title: t.title,
      subtitle: '${t.artistName} · ${t.albumTitle}',
      coverMd5: t.albumCoverMd5,
      onPlay: onPlay,
      onShuffle: onShuffle,
    );
