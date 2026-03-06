import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/master_project.dart';
import 'markdown_parser.dart';

/// Handles all file system operations for `.md` project files.
class FileService {
  static const String _mdExtension = '.md';
  static const String _archiveFolderName = 'archive';
  static const String _defaultFolderName = 'markdone';
  String? _cachedBasePath;

  /// Allows overriding the base path (from user settings).
  String? customBasePath;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  String? _extractAndroidExternalRoot(String path) {
    const marker = '/Android/';
    final markerIndex = path.indexOf(marker);
    if (markerIndex == -1) return null;
    return path.substring(0, markerIndex);
  }

  Future<Directory?> _getAndroidSharedDocumentsDir() async {
    final extDirs = await getExternalStorageDirectories();
    if (extDirs == null || extDirs.isEmpty) return null;

    for (final extDir in extDirs) {
      final storageRoot = _extractAndroidExternalRoot(extDir.path);
      if (storageRoot == null || storageRoot.isEmpty) continue;

      final candidate = Directory(
        p.join(storageRoot, 'Documents', _defaultFolderName),
      );

      try {
        if (!await candidate.exists()) {
          await candidate.create(recursive: true);
        }
        return candidate;
      } catch (e) {
        _log('Could not use shared Documents folder ${candidate.path}: $e');
      }
    }

    return null;
  }

  /// Returns the base directory where `.md` files are stored.
  /// Priority: customBasePath > external storage > app documents.
  Future<String> get basePath async {
    // If user has set a custom path, always use that
    if (customBasePath != null && customBasePath!.isNotEmpty) {
      final dir = Directory(customBasePath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return customBasePath!;
    }

    if (_cachedBasePath != null) return _cachedBasePath!;

    Directory baseDir;
    if (Platform.isAndroid) {
      final sharedDocumentsDir = await _getAndroidSharedDocumentsDir();
      if (sharedDocumentsDir != null) {
        baseDir = sharedDocumentsDir;
      } else {
        // Fallback to app-scoped storage if shared Documents is unavailable.
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null && extDirs.isNotEmpty) {
          baseDir = Directory(p.join(extDirs.first.path, _defaultFolderName));
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          baseDir = Directory(p.join(appDir.path, _defaultFolderName));
        }
      }
    } else {
      // Linux / Desktop
      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      baseDir = Directory(p.join(homeDir, 'Documents', _defaultFolderName));
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    _cachedBasePath = baseDir.path;
    return _cachedBasePath!;
  }

  /// Returns the active storage path currently used by the app.
  Future<String> get effectiveStoragePath async => basePath;

  /// Returns the archive directory where archived `.md` files are stored.
  Future<String> get archivePath async {
    final archiveDir = Directory(p.join(await basePath, _archiveFolderName));
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }
    return archiveDir.path;
  }

  /// Lists all `.md` files in the base directory.
  Future<List<File>> listMarkdownFiles({bool archived = false}) async {
    final dir = Directory(await (archived ? archivePath : basePath));
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith(_mdExtension))
        .cast<File>()
        .toList();

    // Sort by last modified, newest first
    files.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return bStat.modified.compareTo(aStat.modified);
    });

    return files;
  }

  /// Reads and parses a single `.md` file into a [MasterProject].
  Future<MasterProject> readProject(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    return MarkdownParser.parse(content, filePath);
  }

  /// Reads and parses all `.md` files into [MasterProject] objects.
  Future<List<MasterProject>> readAllProjects({bool archived = false}) async {
    final files = await listMarkdownFiles(archived: archived);
    final projects = <MasterProject>[];

    for (final file in files) {
      try {
        final project = await readProject(file.path);
        projects.add(project);
      } catch (e) {
        _log('Error parsing ${file.path}: $e');
      }
    }

    return projects;
  }

  /// Writes a [MasterProject] to its `.md` file.
  Future<void> writeProject(MasterProject project) async {
    final content = MarkdownParser.serialize(project);
    final file = File(project.filePath);
    await file.writeAsString(content);
  }

  /// Creates a new `.md` file with default frontmatter.
  Future<MasterProject> createProject({
    required String title,
    DateTime? dday,
    String? color,
    String? description,
    bool syncWithCalendar = false,
  }) async {
    final base = await basePath;
    // Sanitize filename
    final safeName = title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    var filePath = p.join(base, '$safeName$_mdExtension');

    // Avoid overwriting existing files
    int counter = 1;
    while (await File(filePath).exists()) {
      filePath = p.join(base, '${safeName}_$counter$_mdExtension');
      counter++;
    }

    final project = MasterProject(
      filePath: filePath,
      title: title,
      created: DateTime.now(),
      dday: dday,
      color: color,
      description: description,
      syncWithCalendar: syncWithCalendar,
      todos: [],
    );

    await writeProject(project);
    return project;
  }

  /// Deletes a project's `.md` file.
  Future<void> deleteProject(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      _log('Delete skipped, file does not exist: $filePath');
      return;
    }

    await file.delete();

    if (await file.exists()) {
      throw FileSystemException(
        'Project file still exists after delete',
        filePath,
      );
    }
  }

  /// Moves a project file into the archive folder.
  Future<String> archiveProject(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return filePath;

    final archiveDir = await archivePath;
    final fileName = p.basename(filePath);
    var destinationPath = p.join(archiveDir, fileName);
    var counter = 1;

    while (await File(destinationPath).exists()) {
      final baseName = p.basenameWithoutExtension(fileName);
      destinationPath = p.join(archiveDir, '${baseName}_$counter$_mdExtension');
      counter++;
    }

    await file.rename(destinationPath);
    return destinationPath;
  }

  /// Moves an archived project file back to the active projects folder.
  Future<String> restoreProject(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return filePath;

    final activeDir = await basePath;
    final fileName = p.basename(filePath);
    var destinationPath = p.join(activeDir, fileName);
    var counter = 1;

    while (await File(destinationPath).exists()) {
      final baseName = p.basenameWithoutExtension(fileName);
      destinationPath = p.join(activeDir, '${baseName}_$counter$_mdExtension');
      counter++;
    }

    await file.rename(destinationPath);
    return destinationPath;
  }

  /// Watches the base directory for changes (external edits).
  Stream<FileSystemEvent> watchDirectory() async* {
    final dir = Directory(await basePath);
    if (await dir.exists()) {
      yield* dir.watch(events: FileSystemEvent.all);
    }
  }

  /// Watches the archive directory for changes (external edits).
  Stream<FileSystemEvent> watchArchiveDirectory() async* {
    final dir = Directory(await archivePath);
    if (await dir.exists()) {
      yield* dir.watch(events: FileSystemEvent.all);
    }
  }
}
