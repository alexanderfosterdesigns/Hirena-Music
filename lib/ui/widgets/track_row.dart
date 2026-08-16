import 'package:flutter/material.dart';

import '../../core/duration_format.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../deezer/models.dart';
import 'artwork.dart';

/// A single row in a track list (album/playlist/search), with hover actions.
final class TrackRow extends StatefulWidget {
  const TrackRow({
    super.key,
    required this.track,
    this.index,
    this.showAlbum = false,
    this.isCurrent = false,
    this.saved = false,
    this.onPlay,
    this.onToggleSave,
    this.onOpenAlbum,
  });

  final Track track;
  final int? index;
  final bool showAlbum;
  final bool isCurrent;
  final bool saved;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleSave;
  final VoidCallback? onOpenAlbum;

  @override
  State<TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<TrackRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isCurrent ? HColors.brandRed : HColors.inkPrimary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hovered ? HColors.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(HRadii.chip),
        ),
        child: ListTile(
          dense: true,
          leading: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_hovered && widget.index != null)
                  IconButton(
                    icon: Icon(
                      widget.isCurrent ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                      color: color,
                    ),
                    onPressed: widget.onPlay,
                  )
                else if (widget.index != null)
                  Center(
                    child: Text('${widget.index! + 1}',
                        style: HType.metadata),
                  )
                else
                  Artwork(coverMd5: widget.track.albumCoverMd5,
                      borderRadius: BorderRadius.circular(HRadii.chip)),
              ],
            ),
          ),
          title: Text(
            widget.track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HType.body.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 14,
            ),
          ),
          subtitle: widget.showAlbum
              ? Text(
                  '${widget.track.artistName} · ${widget.track.albumTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HType.metadata,
                )
              : Text(widget.track.artistName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: HType.metadata),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hovered)
                IconButton(
                  icon: Icon(
                    widget.saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: widget.saved ? HColors.brandRed : HColors.inkSecondary,
                    size: 20,
                  ),
                  onPressed: widget.onToggleSave,
                ),
              Text(formatDuration(Duration(seconds: widget.track.duration)),
                  style: HType.metadata),
            ],
          ),
          onTap: widget.onPlay,
        ),
      ),
    );
  }
}
