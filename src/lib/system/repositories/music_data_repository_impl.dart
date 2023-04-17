import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fimber/fimber.dart';
import 'package:rxdart/rxdart.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../constants.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/custom_list.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/home_widgets/playlists.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/shuffle_mode.dart';
import '../../domain/entities/smart_list.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_data_repository.dart';
import '../datasources/local_music_fetcher.dart';
import '../datasources/music_data_source_contract.dart';
import '../datasources/playlist_data_source.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/playlist_model.dart';
import '../models/smart_list_model.dart';
import '../models/song_model.dart';

class MusicDataRepositoryImpl implements MusicDataRepository {
  MusicDataRepositoryImpl(
    this._localMusicFetcher,
    this._musicDataSource,
    this._playlistDataSource,
  ) {
    _musicDataSource.songStream.listen((event) => _songSubject.add(event));
    _getAlbumOfDay().then((value) => _albumOfDaySubject.add(value));
    _getArtistOfDay().then((value) => _artistOfDaySubject.add(value));
    _minuteStream.listen((_) => _updateHighlightStreams());
    _musicDataSource.blockedFilesStream.listen(_blockedFilesSubject.add);
  }

  final LocalMusicFetcher _localMusicFetcher;
  final MusicDataSource _musicDataSource;
  final PlaylistDataSource _playlistDataSource;

  final BehaviorSubject<Map<String, Song>> _songUpdateSubject = BehaviorSubject();
  final BehaviorSubject<List<String>> _songRemovalSubject = BehaviorSubject();
  final BehaviorSubject<List<Song>> _songSubject = BehaviorSubject();
  final Stream _minuteStream = Stream.periodic(const Duration(minutes: 1));
  final BehaviorSubject<Album?> _albumOfDaySubject = BehaviorSubject();
  final BehaviorSubject<Artist?> _artistOfDaySubject = BehaviorSubject();
  final BehaviorSubject<Set<String>> _blockedFilesSubject = BehaviorSubject();

  static final _log = FimberLog('MusicDataRepositoryImpl');

  @override
  Stream<Map<String, Song>> get songUpdateStream => _songUpdateSubject.stream;

  @override
  ValueStream<Album?> get albumOfDayStream => _albumOfDaySubject.stream;

  @override
  ValueStream<Artist?> get artistOfDayStream => _artistOfDaySubject.stream;

  @override
  Future<Song> getSongByPath(String path) async {
    // this method is only called from upper layers
    // they should have no reason to access paths that are not in the database
    return (await _musicDataSource.getSongByPath(path))!;
  }

  @override
  Stream<List<Song>> get songsStream => _songSubject.stream;

  @override
  Stream<List<Album>> get albumStream => _musicDataSource.albumStream;

  @override
  Stream<List<Artist>> get artistStream => _musicDataSource.artistStream;

  @override
  ValueStream<Set<String>> get blockedFilesStream => _blockedFilesSubject.stream;

  @override
  Stream<List<String>> get songRemovalStream => _songRemovalSubject.stream;

  @override
  Stream<List<Song>> getAlbumSongStream(Album album) => _musicDataSource
      .getAlbumSongStream(album as AlbumModel)
      .map((songs) => _sortAlbumSongs(songs));

  @override
  Stream<List<Song>> getArtistSongStream(Artist artist) =>
      _musicDataSource.getArtistSongStream(artist as ArtistModel);

  @override
  Stream<List<Song>> getArtistHighlightedSongStream(Artist artist) {
    return _musicDataSource
        .getArtistSongStream(artist as ArtistModel)
        .map((event) => _sortHighlightedSongs(event));
  }

  @override
  Stream<List<Album>> getArtistAlbumStream(Artist artist) => _musicDataSource
      .getArtistAlbumStream(artist as ArtistModel)
      .map((albums) => _sortArtistAlbums(albums));

  @override
  Stream<List<Song>> getPlaylistSongStream(Playlist playlist) =>
      _playlistDataSource.getPlaylistSongStream(playlist as PlaylistModel);

  @override
  Stream<List<Song>> getSmartListSongStream(SmartList smartList) =>
      _playlistDataSource.getSmartListSongStream(smartList as SmartListModel);

  @override
  Future<void> updateDatabase() async {
    _log.d('updateDatabase called');

    final localMusic = await _localMusicFetcher.getLocalMusic();

    final artists = localMusic['ARTISTS'] as List<ArtistModel>;
    final albums = localMusic['ALBUMS'] as List<AlbumModel>;
    final songs = localMusic['SONGS'] as List<SongModel>;

    _log.d('Artists found: ${artists.length}');
    _log.d('Albums found: ${albums.length}');
    _log.d('Songs found: ${songs.length}');

    await _updateArtists(artists);
    await _updateAlbums(albums);
    await _musicDataSource.insertSongs(songs);

    await _musicDataSource.cleanupDatabase();

    _log.d('updateDatabase finished');

    _updateHighlightStreams();
  }

  Future<void> _updateArtists(List<ArtistModel> artists) async {
    await _musicDataSource.deleteAllArtists();
    await _musicDataSource.insertArtists(artists);
  }

  Future<void> _updateAlbums(List<AlbumModel> albums) async {
    await _musicDataSource.deleteAllAlbums();
    await _musicDataSource.insertAlbums(albums);
  }

  @override
  Future<void> setSongsBlockLevel(List<Song> songs, int blockLevel) async {
    final changedSongs = songs.where((e) => e.blockLevel != blockLevel);
    final newSongs =
        changedSongs.map((e) => (e as SongModel).copyWith(blockLevel: blockLevel)).toList();
    _songUpdateSubject.add({for (var s in newSongs) s.path: s});
    await _musicDataSource.updateSongs(newSongs);
  }

  @override
  Future<Song> incrementPlayCount(Song song) async {
    final newSong = (song as SongModel).copyWith(playCount: song.playCount + 1);
    _songUpdateSubject.add({song.path: newSong});
    await _musicDataSource.updateSongs([newSong]);
    return newSong;
  }

  @override
  Future<void> setLikeCount(List<Song> songs, int count) async {
    if (0 <= count && count <= MAX_LIKE_COUNT) {
      final changedSongs = songs.where((e) => e.likeCount != count);
      final newSongs =
          changedSongs.map((e) => (e as SongModel).copyWith(likeCount: count)).toList();

      _songUpdateSubject.add({for (var s in newSongs) s.path: s});
      await _musicDataSource.updateSongs(newSongs);
    }
  }

  @override
  Future<void> incrementLikeCount(Song song) async {
    final count = song.likeCount < MAX_LIKE_COUNT ? song.likeCount + 1 : 0;
    await setLikeCount([song], count);
  }

  @override
  Future<Song> toggleNextSongLink(Song song) async {
    SongModel newSong;
    if (!song.next) {
      final successor = await _musicDataSource.getSuccessor(song as SongModel);
      newSong = song.copyWith(next: successor != null);
    } else {
      newSong = (song as SongModel).copyWith(next: false);
    }
    _songUpdateSubject.add({song.path: newSong});
    await _musicDataSource.updateSongs([newSong]);
    return newSong;
  }

  @override
  Future<Song> togglePreviousSongLink(Song song) async {
    SongModel newSong;
    if (!song.previous) {
      final predecessor = await _musicDataSource.getPredecessor(song as SongModel);
      newSong = song.copyWith(previous: predecessor != null);
    } else {
      newSong = (song as SongModel).copyWith(previous: false);
    }
    _songUpdateSubject.add({song.path: newSong});
    await _musicDataSource.updateSongs([newSong]);
    return newSong;
  }

  @override
  Future<List<Song>> getPredecessors(Song song) async {
    final List<Song> songs = [];
    Song? currentSong = song;

    while (currentSong!.previous) {
      currentSong = await _musicDataSource.getPredecessor(currentSong as SongModel);
      if (currentSong == null) break;
      songs.add(currentSong);
    }

    return songs.reversed.toList();
  }

  @override
  Future<List<Song>> getSuccessors(Song song) async {
    final List<Song> songs = [];
    Song? currentSong = song;

    while (currentSong!.next) {
      currentSong = await _musicDataSource.getSuccessor(currentSong as SongModel);
      if (currentSong == null) break;
      songs.add(currentSong);
    }

    return songs.toList();
  }

  List<Song> _sortHighlightedSongs(List<Song> songs) {
    return songs
      ..sort(
        (a, b) {
          int r = -a.likeCount.compareTo(b.likeCount);
          if (r == 0) r = -a.playCount.compareTo(b.playCount);
          if (r == 0) r = a.title.compareTo(b.title);
          return r;
        },
      );
  }

  List<Song> _sortAlbumSongs(List<Song> songs) {
    return songs
      ..sort((a, b) {
        if (a.discNumber != b.discNumber) return a.discNumber.compareTo(b.discNumber);
        if (a.trackNumber != b.trackNumber) return a.trackNumber.compareTo(b.trackNumber);
        return compareNatural(a.title, b.title);
      });
  }

  List<Album> _sortArtistAlbums(List<Album> albums) {
    return albums
      ..sort((a, b) {
        if (b.pubYear == null) return -1;
        if (a.pubYear == null) return 1;

        return -a.pubYear!.compareTo(b.pubYear!);
      });
  }

  @override
  Future<List<Album>> searchAlbums(String searchText, {int? limit}) async {
    if (searchText == '') return [];

    final searchTextLower = searchText.toLowerCase();

    // TODO: need to clean the string? sql injection?
    final dbResult = await _musicDataSource.searchAlbums(_fuzzy(searchTextLower));

    dbResult.sort((a, b) => -_similarity(a.title.toLowerCase(), searchTextLower)
        .compareTo(_similarity(b.title.toLowerCase(), searchTextLower)));

    if (limit != null) return dbResult.take(limit).toList();
    return dbResult;
  }

  @override
  Future<List<Artist>> searchArtists(String searchText, {int? limit}) async {
    if (searchText == '') return [];

    final searchTextLower = searchText.toLowerCase();

    // TODO: need to clean the string? sql injection?
    final dbResult = await _musicDataSource.searchArtists(_fuzzy(searchTextLower));

    dbResult.sort((a, b) => -_similarity(a.name.toLowerCase(), searchTextLower)
        .compareTo(_similarity(b.name.toLowerCase(), searchTextLower)));

    if (limit != null) return dbResult.take(limit).toList();
    return dbResult;
  }

  @override
  Future<List<Song>> searchSongs(String searchText, {int? limit}) async {
    if (searchText == '') return [];

    final searchTextLower = searchText.toLowerCase();

    // TODO: need to clean the string? sql injection?
    final dbResult = await _musicDataSource.searchSongs(_fuzzy(searchTextLower));

    dbResult.sort((a, b) => -_similarity(a.title.toLowerCase(), searchTextLower)
        .compareTo(_similarity(b.title.toLowerCase(), searchTextLower)));

    if (limit != null) return dbResult.take(limit).toList();
    return dbResult;
  }

  @override
  Future<List<Playlist>> searchPlaylists(String searchText, {int? limit}) async {
    if (searchText == '') return [];

    final searchTextLower = searchText.toLowerCase();

    // TODO: need to clean the string? sql injection?
    final dbResult = await _playlistDataSource.searchPlaylists(_fuzzy(searchTextLower));

    dbResult.sort((a, b) => -_similarity(a.name.toLowerCase(), searchTextLower)
        .compareTo(_similarity(b.name.toLowerCase(), searchTextLower)));

    if (limit != null) return dbResult.take(limit).toList();
    return dbResult;
  }

  @override
  Future<List<SmartList>> searchSmartLists(String searchText, {int? limit}) async {
    if (searchText == '') return [];

    final searchTextLower = searchText.toLowerCase();

    // TODO: need to clean the string? sql injection?
    final dbResult = await _playlistDataSource.searchSmartLists(_fuzzy(searchTextLower));

    dbResult.sort((a, b) => -_similarity(a.name.toLowerCase(), searchTextLower)
        .compareTo(_similarity(b.name.toLowerCase(), searchTextLower)));

    if (limit != null) return dbResult.take(limit).toList();
    return dbResult;
  }

  double _similarity(String value, String searchText) {
    return value.startsWith(searchText)
        ? value.similarityTo(searchText) + 1
        : value.similarityTo(searchText);
  }

  String _fuzzy(String text) {
    final String fuzzyText = text
        .replaceAll(RegExp(r'[aáàäâã]'), '[aáàäâã]')
        .replaceAll(RegExp(r'[eéèëê]'), '[eéèëê]')
        .replaceAll(RegExp(r'[iíìî]'), '[iíìî]')
        .replaceAll(RegExp(r'[oóòöôõ]'), '[oóòöôõ]')
        .replaceAll(RegExp(r'[uúùüû]'), '[uúùüû]')
        .replaceAll('.', '\\.')
        .replaceAll('?', '\\?');
    return '.*$fuzzyText.*';
  }

  @override
  Future<void> addSongsToPlaylist(Playlist playlist, List<Song> songs) async {
    _playlistDataSource.addSongsToPlaylist(
        playlist as PlaylistModel, songs.map((e) => e as SongModel).toList());
  }

  @override
  Stream<Playlist> getPlaylistStream(int playlistId) {
    return _playlistDataSource.getPlaylistStream(playlistId);
  }

  @override
  Future<void> insertPlaylist(
    String name,
    String iconString,
    String gradientString,
    ShuffleMode? shuffleMode,
  ) async {
    _playlistDataSource.insertPlaylist(name, iconString, gradientString, shuffleMode);
  }

  @override
  Stream<List<Playlist>> get playlistsStream => _playlistDataSource.playlistsStream;

  @override
  Future<void> removePlaylist(Playlist playlist) async {
    _playlistDataSource.removePlaylist(playlist as PlaylistModel);
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    _playlistDataSource.updatePlaylist(PlaylistModel.fromPlaylist(playlist));
  }

  @override
  Future<void> movePlaylistEntry(int playlistId, int oldIndex, int newIndex) async {
    _playlistDataSource.moveEntry(playlistId, oldIndex, newIndex);
  }

  @override
  Future<void> removePlaylistEntry(int playlistId, int index) async {
    _playlistDataSource.removeIndex(playlistId, index);
  }

  @override
  Future<void> insertSmartList({
    required String name,
    required Filter filter,
    required OrderBy orderBy,
    required String iconString,
    required String gradientString,
    ShuffleMode? shuffleMode,
  }) {
    return _playlistDataSource.insertSmartList(
      name,
      filter,
      orderBy,
      iconString,
      gradientString,
      shuffleMode,
    );
  }

  @override
  Future<void> removeSmartList(SmartList smartList) =>
      _playlistDataSource.removeSmartList(smartList as SmartListModel);

  @override
  Stream<List<SmartList>> get smartListsStream => _playlistDataSource.smartListsStream;

  @override
  Stream<SmartList> getSmartListStream(int smartListId) =>
      _playlistDataSource.getSmartListStream(smartListId);

  @override
  Future<void> updateSmartList(SmartList smartList) {
    return _playlistDataSource.updateSmartList(SmartListModel.fromSmartList(smartList));
  }

  @override
  Stream<Song> getSongStream(String path) {
    return _musicDataSource.getSongStream(path);
  }

  @override
  Future<int?> getAlbumId(String title, String artist, int? year) async {
    return _musicDataSource.getAlbumId(title, artist, year);
  }

  Future<void> _updateHighlightStreams() async {
    _getAlbumOfDay().then((value) {
      if (value != null) {
        _albumOfDaySubject.add(value);
      }
    });
    _getArtistOfDay().then((value) {
      if (value != null) {
        _artistOfDaySubject.add(value);
      }
    });
  }

  Future<Album?> _getAlbumOfDay() async {
    final storedAlbum = await _musicDataSource.getAlbumOfDay();
    if (storedAlbum == null || !_isSameDay(storedAlbum.date)) {
      final albums = await _musicDataSource.albumStream.first;
      if (albums.isNotEmpty) {
        final rng = Random();
        final index = rng.nextInt(albums.length);
        _musicDataSource.setAlbumOfDay(AlbumOfDay(albums[index], _day(DateTime.now())));
        return albums[index];
      }
    }
    return storedAlbum?.albumModel;
  }

  Future<Artist?> _getArtistOfDay() async {
    final storedArtist = await _musicDataSource.getArtistOfDay();
    if (storedArtist == null || !_isSameDay(storedArtist.date)) {
      final artists = await _musicDataSource.artistStream.first;
      if (artists.isNotEmpty) {
        final rng = Random();
        final index = rng.nextInt(artists.length);
        _musicDataSource.setArtistOfDay(ArtistOfDay(artists[index], _day(DateTime.now())));
        return artists[index];
      }
    }
    return storedArtist?.artistModel;
  }

  bool _isSameDay(DateTime date) {
    return _day(DateTime.now()).difference(_day(date)).inDays < 1;
  }

  DateTime _day(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  @override
  Stream<List<CustomList>> getCustomListsStream({
    HomePlaylistsOrder orderCriterion = HomePlaylistsOrder.name,
    OrderDirection orderDirection = OrderDirection.ascending,
    HomePlaylistsFilter filter = HomePlaylistsFilter.both,
    int? limit,
  }) {
    final List<Stream<List<CustomList>>> streams = [];
    if ([HomePlaylistsFilter.both, HomePlaylistsFilter.smartlists].contains(filter)) {
      streams.add(_playlistDataSource.smartListsStream);
    }
    if ([HomePlaylistsFilter.both, HomePlaylistsFilter.playlists].contains(filter)) {
      streams.add(_playlistDataSource.playlistsStream);
    }

    return Rx.combineLatest(streams, (List<List<CustomList>> lists) {
      List<CustomList> combined = lists.expand((element) => element).toList();

      switch (orderCriterion) {
        case HomePlaylistsOrder.name:
          combined.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          break;
        case HomePlaylistsOrder.creationDate:
          combined.sort((a, b) => a.timeCreated.compareTo(b.timeCreated));
          break;
        case HomePlaylistsOrder.changeDate:
          combined.sort((a, b) => a.timeChanged.compareTo(b.timeChanged));
          break;
        case HomePlaylistsOrder.history:
          combined.sort((a, b) => a.timeLastPlayed.compareTo(b.timeLastPlayed));
          break;
      }

      if (orderDirection == OrderDirection.descending) {
        combined = combined.reversed.toList();
      }

      if (limit != null && limit > 0) {
        combined = combined.take(limit).toList();
      }

      return combined;
    });
  }

  @override
  Future<void> addBlockedFiles(List<String> paths) async {
    _songRemovalSubject.add(paths);
    await _playlistDataSource.removeBlockedSongs(paths);
    await _musicDataSource.addBlockedFiles(paths);
    _updateHighlightStreams();
  }

  @override
  Future<void> removeBlockedFiles(List<String> paths) async {
    await _musicDataSource.removeBlockedFiles(paths);
  }
  
  @override
  Future<List<bool>> isSongFirstLast(Song song) async {
    final songs = await _musicDataSource.getSongsFromSameAlbum(song as SongModel).then(_sortAlbumSongs);

    return [songs.indexOf(song) == 0, songs.indexOf(song) == songs.length - 1];
  }
}
