import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:mobx/mobx.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:mucke/presentation/widgets/album_art_grid.dart';
import 'package:mucke/presentation/widgets/album_art_list.dart';

import '../../domain/entities/album.dart';
import '../state/music_data_store.dart';
import '../state/navigation_store.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({Key? key}) : super(key: key);

  @override
  _AlbumsPageState createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController scrollController = ScrollController();
  final Observable<bool> showAlbumGrid = Observable(false);
  final Observable<String> sortingMode = Observable('name');

  @override
  Widget build(BuildContext context) {
    print('AlbumsPage.build');
    final MusicDataStore store = GetIt.I<MusicDataStore>();
    final NavigationStore navStore = GetIt.I<NavigationStore>();

    super.build(context);
    return Observer(builder: (_) {
      print('AlbumsPage.build -> Observer.builder');
      final List<Album> albums = store.albumStream.value ?? [];
      switch (sortingMode.value) {
        case 'name':
          break;
        case 'artistName':
          albums.sort((a,b) => a.artist.compareTo(b.artist));
          break;
        case 'random':
          albums.shuffle(Random());
          break;
      }
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            leading: IconButton(
              onPressed: () {
                showAlbumGrid.toggle();
              },
              icon: Icon(showAlbumGrid.value ? Icons.list : Icons.grid_view),
            ),
            actions: [
              DropdownButton(
                value: sortingMode.value,
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('name')),
                  DropdownMenuItem(value: 'artistName', child: Text('artistName')),
                  DropdownMenuItem(value: 'random', child: Text('random')),
                ],
                onChanged: (selectedValue) {
                  if (selectedValue != null)
                    mobx.Action(() {
                      sortingMode.value = selectedValue;
                    })();
                },
              )
            ],
          ),
          if (showAlbumGrid.value)
            AlbumArtGrid(
                albums: albums,
                scrollController: scrollController,
                navStore: navStore)
          else
            AlbumArtList(
                albums: albums,
                scrollController: scrollController,
                navStore: navStore),
        ],
      );
    });
  }

  @override
  bool get wantKeepAlive => true;
}
