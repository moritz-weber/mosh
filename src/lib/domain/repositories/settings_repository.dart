import 'package:rxdart/rxdart.dart';

abstract class SettingsInfoRepository {
  Stream<List<String>> get libraryFoldersStream;
  ValueStream<String> get fileExtensionsStream;
  ValueStream<bool> get manageExternalStorageGranted;
  ValueStream<bool> get playAlbumsInOrderStream;
}

abstract class SettingsRepository extends SettingsInfoRepository {
  Future<void> addLibraryFolder(String? path);
  Future<void> removeLibraryFolder(String? path);
  Future<void> setFileExtension(String extensions);
  Future<void> setManageExternalStorageGranted(bool granted);
  Future<void> setPlayAlbumsInOrder(bool playInOrder);
}
