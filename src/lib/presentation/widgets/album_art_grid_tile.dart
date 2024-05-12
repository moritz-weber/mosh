import 'package:flutter/material.dart';

import '../theming.dart';
import '../utils.dart' as utils;

class AlbumArtGridTile extends StatelessWidget {
  const AlbumArtGridTile({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.albumArtPath,
    this.highlight = false,
  }) : super(key: key);

  final String title;
  final String subtitle;
  final String? albumArtPath;
  final Function onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
        child: Column(
          children: [
            SizedBox(
              width: 128,
              height: 128,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image(
                  image: utils.getAlbumImage(albumArtPath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 3, horizontal: 0)),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TEXT_SMALL_SUBTITLE.copyWith(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          ],
        ),
      ),
    );
  }
}
