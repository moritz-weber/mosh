import 'package:flutter/material.dart';
import 'package:mucke/presentation/state/navigation_store.dart';

import '../../domain/entities/album.dart';
import 'album_art_list_tile.dart';

class AlbumArtList extends StatelessWidget {
  const AlbumArtList({
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
    return SliverList.separated(
      itemCount: albums.length,
      itemBuilder: (_, int index) {
        final Album album = albums[index];
        return AlbumArtListTile(
          title: album.title,
          subtitle: album.artist,
          albumArtPath: album.albumArtPath,
          onTap: () {},
        );
      },
      separatorBuilder: (BuildContext context, int index) => const SizedBox(
        height: 4.0,
      ),
    );
  }
}
