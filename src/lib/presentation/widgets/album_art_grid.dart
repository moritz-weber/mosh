import 'package:flutter/material.dart';
import 'package:mucke/presentation/pages/album_details_page.dart';
import 'package:mucke/presentation/state/navigation_store.dart';
import 'package:mucke/presentation/widgets/album_art_grid_tile.dart';

import '../../domain/entities/album.dart';

class AlbumArtGrid extends StatelessWidget {
  const AlbumArtGrid({
    Key? key,
    required this.albums,
    required this.scrollController,
    required this.navStore,
  }) : super(key: key);

  final List<Album> albums;
  final ScrollController scrollController;
  final NavigationStore navStore;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      itemCount: albums.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemBuilder: (_, int index) {
        final Album album = albums[index];
        return AlbumArtGridTile(
            title: album.title,
            subtitle: album.artist,
            albumArtPath: album.albumArtPath,
            onTap: () {
              navStore.push(
                context,
                MaterialPageRoute<Widget>(
                  builder: (BuildContext context) => AlbumDetailsPage(
                    album: album,
                  ),
                ),
              );
            });
      },
    );
  }
}
