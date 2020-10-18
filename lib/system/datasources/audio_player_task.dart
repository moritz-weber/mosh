import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:moor/isolate.dart';
import 'package:moor/moor.dart';

import '../../domain/entities/shuffle_mode.dart';
import '../models/song_model.dart';
import 'moor_music_data_source.dart';
import 'queue_manager.dart';

const String INIT = 'INIT';
const String PLAY_WITH_CONTEXT = 'PLAY_WITH_CONTEXT';
const String APP_LIFECYCLE_RESUMED = 'APP_LIFECYCLE_RESUMED';
const String SET_SHUFFLE_MODE = 'SET_SHUFFLE_MODE';
const String SHUFFLE_ALL = 'SHUFFLE_ALL';
const String KEY_INDEX = 'INDEX';

class AudioPlayerTask extends BackgroundAudioTask {
  final audioPlayer = AudioPlayer();
  MoorMusicDataSource moorMusicDataSource;
  QueueManager qm;

  List<MediaItem> originalPlaybackContext = <MediaItem>[];
  List<MediaItem> playbackContext = <MediaItem>[];

  ConcatenatingAudioSource queue;
  List<int> permutation;

  ShuffleMode _shuffleMode = ShuffleMode.none;
  ShuffleMode get shuffleMode => _shuffleMode;
  set shuffleMode(ShuffleMode s) {
    _shuffleMode = s;
    AudioServiceBackground.sendCustomEvent({SET_SHUFFLE_MODE: s.toString()});
  }

  int _playbackIndex = -1;
  int get playbackIndex => _playbackIndex;
  set playbackIndex(int i) {
    print(i);
    if (i != null) {
      _playbackIndex = i;
      AudioServiceBackground.setMediaItem(playbackContext[i]);
      AudioServiceBackground.sendCustomEvent({KEY_INDEX: i});

      AudioServiceBackground.setState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext
        ],
        playing: audioPlayer.playing,
        processingState: AudioProcessingState.ready,
        updateTime:
            Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
        position: audioPlayer.position,
      );
    }
  }

  @override
  Future<void> onStop() async {
    await audioPlayer.stop();
    await audioPlayer.dispose();
    await super.onStop();
  }

  @override
  Future<void> onPlay() async {
    audioPlayer.play();
  }

  @override
  Future<void> onPause() async {
    await audioPlayer.pause();
  }

  @override
  Future<void> onSkipToNext() async {
    audioPlayer.seekToNext();
  }

  @override
  Future<void> onSkipToPrevious() async {
    audioPlayer.seekToPrevious();
  }

  @override
  Future<void> onCustomAction(String name, arguments) async {
    switch (name) {
      case INIT:
        return init();
      case PLAY_WITH_CONTEXT:
        // arguments: [List<String>, int]
        final args = arguments as List<dynamic>;
        final context = List<String>.from(args[0] as List<dynamic>);
        final index = args[1] as int;
        return playWithContext(context, index);
      case APP_LIFECYCLE_RESUMED:
        return onAppLifecycleResumed();
      case SET_SHUFFLE_MODE:
        return setShuffleMode((arguments as String).toShuffleMode());
      case SHUFFLE_ALL:
        return shuffleAll();
      default:
    }
  }

  Future<void> init() async {
    print('AudioPlayerTask.init');
    audioPlayer.playerStateStream.listen((event) => handlePlayerState(event));
    audioPlayer.sequenceStateStream
        .listen((event) => playbackIndex = event?.currentIndex);

    final connectPort = IsolateNameServer.lookupPortByName(MOOR_ISOLATE);
    final MoorIsolate moorIsolate = MoorIsolate.fromConnectPort(connectPort);
    final DatabaseConnection databaseConnection = await moorIsolate.connect();
    moorMusicDataSource = MoorMusicDataSource.connect(databaseConnection);

    qm = QueueManager(moorMusicDataSource);
  }

  Future<void> playWithContext(List<String> context, int index) async {
    final mediaItems = await qm.getMediaItemsFromPaths(context);
    playPlaylist(mediaItems, index);
  }

  Future<void> onAppLifecycleResumed() async {
    AudioServiceBackground.sendCustomEvent({KEY_INDEX: playbackIndex});
    AudioServiceBackground.sendCustomEvent(
        {SET_SHUFFLE_MODE: shuffleMode.toString()});
  }

  Future<void> setShuffleMode(ShuffleMode mode) async {
    shuffleMode = mode;

    final index = permutation[playbackIndex];
    permutation =
        qm.generatePermutation(shuffleMode, originalPlaybackContext, index);
    playbackContext =
        qm.getPermutatedSongs(originalPlaybackContext, permutation);

    AudioServiceBackground.setQueue(playbackContext);

    final newQueue = qm.mediaItemsToAudioSource(playbackContext);
    queue.removeRange(0, playbackIndex);
    queue.removeRange(1, queue.length);

    if (shuffleMode == ShuffleMode.none) {
      queue.insertAll(0, newQueue.children.sublist(0, index));
      queue.addAll(newQueue.children.sublist(index + 1));
      playbackIndex = index;
    } else {
      queue.addAll(newQueue.children.sublist(1));
    }
  }

  Future<void> shuffleAll() async {
    shuffleMode = ShuffleMode.standard;
    final List<SongModel> songs = await moorMusicDataSource.getSongs();
    final List<MediaItem> mediaItems =
        songs.map((song) => song.toMediaItem()).toList();

    final rng = Random();
    final index = rng.nextInt(mediaItems.length);

    playPlaylist(mediaItems, index);
  }

  Future<void> playPlaylist(List<MediaItem> mediaItems, int index) async {
    permutation = qm.generatePermutation(shuffleMode, mediaItems, index);
    playbackContext = qm.getPermutatedSongs(mediaItems, permutation);
    originalPlaybackContext = mediaItems;

    AudioServiceBackground.setQueue(playbackContext);
    queue = qm.mediaItemsToAudioSource(playbackContext);
    audioPlayer.play();
    final int startIndex = shuffleMode == ShuffleMode.none ? index : 0;
    await audioPlayer.load(queue, initialIndex: startIndex);
  }

  void handlePlayerState(PlayerState ps) {
    if (ps.processingState == ProcessingState.ready && ps.playing) {
      AudioServiceBackground.setState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext
        ],
        playing: true,
        processingState: AudioProcessingState.ready,
        updateTime:
            Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
        position: audioPlayer.position,
      );
    } else if (ps.processingState == ProcessingState.ready && !ps.playing) {
      AudioServiceBackground.setState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext
        ],
        processingState: AudioProcessingState.ready,
        updateTime:
            Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
        position: audioPlayer.position,
        playing: false,
      );
    }
  }
}
