import 'package:drift/drift.dart';
import 'package:on_audio_query/on_audio_query.dart' as aq;

import '../../domain/entities/album.dart';
import '../datasources/drift_database.dart';
import '../utils.dart';
import 'default_values.dart';

class AlbumModel extends Album {
  const AlbumModel({
    required super.id,
    required super.title,
    required super.artist,
    super.albumArtPath,
    super.pubYear,
  });

  factory AlbumModel.fromDrift(DriftAlbum driftAlbum) => AlbumModel(
        id: driftAlbum.id,
        title: driftAlbum.title,
        artist: driftAlbum.artist,
        albumArtPath: driftAlbum.albumArtPath,
        pubYear: driftAlbum.year,
      );

    factory AlbumModel.fromOnAudioQuery({
    required aq.SongModel songModel,
    required int albumId,
    String? albumArtPath,
  }) {
    final data = songModel.getMap;
    final albumArtist = data['album_artist'] as String? ?? '';
    final artist = albumArtist != '' ? albumArtist : songModel.artist;

    return AlbumModel(
      id: albumId,
      title: songModel.album ?? DEF_ALBUM,
      artist: artist ?? DEF_ARTIST,
      albumArtPath: albumArtPath,
      pubYear: data['year'] == null ? null : parseYear(data['year'] as String?),
    );
  }

  @override
  String toString() {
    return '$title';
  }

  AlbumModel copyWith({
    String? artist,
    String? title,
    int? id,
    int? pubYear,
    String? albumArtPath,
  }) =>
      AlbumModel(
          artist: artist ?? this.artist,
          title: title ?? this.title,
          id: id ?? this.id,
          pubYear: pubYear ?? this.pubYear,
          albumArtPath: albumArtPath ?? this.albumArtPath);

  AlbumsCompanion toAlbumsCompanion() => AlbumsCompanion(
        id: Value(id),
        title: Value(title),
        artist: Value(artist),
        albumArtPath: Value(albumArtPath),
        year: Value(pubYear),
      );
}

class AlbumOfDay {
  AlbumOfDay(this.albumModel, this.date);

  final AlbumModel albumModel;
  final DateTime date;

  String toJSON() {
    return '{"id": ${albumModel.id}, "date": ${date.millisecondsSinceEpoch}}';
  }
}
