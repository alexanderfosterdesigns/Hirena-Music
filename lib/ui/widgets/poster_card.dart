import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../deezer/models.dart';
import 'artwork.dart';

/// A hoverable poster card (album/artist) with title + subtitle.
final class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverMd5,
    this.artistMd5,
    this.onTap,
    this.onPlay,
    this.width = 168,
    this.aspect = HAspect.poster,
  });

  final String title;
  final String subtitle;
  final String? coverMd5;
  final String? artistMd5;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final double width;
  final double aspect;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final height = widget.width * widget.aspect;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _hovered ? HMotion.cardHoverScale : 1.0,
                duration: HMotion.fast,
                curve: HMotion.ease,
                child: Stack(
                  children: [
                    Artwork(
                      coverMd5: widget.coverMd5,
                      artistMd5: widget.artistMd5,
                      width: widget.width,
                      height: height,
                    ),
                    if (widget.onPlay != null && _hovered)
                      Positioned(
                        right: HSpacing.s2,
                        bottom: HSpacing.s2,
                        child: _PlayButton(onTap: widget.onPlay!),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: HSpacing.s2),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HType.cardTitle,
              ),
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HType.metadata,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HColors.brandRed,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.play_arrow_rounded, color: HColors.inkPrimary, size: 22),
        ),
      ),
    );
  }
}

/// A landscape card (16:9) used for editorial/chart rows.
final class LandscapeCard extends StatelessWidget {
  const LandscapeCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverMd5,
    this.onTap,
    this.width = 280,
  });

  final String title;
  final String subtitle;
  final String? coverMd5;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: widget.width,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(HRadii.card),
              child: Artwork(
                coverMd5: widget.coverMd5,
                width: widget.width,
                height: widget.width / HAspect.landscape,
              ),
            ),
            Positioned(
              left: HSpacing.s3,
              right: HSpacing.s3,
              bottom: HSpacing.s3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HType.cardTitle),
                  Text(widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HType.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Converts an [Album] or [Artist] into a poster card.
Widget posterForAlbum(Album a, {VoidCallback? onTap, VoidCallback? onPlay, double width = 168}) =>
    PosterCard(
      title: a.title,
      subtitle: a.artistName,
      coverMd5: a.coverMd5,
      onTap: onTap,
      onPlay: onPlay,
      width: width,
    );

Widget posterForArtist(Artist a, {VoidCallback? onTap, double width = 168}) => PosterCard(
      title: a.name,
      subtitle: 'Artist',
      artistMd5: a.pictureMd5,
      onTap: onTap,
      width: width,
    );
