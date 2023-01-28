import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../constants.dart';
import '../../defaults.dart';
import '../../domain/entities/playable.dart';
import 'moor/history_dao.dart';
import 'moor/home_widget_dao.dart';
import 'moor/music_data_dao.dart';
import 'moor/persistent_state_dao.dart';
import 'moor/playlist_dao.dart';
import 'moor/settings_dao.dart';

part 'moor_database.g.dart';

const String MOOR_ISOLATE = 'MOOR_ISOLATE';

@DataClassName('MoorArtist')
class Artists extends Table {
  TextColumn get name => text()();
  IntColumn get id => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MoorAlbum')
class Albums extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get albumArtPath => text().nullable()();
  IntColumn get year => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MoorSong')
class Songs extends Table {
  TextColumn get title => text()();
  TextColumn get albumTitle => text()();
  IntColumn get albumId => integer()();
  TextColumn get artist => text()();
  TextColumn get path => text()();
  IntColumn get duration => integer()();
  TextColumn get albumArtPath => text().nullable()();
  IntColumn get discNumber => integer()();
  IntColumn get trackNumber => integer()();
  IntColumn get year => integer().nullable()();
  IntColumn get blockLevel => integer().withDefault(const Constant(0))();
  IntColumn get likeCount => integer().withDefault(const Constant(0))();
  IntColumn get skipCount => integer().withDefault(const Constant(0))();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  BoolColumn get present => boolean().withDefault(const Constant(true))();
  DateTimeColumn get timeAdded => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastModified => dateTime()();

  BoolColumn get previous => boolean().withDefault(const Constant(false))();
  BoolColumn get next => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {path};
}

@DataClassName('MoorQueueEntry')
class QueueEntries extends Table {
  IntColumn get index => integer()();
  TextColumn get path => text()();
  IntColumn get originalIndex => integer()();
  IntColumn get type => integer()();
  BoolColumn get isAvailable => boolean()();

  @override
  Set<Column> get primaryKey => {index};
}

@DataClassName('AvailableSongEntry')
class AvailableSongEntries extends Table {
  IntColumn get index => integer()();
  TextColumn get path => text()();
  IntColumn get originalIndex => integer()();
  IntColumn get type => integer()();
  BoolColumn get isAvailable => boolean()();

  @override
  Set<Column> get primaryKey => {index};
}

@DataClassName('KeyValueEntry')
class KeyValueEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class LibraryFolders extends Table {
  TextColumn get path => text()();
}

@DataClassName('MoorSmartList')
class SmartLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get shuffleMode => text().nullable()();
  TextColumn get icon => text().withDefault(const Constant('auto_awesome_rounded'))();
  TextColumn get gradient => text().withDefault(const Constant('sanguine'))();
  DateTimeColumn get timeCreated => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get timeChanged => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get timeLastPlayed =>
      dateTime().withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))();

  // Filter
  BoolColumn get excludeArtists => boolean().withDefault(const Constant(false))();
  IntColumn get blockLevel => integer().withDefault(const Constant(0))();
  IntColumn get minLikeCount => integer().withDefault(const Constant(0))();
  IntColumn get maxLikeCount => integer().withDefault(const Constant(5))();
  IntColumn get minPlayCount => integer().nullable()();
  IntColumn get maxPlayCount => integer().nullable()();
  IntColumn get minSkipCount => integer().nullable()();
  IntColumn get maxSkipCount => integer().nullable()();
  IntColumn get minYear => integer().nullable()();
  IntColumn get maxYear => integer().nullable()();
  IntColumn get limit => integer().nullable()();

  // OrderBy
  TextColumn get orderCriteria => text()();
  TextColumn get orderDirections => text()();
}

@DataClassName('MoorSmartListArtist')
class SmartListArtists extends Table {
  IntColumn get smartListId => integer()();
  TextColumn get artistName => text()();
}

@DataClassName('MoorPlaylist')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get shuffleMode => text().nullable()();
  TextColumn get icon => text().withDefault(const Constant('queue_music_rounded'))();
  TextColumn get gradient => text().withDefault(const Constant('oceanblue'))();
  DateTimeColumn get timeCreated => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get timeChanged => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get timeLastPlayed =>
      dateTime().withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))();
}

@DataClassName('MoorPlaylistEntry')
class PlaylistEntries extends Table {
  IntColumn get playlistId => integer()();
  TextColumn get songPath => text()();
  IntColumn get position => integer()();
}

@DataClassName('MoorHomeWidget')
class HomeWidgets extends Table {
  IntColumn get position => integer()();
  TextColumn get type => text()();
  TextColumn get data => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {position};
}

@DataClassName('MoorHistoryEntry')
class HistoryEntries extends Table {
  DateTimeColumn get time => dateTime().withDefault(currentDateAndTime)();
  TextColumn get type => text()();
  TextColumn get identifier => text()();
}

class BlockedFiles extends Table {
  TextColumn get path => text()();

  @override
  Set<Column> get primaryKey => {path};
}

@DriftDatabase(
  tables: [
    Albums,
    Artists,
    LibraryFolders,
    QueueEntries,
    AvailableSongEntries,
    Songs,
    SmartLists,
    SmartListArtists,
    Playlists,
    PlaylistEntries,
    KeyValueEntries,
    HomeWidgets,
    HistoryEntries,
    BlockedFiles,
  ],
  daos: [
    PersistentStateDao,
    SettingsDao,
    MusicDataDao,
    PlaylistDao,
    HomeWidgetDao,
    HistoryDao,
  ],
)
class MoorDatabase extends _$MoorDatabase {
  /// Use MoorMusicDataSource in main isolate only.
  MoorDatabase() : super(_openConnection());

  /// Used for testing with in-memory database.
  MoorDatabase.withQueryExecutor(QueryExecutor e) : super(e);

  /// Used to connect to a database on another isolate.
  MoorDatabase.connect(DatabaseConnection connection) : super.connect(connection);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          if (details.wasCreated) {
            await into(keyValueEntries).insert(
              const KeyValueEntriesCompanion(key: Value(PERSISTENT_INDEX), value: Value('0')),
            );
            await into(keyValueEntries).insert(
              const KeyValueEntriesCompanion(key: Value(PERSISTENT_LOOPMODE), value: Value('0')),
            );
            await into(keyValueEntries).insert(
              const KeyValueEntriesCompanion(key: Value(PERSISTENT_SHUFFLEMODE), value: Value('0')),
            );
            await into(keyValueEntries).insert(
              const KeyValueEntriesCompanion(
                  key: Value(SETTING_ALLOWED_EXTENSIONS), value: Value(ALLOWED_FILE_EXTENSIONS)),
            );
            await into(keyValueEntries).insert(
              const KeyValueEntriesCompanion(
                  key: Value(SETTING_PLAY_ALBUMS_IN_ORDER), value: Value('false')),
            );
            final Map initialPlayable = {
              'id': '',
              'type': PlayableType.all.toString(),
            };
            await into(keyValueEntries).insert(
              KeyValueEntriesCompanion(
                key: const Value(PERSISTENT_PLAYABLE),
                value: Value(jsonEncode(initialPlayable)),
              ),
            );
            await into(homeWidgets).insert(
              const HomeWidgetsCompanion(
                position: Value(0),
                type: Value('HomeWidgetType.album_of_day'),
                data: Value('{}'),
              ),
            );
            await into(homeWidgets).insert(
              const HomeWidgetsCompanion(
                position: Value(1),
                type: Value('HomeWidgetType.artist_of_day'),
                data: Value('{"shuffleMode": "ShuffleMode.plus"}'),
              ),
            );
            await into(homeWidgets).insert(
              const HomeWidgetsCompanion(
                position: Value(2),
                type: Value('HomeWidgetType.shuffle_all'),
                data: Value('{"shuffleMode": "ShuffleMode.plus"}'),
              ),
            );
            await into(homeWidgets).insert(
              HomeWidgetsCompanion(
                position: const Value(3),
                type: const Value('HomeWidgetType.playlists'),
                data: Value(
                  json.encode({
                    'title': 'Your Playlists',
                    'maxEntries': 3,
                    'orderCriterion': 'HomePlaylistsOrder.name',
                    'orderDirection': 'OrderDirection.ascending',
                    'filter': 'HomePlaylistsFilter.both',
                  }),
                ),
              ),
            );
            await into(homeWidgets).insert(
              HomeWidgetsCompanion(
                position: const Value(4),
                type: const Value('HomeWidgetType.history'),
                data: Value(
                  json.encode({
                    'maxEntries': 3,
                  }),
                ),
              ),
            );
          }
        },
        onUpgrade: (Migrator m, int from, int to) async {
          print('$from -> $to');
          if (from < 2) {
            await m.addColumn(smartLists, smartLists.blockLevel);
            await m.alterTable(TableMigration(smartLists));
          }
          if (from < 3) {
            await m.addColumn(songs, songs.lastModified);
            await m.alterTable(
              TableMigration(songs, columnTransformer: {
                songs.lastModified: Constant(DateTime.fromMillisecondsSinceEpoch(0)),
              }),
            );
          }
          if (from < 4) {
            await m.alterTable(
              TableMigration(songs, columnTransformer: {
                songs.previous: const Constant(false),
                songs.next: const Constant(false),
              }),
            );
          }
          if (from < 5) {
            await m.addColumn(smartLists, smartLists.icon);
            await m.addColumn(smartLists, smartLists.gradient);
            await m.alterTable(TableMigration(smartLists));
          }
          if (from < 6) {
            await m.addColumn(playlists, playlists.shuffleMode);
            await m.addColumn(playlists, playlists.icon);
            await m.addColumn(playlists, playlists.gradient);
            await m.alterTable(TableMigration(playlists));
          }
          if (from < 7) {
            await m.alterTable(
              TableMigration(artists, columnTransformer: {
                artists.id: artists.rowId,
              }),
            );
          }
          if (from < 8) {
            await m.createTable(homeWidgets);
            await into(homeWidgets).insert(
              const HomeWidgetsCompanion(
                position: Value(0),
                type: Value('HomeWidgetType.album_of_day'),
                data: Value('{}'),
              ),
            );
            await into(homeWidgets).insert(
              const HomeWidgetsCompanion(
                position: Value(1),
                type: Value('HomeWidgetType.artist_of_day'),
                data: Value('{"shuffleMode": "ShuffleMode.plus"}'),
              ),
            );
            await into(homeWidgets).insert(
              const HomeWidgetsCompanion(
                position: Value(2),
                type: Value('HomeWidgetType.shuffle_all'),
                data: Value('{"shuffleMode": "ShuffleMode.plus"}'),
              ),
            );
            await into(homeWidgets).insert(
              const HomeWidgetsCompanion(
                position: Value(3),
                type: Value('HomeWidgetType.playlists'),
                data: Value('{}'),
              ),
            );
          }
          if (from < 9) {
            final now = DateTime.now();
            await m.addColumn(smartLists, smartLists.timeLastPlayed);
            await m.alterTable(TableMigration(smartLists, columnTransformer: {
              smartLists.timeChanged: Constant(now),
              smartLists.timeCreated: Constant(now),
            }));
            await m.addColumn(playlists, playlists.timeLastPlayed);
            await m.alterTable(TableMigration(playlists, columnTransformer: {
              playlists.timeChanged: Constant(now),
              playlists.timeCreated: Constant(now),
            }));
          }
          if (from < 10) {
            await m.createTable(historyEntries);
          }
          if (from < 11) {
            await m.createTable(blockedFiles);
            await into(keyValueEntries).insert(
              const KeyValueEntriesCompanion(
                  key: Value(SETTING_ALLOWED_EXTENSIONS), value: Value(ALLOWED_FILE_EXTENSIONS)),
            );
          }
          if (from < 12) {
            await into(keyValueEntries).insert(const KeyValueEntriesCompanion(
              key: Value(SETTING_PLAY_ALBUMS_IN_ORDER),
              value: Value('false'),
            ));
          }
        },
      );
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

Future<DriftIsolate> createMoorIsolate() async {
  // this method is called from the main isolate. Since we can't use
  // getApplicationDocumentsDirectory on a background isolate, we calculate
  // the database path in the foreground isolate and then inform the
  // background isolate about the path.
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'db.sqlite');
  final receivePort = ReceivePort();

  await Isolate.spawn(
    _startBackground,
    _IsolateStartRequest(receivePort.sendPort, path),
  );

  // _startBackground will send the MoorIsolate to this ReceivePort
  return await receivePort.first as DriftIsolate;
}

void _startBackground(_IsolateStartRequest request) {
  // this is the entry point from the background isolate! Let's create
  // the database from the path we received
  final executor = NativeDatabase(File(request.targetPath));
  // we're using MoorIsolate.inCurrent here as this method already runs on a
  // background isolate. If we used MoorIsolate.spawn, a third isolate would be
  // started which is not what we want!
  final moorIsolate = DriftIsolate.inCurrent(
    () => DatabaseConnection.fromExecutor(executor),
  );
  // inform the starting isolate about this, so that it can call .connect()
  request.sendMoorIsolate.send(moorIsolate);
}

// used to bundle the SendPort and the target path, since isolate entry point
// functions can only take one parameter.
class _IsolateStartRequest {
  _IsolateStartRequest(this.sendMoorIsolate, this.targetPath);

  final SendPort sendMoorIsolate;
  final String targetPath;
}
