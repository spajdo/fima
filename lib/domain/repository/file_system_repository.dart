import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';

abstract class FileSystemRepository {
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  });
  Future<String> getHomeDirectory();
  Future<void> deleteItem(String path);
  Future<void> createDirectory(String path);
  Future<void> createFile(String path);
  Future<void> renameItem(String oldPath, String newPath);
  Future<void> copyItem(String sourcePath, String destinationPath);
  Future<void> moveItem(String sourcePath, String destinationPath);
  Future<void> moveToTrash(String path);

  Stream<OperationStatus> copyItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  );

  Stream<OperationStatus> moveItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  );
}
