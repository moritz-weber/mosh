import 'package:rxdart/rxdart.dart';

import '../entities/album.dart';
import '../entities/artist.dart';
import '../entities/custom_list.dart';
import '../entities/enums.dart';
import '../entities/home_widgets/playlists.dart';
import '../entities/playlist.dart';
import '../entities/shuffle_mode.dart';
import '../entities/smart_list.dart';
import '../entities/song.dart';

abstract class MusicDataInfoRepository {
  Stream<Map<String, Song>> get songUpdateStream;
  Stream<List<String>> get songRemovalStream;

  Future<Song> getSongByPath(String path);
  Stream<Song> getSongStream(String path);
  Stream<List<Song>> get songsStream;
  Stream<List<Song>> getAlbumSongStream(Album album);
  Stream<List<Song>> getArtistSongStream(Artist artist);
  Stream<List<Song>> getArtistHighlightedSongStream(Artist artist);
  Stream<List<Song>> getPlaylistSongStream(Playlist playlist);
  Stream<List<Song>> getSmartListSongStream(SmartList smartList);
  Future<List<Song>> getPredecessors(Song song);
  Future<List<Song>> getSuccessors(Song song);

  Stream<List<Playlist>> get playlistsStream;
  Stream<Playlist> getPlaylistStream(int playlistId);

  Stream<List<SmartList>> get smartListsStream;
  Stream<SmartList> getSmartListStream(int smartListId);

  Stream<List<CustomList>> getCustomListsStream({
    HomePlaylistsOrder orderCriterion = HomePlaylistsOrder.name,
    OrderDirection orderDirection = OrderDirection.ascending,
    HomePlaylistsFilter filter = HomePlaylistsFilter.both,
    int? limit,
  });

  Stream<List<Album>> get albumStream;
  Stream<List<Album>> getArtistAlbumStream(Artist artist);
  Future<int?> getAlbumId(String title, String artist, int? year);

  Stream<List<Artist>> get artistStream;

  ValueStream<Album?> get albumOfDayStream;
  ValueStream<Artist?> get artistOfDayStream;

  Future<List<Artist>> searchArtists(String searchText, {int? limit});
  Future<List<Album>> searchAlbums(String searchText, {int? limit});
  Future<List<Song>> searchSongs(String searchText, {int? limit});
  Future<List<SmartList>> searchSmartLists(String searchText, {int? limit});
  Future<List<Playlist>> searchPlaylists(String searchText, {int? limit});

  ValueStream<Set<String>> get blockedFilesStream;
}

abstract class MusicDataRepository extends MusicDataInfoRepository {
  Future<void> updateDatabase();

  Future<void> setSongsBlockLevel(List<Song> songs, int blockLevel);

  Future<void> setLikeCount(List<Song> songs, int count);
  Future<void> incrementLikeCount(Song song);

  Future<Song> incrementPlayCount(Song song);

  Future<Song> togglePreviousSongLink(Song song);
  Future<Song> toggleNextSongLink(Song song);

  Future<void> insertPlaylist(
    String name,
    String iconString,
    String gradientString,
    ShuffleMode? shuffleMode,
  );
  Future<void> updatePlaylist(Playlist playlist);
  Future<void> removePlaylist(Playlist playlist);
  Future<void> addSongsToPlaylist(Playlist playlist, List<Song> songs);
  Future<void> removePlaylistEntry(int playlistId, int index);
  Future<void> movePlaylistEntry(int playlistId, int oldIndex, int newIndex);

  Future<void> insertSmartList({
    required String name,
    required Filter filter,
    required OrderBy orderBy,
    required String iconString,
    required String gradientString,
    ShuffleMode? shuffleMode,
  });
  Future<void> updateSmartList(SmartList smartList);
  Future<void> removeSmartList(SmartList smartList);

  Future<void> addBlockedFiles(List<String> paths);
  Future<void> removeBlockedFiles(List<String> paths);
}
