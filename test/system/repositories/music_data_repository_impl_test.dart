import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mosh/system/datasources/local_music_fetcher_contract.dart';
import 'package:mosh/system/datasources/music_data_source_contract.dart';
import 'package:mosh/system/models/album_model.dart';
import 'package:mosh/system/models/song_model.dart';
import 'package:mosh/system/repositories/music_data_repository_impl.dart';

import '../../test_constants.dart';

class MockLocalMusicFetcher extends Mock implements LocalMusicFetcher {}

class MockMusicDataSource extends Mock implements MusicDataSource {}

void main() {
  MusicDataRepositoryImpl repository;
  MockLocalMusicFetcher mockLocalMusicFetcher;
  MockMusicDataSource mockMusicDataSource;

  List<AlbumModel> tAlbumList;
  List<AlbumModel> tEmptyAlbumList;

  List<SongModel> tSongList;
  List<SongModel> tEmptySongList;

  setUp(() {
    mockLocalMusicFetcher = MockLocalMusicFetcher();
    mockMusicDataSource = MockMusicDataSource();

    repository = MusicDataRepositoryImpl(
      localMusicFetcher: mockLocalMusicFetcher,
      musicDataSource: mockMusicDataSource,
    );

    tAlbumList = setupAlbumList();
    tEmptyAlbumList = [];

    tSongList = setupSongList();
    tEmptySongList = [];
  });

  group('getAlbums', () {
    test(
      'should get albums from MusicDataSource',
      () async {
        // arrange
        when(mockMusicDataSource.getAlbums())
            .thenAnswer((_) async => tAlbumList);
        // act
        final result = await repository.getAlbums();
        // assert
        verify(mockMusicDataSource.getAlbums());
        expect(result, Right(tAlbumList));
      },
    );

    test(
      'should return empty list when MusicDataSource does not return albums',
      () async {
        // arrange
        when(mockMusicDataSource.getAlbums())
            .thenAnswer((_) async => tEmptyAlbumList);
        // act
        final result = await repository.getAlbums();
        // assert
        verify(mockMusicDataSource.getAlbums());
        expect(result, Right(tEmptyAlbumList));
      },
    );
  });

  group('getSongs', () {
    test(
      'should get songs from MusicDataSource',
      () async {
        // arrange
        when(mockMusicDataSource.getSongs()).thenAnswer((_) async => tSongList);
        // act
        final result = await repository.getSongs();
        // assert
        verify(mockMusicDataSource.getSongs());
        expect(result, Right(tSongList));
      },
    );

    test(
      'should get songs from MusicDataSource',
      () async {
        // arrange
        when(mockMusicDataSource.getSongs())
            .thenAnswer((_) async => tEmptySongList);
        // act
        final result = await repository.getSongs();
        // assert
        verify(mockMusicDataSource.getSongs());
        expect(result, Right(tEmptySongList));
      },
    );
  });

  group('updateDatabase', () {
    setUp(() {
      when(mockLocalMusicFetcher.getSongs())
          .thenAnswer((_) async => tEmptySongList);
      when(mockMusicDataSource.songExists(any)).thenAnswer((_) async => false);
    });

    test(
      'should fetch list of albums from LocalMusicFetcher',
      () async {
        when(mockLocalMusicFetcher.getAlbums())
            .thenAnswer((_) async => tAlbumList);

        when(mockMusicDataSource.albumExists(any))
            .thenAnswer((_) async => false);
        // act
        repository.updateDatabase();
        // assert
        verify(mockLocalMusicFetcher.getAlbums());
      },
    );

    test(
      'should insert fetched albums to MusicDataSource',
      () async {
        // arrange
        when(mockLocalMusicFetcher.getAlbums())
            .thenAnswer((_) async => tAlbumList);
        when(mockMusicDataSource.albumExists(any))
            .thenAnswer((_) async => false);
        // act
        await repository.updateDatabase();
        // assert
        for (final album in tAlbumList) {
          verify(mockMusicDataSource.insertAlbum(album));
        }
      },
    );

    test(
      'should not insert albums that are already stored in MusicDataSource',
      () async {
        // arrange
        when(mockLocalMusicFetcher.getAlbums())
            .thenAnswer((_) async => tAlbumList);
        when(mockMusicDataSource.albumExists(tAlbumList[0]))
            .thenAnswer((_) async => true);
        when(mockMusicDataSource.albumExists(tAlbumList[1]))
            .thenAnswer((_) async => false);
        // act
        await repository.updateDatabase();
        // assert
        verifyNever(mockMusicDataSource.insertAlbum(tAlbumList[0]));
        verify(mockMusicDataSource.insertAlbum(tAlbumList[1]));
      },
    );
  });
}

List<AlbumModel> setupAlbumList() => [
      AlbumModel(
        artist: ARTIST_1,
        title: ALBUM_TITLE_1,
        albumArtPath: ALBUM_ART_PATH_1,
        pubYear: YEAR_1,
      ),
      AlbumModel(
        artist: ARTIST_2,
        title: ALBUM_TITLE_2,
        albumArtPath: ALBUM_ART_PATH_2,
        pubYear: YEAR_2,
      ),
    ];

List<SongModel> setupSongList() => [
      SongModel(
        title: SONG_TITLE_3,
        album: ALBUM_TITLE_3,
        artist: ARTIST_3,
        path: PATH_3,
        duration: DURATION_3,
        trackNumber: TRACKNUMBER_3,
        albumArtPath: ALBUM_ART_PATH_3,
      ),
      SongModel(
        title: SONG_TITLE_4,
        album: ALBUM_TITLE_4,
        artist: ARTIST_4,
        path: PATH_4,
        duration: DURATION_4,
        trackNumber: TRACKNUMBER_4,
        albumArtPath: ALBUM_ART_PATH_4,
      ),
    ];
