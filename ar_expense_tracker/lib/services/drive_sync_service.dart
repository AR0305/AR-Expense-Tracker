// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';

enum SyncResult { uploaded, downloaded, upToDate, error, none }

class SyncState {
  final bool isSyncing;
  final double syncProgress;
  final String syncStatus;
  const SyncState({this.isSyncing = false, this.syncProgress = -1.0, this.syncStatus = ''});
}

final driveSyncServiceProvider = Provider<DriveSyncService>((ref) {
  return DriveSyncService();
});

class DriveSyncService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  bool get isSignedIn => _googleSignIn.currentUser != null;
  
  final ValueNotifier<SyncState> syncState = ValueNotifier(const SyncState());
  bool get isSyncing => syncState.value.isSyncing;

  Timer? _debounceTimer;
  Future<void> Function()? onBeforeBackup;

  void _updateStatus(String status, {double progress = -1.0, bool isSyncing = true}) {
    syncState.value = SyncState(isSyncing: isSyncing, syncProgress: progress, syncStatus: status);
  }

  void clearStatusWithDelay({String doneMessage = 'Sync Done'}) {
    _updateStatus(doneMessage, isSyncing: false);
    Future.delayed(const Duration(seconds: 3), () {
      if (!syncState.value.isSyncing) _updateStatus('', isSyncing: false);
    });
  }

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
  
  Future<drive.DriveApi?> _getDriveApi() async {
    if (!isSignedIn) return null;
    try {
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) return null;
      return drive.DriveApi(authClient);
    } catch (_) {
      return null;
    }
  }

  Stream<List<int>> _progressStream(File file, int totalSize, Function(double)? onProgress) async* {
    int bytesRead = 0;
    await for (final chunk in file.openRead()) {
      bytesRead += chunk.length;
      onProgress?.call((bytesRead / totalSize).clamp(0.0, 1.0));
      yield chunk;
    }
  }

  Future<void> backupDatabase({Function(double)? onProgress}) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception("Please sign in to Google first.");

    // Checkpoint WAL buffer to ensure all writes are on disk
    await onBeforeBackup?.call();
    
    // DB File path
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    if (!await file.exists()) throw Exception("Local database not found.");
    
    _updateStatus('Uploading to Google Drive...', progress: 0.0);
    
    // Check if backup already exists
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name='expense_tracker.sqlite'",
    );
    
    final length = await file.length();
    
    // Upload media stream
    final media = drive.Media(_progressStream(file, length, onProgress), length);
    final driveFile = drive.File()..name = 'expense_tracker.sqlite';
    
    drive.File? resultFile;
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      // Update existing
      final fileId = fileList.files!.first.id!;
      resultFile = await driveApi.files.update(
        driveFile,
        fileId,
        uploadMedia: media,
        $fields: 'id, modifiedTime',
      );
    } else {
      // Create new
      driveFile.parents = ['appDataFolder'];
      resultFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, modifiedTime',
      );
    }
    
    if (resultFile.modifiedTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_timestamp', resultFile.modifiedTime!.toUtc().toIso8601String());
      await prefs.setBool('local_has_unsynced_changes', false);
    }
    
    onProgress?.call(1.0); 

    await _syncImages(driveApi, isBackup: true);
  }

  Future<void> restoreDatabase({Function(double)? onProgress}) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception("Please sign in to Google first.");
    
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name='expense_tracker.sqlite'",
    );
    
    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception("No backup found in Google Drive.");
    }
    
    _updateStatus('Downloading from Google Drive...', progress: 0.0);
    
    final fileId = fileList.files!.first.id!;
    
    final drive.Media media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    
    final fileMeta = await driveApi.files.get(fileId, $fields: "size") as drive.File;
    final int totalSize = int.tryParse(fileMeta.size ?? '0') ?? 0;
    
    final dbFolder = await getApplicationDocumentsDirectory();
    final tempFile = File(p.join(dbFolder.path, 'db.sqlite.tmp'));
    final sink = tempFile.openWrite();
    
    int bytesDownloaded = 0;
    await for (var chunk in media.stream) {
      sink.add(chunk);
      bytesDownloaded += chunk.length;
      if (totalSize > 0) {
        onProgress?.call((bytesDownloaded / totalSize).clamp(0.0, 1.0));
      }
    }
    await sink.flush();
    await sink.close();

    // Verify temp file and atomically replace target
    if (await tempFile.length() > 0) {
      final walFile = File(p.join(dbFolder.path, 'db.sqlite-wal'));
      if (await walFile.exists()) {
        try { await walFile.delete(); } catch (_) {}
      }
      final shmFile = File(p.join(dbFolder.path, 'db.sqlite-shm'));
      if (await shmFile.exists()) {
        try { await shmFile.delete(); } catch (_) {}
      }

      final targetFile = File(p.join(dbFolder.path, 'db.sqlite'));
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
    }
    
    final prefs = await SharedPreferences.getInstance();
    if (fileList.files!.first.modifiedTime != null) {
      await prefs.setString('last_sync_timestamp', fileList.files!.first.modifiedTime!.toUtc().toIso8601String());
    }
    await prefs.setBool('local_has_unsynced_changes', false);
    
    onProgress?.call(1.0);

    await _syncImages(driveApi, isBackup: false);
  }

  /// Called when the database is modified locally
  void triggerAutoBackup() async {
    if (isSyncing) return; // Don't backup if we are currently restoring
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('local_has_unsynced_changes', true);

    final autoSync = prefs.getBool('auto_sync') ?? false;
    if (!autoSync) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () async {
      if (!isSignedIn) return;
      try {
        await backupDatabase(onProgress: (p) => _updateStatus('Auto Saving...', progress: p));
      } catch (_) {
      } finally {
        clearStatusWithDelay();
      }
    });
  }

  Future<int> getDriveUsage() async {
    if (!isSignedIn) return 0;
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return 0;
      
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        $fields: 'files(size)',
      );
      
      int totalSize = 0;
      for (var file in fileList.files ?? []) {
        totalSize += int.tryParse(file.size ?? '0') ?? 0;
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Performs an intelligent sync: uploads if local changes exist, otherwise downloads if cloud is newer.
  Future<SyncResult> performSmartSync({bool force = false, Future<void> Function()? onBeforeDownload}) async {
    if (!isSignedIn) return SyncResult.none;
    
    final prefs = await SharedPreferences.getInstance();
    final autoSync = prefs.getBool('auto_sync') ?? false;
    if (!autoSync && !force) return SyncResult.none;

    _updateStatus('Checking Sync Status...', progress: -1.0);
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return SyncResult.error;

      final hasUnsyncedChanges = prefs.getBool('local_has_unsynced_changes') ?? false;
      final lastSyncStr = prefs.getString('last_sync_timestamp');

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name='expense_tracker.sqlite'",
        $fields: 'files(id, modifiedTime)',
      );

      if (hasUnsyncedChanges) {
        // We have local changes that were never uploaded. Overwrite remote.
        await backupDatabase(onProgress: (p) => _updateStatus('Uploading to Google Drive...', progress: p));
        return SyncResult.uploaded;
      } else {
        if (fileList.files != null && fileList.files!.isNotEmpty) {
          final remoteFile = fileList.files!.first;
          final remoteTime = remoteFile.modifiedTime;
          
          if (remoteTime != null) {
            if (lastSyncStr == null) {
              // Never synced locally, but remote exists (e.g. new install)
              await onBeforeDownload?.call();
              await restoreDatabase(onProgress: (p) => _updateStatus('Downloading from Google Drive...', progress: p));
              return SyncResult.downloaded;
            } else {
              final localTime = DateTime.parse(lastSyncStr).toUtc();
              if (remoteTime.toUtc().isAfter(localTime)) {
                // Remote is newer, download it
                await onBeforeDownload?.call();
                await restoreDatabase(onProgress: (p) => _updateStatus('Downloading from Google Drive...', progress: p));
                return SyncResult.downloaded;
              } else {
                return SyncResult.upToDate;
              }
            }
          }
        }
      }
      return SyncResult.upToDate;
    } catch (_) {
      return SyncResult.error;
    } finally {
      clearStatusWithDelay();
    }
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_timestamp');
  }

  Future<void> _syncImages(drive.DriveApi driveApi, {required bool isBackup}) async {
    final prefs = await SharedPreferences.getInstance();
    final syncImages = prefs.getBool('sync_images') ?? true;
    if (!syncImages) return;

    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/expense_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final localFiles = imagesDir.listSync().whereType<File>().toList();
    final localNames = localFiles.map((f) => p.basename(f.path)).toSet();

    String pageToken = '';
    List<drive.File> remoteFiles = [];
    do {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "mimeType contains 'image/'",
        $fields: 'nextPageToken, files(id, name, size)',
        pageToken: pageToken.isEmpty ? null : pageToken,
      );
      remoteFiles.addAll(fileList.files ?? []);
      pageToken = fileList.nextPageToken ?? '';
    } while (pageToken.isNotEmpty);

    final remoteNames = remoteFiles.map((f) => f.name!).toSet();
    final remoteMap = { for (var f in remoteFiles) f.name!: f };
    final localMap = { for (var f in localFiles) p.basename(f.path): f };

    if (isBackup) {
      final toUpload = localNames.difference(remoteNames).toList();
      final toDeleteRemote = remoteNames.difference(localNames).toList();
      
      int totalOperations = toUpload.length + toDeleteRemote.length;
      if (totalOperations == 0) return;
      int completed = 0;

      for (var name in toUpload) {
        final file = localMap[name]!;
        final length = await file.length();
        final media = drive.Media(_progressStream(file, length, null), length);
        final driveFile = drive.File()
          ..name = name
          ..parents = ['appDataFolder'];
        
        _updateStatus('Uploading Image ${completed + 1} of $totalOperations...', progress: (completed / totalOperations).clamp(0.0, 1.0));
        await driveApi.files.create(driveFile, uploadMedia: media);
        completed++;
      }

      for (var name in toDeleteRemote) {
        _updateStatus('Cleaning Remote Image ${completed + 1} of $totalOperations...', progress: (completed / totalOperations).clamp(0.0, 1.0));
        await driveApi.files.delete(remoteMap[name]!.id!);
        completed++;
      }
    } else {
      final toDownload = remoteNames.difference(localNames).toList();
      final toDeleteLocal = localNames.difference(remoteNames).toList();
      
      int totalOperations = toDownload.length + toDeleteLocal.length;
      if (totalOperations == 0) return;
      int completed = 0;

      for (var name in toDownload) {
        _updateStatus('Downloading Image ${completed + 1} of $totalOperations...', progress: (completed / totalOperations).clamp(0.0, 1.0));
        final driveFile = remoteMap[name]!;
        final media = await driveApi.files.get(
          driveFile.id!,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
        
        final localFile = File('${imagesDir.path}/$name');
        final sink = localFile.openWrite();
        await media.stream.pipe(sink);
        await sink.close();
        completed++;
      }

      for (var name in toDeleteLocal) {
        _updateStatus('Cleaning Local Image ${completed + 1} of $totalOperations...', progress: (completed / totalOperations).clamp(0.0, 1.0));
        final file = localMap[name]!;
        if (await file.exists()) {
          await file.delete();
        }
        completed++;
      }
    }
  }
}

