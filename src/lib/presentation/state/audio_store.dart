import 'dart:async';

import 'package:mobx/mobx.dart';

import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/loop_mode.dart';
import '../../domain/entities/playable.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/queue_item.dart';
import '../../domain/entities/shuffle_mode.dart';
import '../../domain/entities/smart_list.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/audio_player_repository.dart';
import '../../domain/usecases/play_album.dart';
import '../../domain/usecases/play_album_from_index.dart';
import '../../domain/usecases/play_artist.dart';
import '../../domain/usecases/play_playable.dart';
import '../../domain/usecases/play_playlist.dart';
import '../../domain/usecases/play_smart_list.dart';
import '../../domain/usecases/play_songs.dart';
import '../../domain/usecases/seek_to_next.dart';
import '../../domain/usecases/shuffle_all.dart';
import '../../domain/utils.dart';
import '../utils.dart' as utils;

part 'audio_store.g.dart';

class AudioStore extends _AudioStore with _$AudioStore {
  AudioStore({
    required PlayAlbum playAlbum,
    required PlayAlbumFromIndex playAlbumFromIndex,
    required PlayArtist playArtist,
    required PlaySongs playSongs,
    required PlaySmartList playSmartList,
    required PlayPlaylist playPlayist,
    required PlayPlayable playPlayable,
    required SeekToNext seekToNext,
    required ShuffleAll shuffleAll,
    required AudioPlayerRepository audioPlayerRepository,
  }) : super(
          playSongs,
          audioPlayerRepository,
          playAlbum,
          playAlbumFromIndex,
          playArtist,
          playSmartList,
          playPlayist,
          seekToNext,
          shuffleAll,
          playPlayable,
        );
}

abstract class _AudioStore with Store {
  _AudioStore(
    this._playSongs,
    this._audioPlayerRepository,
    this._playAlbum,
    this._playAlbumFromIndex,
    this._playArtist,
    this._playSmartList,
    this._playPlaylist,
    this._seekToNext,
    this._shuffleAll,
    this._playPlayable,
  ) {
    _audioPlayerRepository.managedQueueInfo.queueItemsStream.listen(_setQueue);
    _audioPlayerRepository.managedQueueInfo.availableSongsStream.listen((_) => _setAvSongs());
    _audioPlayerRepository.shuffleModeStream.listen((_) => _setAvSongs());
    _audioPlayerRepository.playableStream.listen((_) => _setAvSongs());
  }

  final AudioPlayerRepository _audioPlayerRepository;

  final PlayAlbum _playAlbum;
  final PlayAlbumFromIndex _playAlbumFromIndex;
  final PlayArtist _playArtist;
  final PlaySmartList _playSmartList;
  final PlayPlaylist _playPlaylist;
  final PlaySongs _playSongs;
  final PlayPlayable _playPlayable;
  final SeekToNext _seekToNext;
  final ShuffleAll _shuffleAll;

  @observable
  late ObservableStream<Song?> currentSongStream =
      _audioPlayerRepository.currentSongStream.asObservable();

  @observable
  late ObservableStream<bool> playingStream = _audioPlayerRepository.playingStream.asObservable();

  @observable
  late ObservableStream<Duration> currentPositionStream =
      _audioPlayerRepository.positionStream.asObservable(initialValue: const Duration(seconds: 0));

  @computed
  String get positionString =>
      utils.msToTimeString(currentPositionStream.value ?? const Duration(seconds: 0));

  @observable
  late ObservableStream<List<QueueItem>> queueStream =
      _audioPlayerRepository.managedQueueInfo.queueItemsStream.asObservable();

  @readonly
  late List<QueueItem> _queue = [];

  @action
  void _setQueue(List<QueueItem> queue) {
    _queue = queue;
  }

  @computed
  int get queueLength => _queue.length;

  @observable
  late List<QueueItem> _availableSongs = [];

  @action
  void _setAvSongs() {
    _availableSongs = filterAvailableSongs(
      _audioPlayerRepository.managedQueueInfo.availableSongsStream.value,
      blockLevel: calcBlockLevel(
        _audioPlayerRepository.shuffleModeStream.value,
        _audioPlayerRepository.playableStream.value,
      ),
    );
  }

  @computed
  int get numAvailableSongs => _availableSongs.length;

  @observable
  late ObservableStream<Playable> playableStream =
      _audioPlayerRepository.managedQueueInfo.playableStream.asObservable();

  @observable
  late ObservableStream<int?> queueIndexStream =
      _audioPlayerRepository.currentIndexStream.asObservable();

  @observable
  late ObservableStream<ShuffleMode> shuffleModeStream =
      _audioPlayerRepository.shuffleModeStream.asObservable();

  @observable
  late ObservableStream<LoopMode> loopModeStream =
      _audioPlayerRepository.loopModeStream.asObservable();

  Timer? _sleepTimer;
  void setSleepTimer(int time) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(Duration(minutes: time), () => _audioPlayerRepository.stop());
  }

  @computed
  bool get hasNext =>
      (queueIndexStream.value != null && queueIndexStream.value! < queueLength - 1) ||
      (loopModeStream.value ?? LoopMode.off) != LoopMode.off;

  @computed
  bool get hasPrevious =>
      (queueIndexStream.value != null && queueIndexStream.value! > 0) ||
      (loopModeStream.value ?? LoopMode.off) != LoopMode.off;

  Future<void> playSong(int index, List<Song> songList, Playable playable) async {
    _playSongs(songs: songList, initialIndex: index, playable: playable, keepInitialIndex: true);
  }

  Future<void> play() async => _audioPlayerRepository.play();

  Future<void> pause() async => _audioPlayerRepository.pause();

  Future<void> skipToNext() async => _seekToNext();

  Future<void> skipToPrevious() async => _audioPlayerRepository.seekToPrevious();

  Future<void> seekToIndex(int index) async => _audioPlayerRepository.seekToIndex(index);

  Future<void> seekToPosition(double position) async =>
      _audioPlayerRepository.seekToPosition(position);

  Future<void> setShuffleMode(ShuffleMode shuffleMode) async =>
      _audioPlayerRepository.setShuffleMode(shuffleMode);

  Future<void> setLoopMode(LoopMode loopMode) async => _audioPlayerRepository.setLoopMode(loopMode);

  Future<void> shuffleAll(ShuffleMode shuffleMode) async => _shuffleAll(shuffleMode);

  Future<void> addToQueue(List<Song> songs) async => _audioPlayerRepository.addToQueue(songs);

  Future<void> playNext(List<Song> songs) async => _audioPlayerRepository.playNext(songs);

  Future<void> appendToNext(List<Song> songs) async => _audioPlayerRepository.addToNext(songs);

  Future<void> moveQueueItem(int oldIndex, int newIndex) async =>
      _audioPlayerRepository.moveQueueItem(oldIndex, newIndex);

  Future<void> removeQueueIndices(List<int> indices) async =>
      _audioPlayerRepository.removeQueueIndices(indices);

  Future<void> playAlbum(Album album) async => _playAlbum(album);

  Future<void> playAlbumFromIndex(Album album, int initialIndex) async =>
      _playAlbumFromIndex(album, initialIndex);

  Future<void> playSmartList(SmartList smartList) async => _playSmartList(smartList);

  Future<void> playPlaylist(Playlist playlist) async => _playPlaylist(playlist);

  Future<void> playArtist(Artist artist, ShuffleMode? shuffleMode) async =>
      _playArtist(artist, shuffleMode);

  Future<void> playPlayable(Playable playable, ShuffleMode? shuffleMode) async =>
      _playPlayable(playable, shuffleMode);
}
