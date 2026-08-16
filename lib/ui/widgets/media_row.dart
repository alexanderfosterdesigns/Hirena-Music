import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';

/// A titled horizontal carousel of cards.
final class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.children,
    this.height = 240,
    this.onViewAll,
  });

  final String title;
  final List<Widget> children;
  final double height;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              HSpacing.s5, HSpacing.s3, HSpacing.s5, HSpacing.s3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(title, style: HType.rowTitle, overflow: TextOverflow.ellipsis),
              ),
              if (onViewAll != null) ...[
                const SizedBox(width: HSpacing.s4),
                TextButton(onPressed: onViewAll, child: const Text('See all')),
              ],
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: HSpacing.s5),
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(width: HSpacing.s3),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}
