import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:async_task/async_task.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fimber/flutter_fimber.dart';
import 'package:image/image.dart' as img;
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/default_values.dart';
import '../models/song_model.dart';
import '../utils.dart';
import 'local_music_fetcher.dart';
import 'music_data_source_contract.dart';
import 'settings_data_source.dart';

const IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png'];

class LocalMusicFetcherImpl implements LocalMusicFetcher {
  LocalMusicFetcherImpl(
    this._settingsDataSource,
    this._musicDataSource,
  );

  static final _log = FimberLog('LocalMusicFetcher');

  final SettingsDataSource _settingsDataSource;
  final MusicDataSource _musicDataSource;

  @override
  ValueStream<int?> get fileNumStream => _fileNumSubject.stream;
  @override
  ValueStream<int?> get progressStream => _progressSubject.stream;

  final BehaviorSubject<int?> _fileNumSubject = BehaviorSubject<int?>();
  final BehaviorSubject<int?> _progressSubject = BehaviorSubject<int?>();

  @override
  Future<Map<String, List>> getLocalMusic() async {
    // FIXME: it seems that songs currently loaded in queue are not updated
    _fileNumSubject.add(null);
    _progressSubject.add(null);
    int scanCount = 0;

    final musicDirectories = await _settingsDataSource.libraryFoldersStream.first;
    final libDirs = musicDirectories.map((e) => Directory(e));

    final extString = await _settingsDataSource.fileExtensionsStream.first;
    final allowedExtensions = getExtensionSet(extString);
    final blockedPaths = await _musicDataSource.blockedFilesStream.first;

    final hasStorageAccess = await Permission.storage.isGranted;
    if (!hasStorageAccess) {
      await Permission.storage.request();
      if (!await Permission.storage.isGranted) {
        return {};
      }
    }

    final Set<String> songFilePaths = {};
    for (final libDir in libDirs) {
      _log.d('Checking folder: ${libDir.path}');
      songFilePaths.addAll(
        await getSongFilesInDirectory(libDir.path, allowedExtensions, blockedPaths),
      );
    }
    final List<File> songFiles = songFilePaths.map((e) => File(e)).toList();

    _log.d('Found songs: ${songFiles.length}');

    final albumsInDb = await getSortedAlbums();
    int newAlbumId = albumsInDb.isNotEmpty ? albumsInDb.last.id + 1 : 0;
    _log.d('New albums start with id: $newAlbumId');

    final artistsInDb = await getSortedArtists();
    int newArtistId = artistsInDb.isNotEmpty ? artistsInDb.last.id + 1 : 0;
    _log.d('New artists start with id: $newArtistId');

    final List<File> songFilesToCheck = await getSongFilesToCheck(songFiles);
    _fileNumSubject.add(songFilesToCheck.length);
    _log.d('Song files to check: ${songFilesToCheck.length}');

    final existingSongFiles =
        songFiles.where((element) => !songFilesToCheck.contains(element)).toList();
    _log.d('Existing songs: ${existingSongFiles.length}');

    final structs = await mapSongsAlreadyScanned(existingSongFiles, albumsInDb, artistsInDb);

    final songs = structs['songs'] as List<SongModel>;
    final albums = structs['albums'] as List<AlbumModel>;
    final artists = structs['artists'] as Set<ArtistModel>;
    final albumIdMap = structs['albumIdMap'] as Map<String, int>;
    final albumArtMap = structs['albumArtMap'] as Map<int, String>;

    final songsToCheck = await getMetadataForFiles(songFilesToCheck);
    _log.d('Songs to process: ${songsToCheck.length}');

    for (final (songFile, songData) in songsToCheck) {
      _log.i('Processing Song ${songFile.path}');
      _progressSubject.add(++scanCount);

      final lastModified = songFile.lastModifiedSync();

      final albumArtist = songData.albumArtist ?? songData.artist;
      final albumString = '${songData.album}___${albumArtist}__${songData.year}';

      if (albumIdMap.containsKey(albumString)) {
        final albumId = albumIdMap[albumString]!;
        // TODO: Potential improvement. If albumArtMap does not contain an entry for this album yet
        // we could test if the current song has a picture. The way it is now if the first SongFile in an album
        // scanned has no picture, the whole album has no Picture.

        songs.add(
          SongModel.fromMetadata(
            path: songFile.path,
            songData: songData,
            albumId: albumId,
            albumArtPath: albumArtMap[albumId],
            lastModified: lastModified,
          ),
        );
        continue;
      }

      final albumId = await getAlbumId(
        newAlbumId,
        songData.album,
        albumArtist,
        songData.year,
      );
      albumIdMap[albumString] = albumId;
      newAlbumId = max(newAlbumId, albumId + 1);

      Uint8List? albumArt = songData.picture?.data;

      // fallback to get albumArt
      if (albumArt == null) {
        // get directory of song and look for image files
        final images = await songFile.parent
            .list(recursive: false, followLinks: false)
            .where((item) =>
                FileSystemEntity.isFileSync(item.path) &&
                IMAGE_EXTENSIONS.contains(p.extension(item.path).toLowerCase()))
            .asyncMap((item) => File(item.path))
            .toList();
        for (final image in images) {
          try {
            albumArt = image.readAsBytesSync();
            break;
          } catch (e) {
            _log.e('Could not read image file: ${image.path}');
          }
        }
      }

      if (albumArt != null) {
        albumArtMap[albumId] = await cacheAlbumArt(albumArt, albumId);
      }

      final String? songArtist = songData.artist;
      final String artistName = albumArtist ?? (songArtist ?? DEF_ARTIST);

      final artist = artistsInDb.firstWhereOrNull((a) => a.name == artistName);
      if (artist != null) artists.add(artist);
      if (artists.none((a) => a.name == artistName)) {
        // artist is also not in the set already
        artists.add(ArtistModel(name: artistName, id: newArtistId++));
      }

      albums.add(
        AlbumModel.fromMetadata(
          songData: songData,
          albumId: albumId,
          albumArtPath: albumArtMap[albumId],
        ),
      );
      songs.add(
        SongModel.fromMetadata(
          path: songFile.path,
          songData: songData,
          albumId: albumId,
          lastModified: lastModified,
          albumArtPath: albumArtMap[albumId],
        ),
      );
    }

    _log.d('Songs in list: ${songs.length}');

    final albumAccentTasks = albums
        .where((element) => element.color == null && element.albumArtPath != null)
        .map((e) => AccentGenerator(e.id, File(e.albumArtPath!)));

    final asyncExecutor = AsyncExecutor(
      sequential: false,
      parallelism: max(Platform.numberOfProcessors - 1, 1),
      taskTypeRegister: accentGeneratorTypeRegister,
    );

    asyncExecutor.logger.enabled = true;

    final executions = asyncExecutor.executeAll(albumAccentTasks);

    _fileNumSubject.add(executions.length);
    scanCount = 0;

    final albumColorMap = <int, Color>{};

    for (final execution in executions) {
      _progressSubject.add(++scanCount);
      final (albumId, color) = await execution;
      if (color == null) {
        _log.w('failed getting color for albumId $albumId');
        continue;
      }

      albumColorMap[albumId] = color;
    }

    asyncExecutor.close();

    for (int i = 0; i < albums.length; i++) {
      final Color? color = albumColorMap[albums[i].id];
      if (color != null) albums[i] = albums[i].copyWith(color: color);
    }

    for (int i = 0; i < songs.length; i++) {
      final Color? color = albumColorMap[songs[i].albumId];
      if (color != null) songs[i] = songs[i].copyWith(color: color);
    }

    return {
      'SONGS': songs,
      'ALBUMS': albums,
      'ARTISTS': artists.toList(),
    };
  }

  Future<Set<String>> getSongFilesInDirectory(
      String path, Set<String> allowedExtensions, Set<String> blockedPaths) async {
    return Directory(path)
        .list(recursive: true, followLinks: false)
        .where((item) => FileSystemEntity.isFileSync(item.path))
        .where((item) => !blockedPaths.contains(item.path))
        .where((item) {
          try {
            final extension = p.extension(item.path).toLowerCase().substring(1);
            return allowedExtensions.contains(extension);
          } on RangeError {
            return false;
          }
        })
        .asyncMap((item) => item.path)
        .toSet();
  }

  // Returns a list of all new song files and files that have changed since they where last imported
  Future<List<File>> getSongFilesToCheck(List<File> songFiles) async {
    final List<File> songFilesToCheck = [];
    final songsInDb = Map<String, SongModel>.fromIterable(
      await _musicDataSource.songStream.first,
      key: (s) => (s as SongModel).path,
    );

    for (final songFile in songFiles) {
      final lastModified = songFile.lastModifiedSync();
      final song = songsInDb[songFile.path];

      if (song == null || lastModified.isAfter(song.lastModified)) songFilesToCheck.add(songFile);
    }

    return songFilesToCheck;
  }

  Future<List<ArtistModel>> getSortedArtists() async {
    return (await _musicDataSource.artistStream.first)..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<List<AlbumModel>> getSortedAlbums() async {
    return (await _musicDataSource.albumStream.first)..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<int> getAlbumId(int newAlbumId, String? album, String? albumArtist, int? year) async {
    return await _musicDataSource.getAlbumId(album, albumArtist, year) ?? newAlbumId++;
  }

  Future<String> cacheAlbumArt(Uint8List albumArt, int albumId) async {
    final Directory dir = await getApplicationSupportDirectory();
    final albumArtPath = '${dir.path}/$albumId';
    final file = File(albumArtPath);
    file.writeAsBytesSync(albumArt);

    return albumArtPath;
  }

  /// Maps all the songs that where scanned previously, and their Albums and Artists to the new data structures
  Future<Map<String, dynamic>> mapSongsAlreadyScanned(
    List<File> songFiles,
    List<AlbumModel> albumsInDb,
    List<ArtistModel> artistsInDb,
  ) async {
    _log.d('Mapping already scanned songs: START');
    final List<SongModel> songs = [];
    final List<AlbumModel> albums = [];
    final Set<ArtistModel> artists = {};

    final Map<String, int> albumIdMap = {};
    final Map<int, String> albumArtMap = {};

    /// album id, background color
    final Map<int, Color?> colorMap = {};

    for (final songFile in songFiles) {
      _log.d('${songFile.path}');
      final song = (await _musicDataSource.getSongByPath(songFile.path))!;

      final album = albumsInDb.singleWhere((a) => a.id == song.albumId);
      final albumString = '${album.title}___${album.artist}__${album.pubYear}';

      if (albumIdMap.containsKey(albumString)) {
        // we already encountered the album (at least by albumString)
        // make sure the id is consistent
        if (album.id != albumIdMap[albumString])
          songs.add(
            song.copyWith(
              albumId: albumIdMap[albumString],
              color: colorMap[albumIdMap[albumString]],
            ),
          );
        else
          songs.add(song.copyWith(color: colorMap[album.id]));
      } else {
        albumIdMap[albumString] = album.id;

        if (album.albumArtPath != null) {
          albumArtMap[album.id] = album.albumArtPath!;
          if (album.color != null) colorMap[album.id] = album.color;
        }
        albums.add(album);
        final artist = artistsInDb.singleWhere((a) => a.name == album.artist);
        artists.add(artist);

        songs.add(song.copyWith(color: colorMap[album.id]));
      }
    }
    _log.d('Mapping already scanned songs: DONE');
    return {
      'songs': songs,
      'albums': albums,
      'artists': artists,
      'albumIdMap': albumIdMap,
      'albumArtMap': albumArtMap
    };
  }

  Future<List<(File, Metadata)>> getMetadataForFiles(List<File> filesToCheck) async {
    _log.d('Getting meta data for songs: START');
    final List<(File, Metadata)> songsMetadata = [];

    final tasks = filesToCheck.map((e) => MetadataLoader(e));

    final asyncExecutor = AsyncExecutor(
      sequential: false,
      parallelism: max(Platform.numberOfProcessors - 1, 1),
      taskTypeRegister: metadataLoaderTypeRegister,
    );

    asyncExecutor.logger.enabled = true;

    final executions = asyncExecutor.executeAll(tasks);

    await Future.wait(executions);

    for (final execution in executions) {
      final result = await execution;
      if (result != null) songsMetadata.add(result);
    }

    asyncExecutor.close();

    _log.d('Getting meta data for songs: DONE');
    return songsMetadata;
  }

  Set<String> getExtensionSet(String extString) {
    List<String> extensions = extString.toLowerCase().split(',');
    extensions = extensions.map((e) => e.trim()).toList();
    extensions = extensions.whereNot((element) => element.isEmpty).toList();
    return Set<String>.from(extensions);
  }

  Future<List<File>> getAllFilesRecursively(String path) async {
    final List<File> files = [];
    if (FileSystemEntity.isDirectorySync(path)) {
      final dir = Directory(path);
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        files.addAll(await getAllFilesRecursively(entity.path));
      }
    } else if (FileSystemEntity.isFileSync(path)) {
      files.add(File(path));
    }
    return files;
  }
}

List<AsyncTask> metadataLoaderTypeRegister() => [MetadataLoader(File(''))];

class MetadataLoader extends AsyncTask<File, (File, Metadata)?> {
  MetadataLoader(this.file);

  final File file;

  @override
  AsyncTask<File, (File, Metadata)?> instantiate(
    File parameters, [
    Map<String, SharedData>? sharedData,
  ]) {
    MetadataGod.initialize();
    return MetadataLoader(parameters);
  }

  @override
  File parameters() {
    return file;
  }

  @override
  FutureOr<(File, Metadata)?> run() async {
    try {
      return (file, await MetadataGod.readMetadata(file: file.path));
    } catch (e) {
      return null;
    }
  }
}

List<AsyncTask> accentGeneratorTypeRegister() => [AccentGenerator(0, File(''))];

class AccentGenerator extends AsyncTask<(int, File), (int, Color?)> {
  AccentGenerator(this.albumId, this.pictureFile);

  final File pictureFile;
  final int albumId;

  @override
  AsyncTask<(int, File), (int, Color?)> instantiate((int, File) parameters,
      [Map<String, SharedData>? sharedData]) {
    return AccentGenerator(parameters.$1, parameters.$2);
  }

  @override
  (int, File) parameters() {
    return (albumId, pictureFile);
  }

  @override
  FutureOr<(int, Color?)> run() async {
    final image = await _loadImage(pictureFile);
    if (image == null) return (albumId, null);
    return (albumId, getBackgroundColor(image));
  }

  Future<img.Image?> _loadImage(File file) async {
    final data = await file.readAsBytes();
    img.Image? image;
    try {
      image = img.decodeImage(data);
    } catch (e) {
      return null;
    }

    return image;
  }
}
