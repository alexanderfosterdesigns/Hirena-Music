import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../deezer/art.dart';

/// Size-matched, cached artwork (cover or artist) with a neutral placeholder.
final class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    this.coverMd5,
    this.artistMd5,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.image,
  });

  final String? coverMd5;
  final String? artistMd5;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// When provided, renders this image instead of the network artwork.
  /// Used by tests/screenshot harnesses to stay offline & deterministic.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = width ?? height ?? 500;
    final url = artistMd5 != null
        ? Art.artist(artistMd5!, size: Art.sizeFor(size, dpr))
        : Art.cover(coverMd5 ?? '', size: Art.sizeFor(size, dpr));

    Widget child;
    if (image != null) {
      child = Image(image: image, fit: fit, width: width, height: height);
    } else if ((coverMd5 == null || coverMd5!.isEmpty) &&
        (artistMd5 == null || artistMd5!.isEmpty)) {
      child = const _Placeholder();
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => const _Placeholder(),
        errorWidget: (_, __, ___) => const _Placeholder(),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(HRadii.card),
      child: child,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HColors.surfaceRaised,
      alignment: Alignment.center,
      child: const Icon(Icons.music_note, color: HColors.inkDisabled, size: 28),
    );
  }
}
