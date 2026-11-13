import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static const String owner = 'AR0305';
  static const String repo = 'AR-Expense-Tracker';
  static const String _prefKeyLastCheck = 'last_github_update_check';
  static const int _throttleDurationMs = 12 * 60 * 60 * 1000; // 12 hours

  static Future<void> checkForUpdates(
    BuildContext context, {
    bool force = false,
    bool showNoUpdateFeedback = false,
  }) async {
    try {
      if (owner == 'YOUR_GITHUB_USERNAME' || repo == 'YOUR_REPOSITORY_NAME') {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_prefKeyLastCheck) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!force && (now - lastCheck < _throttleDurationMs)) {
        return;
      }

      // 1. Get the current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Ask GitHub for the latest release
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
      );

      // Record check timestamp on success or standard API responses
      if (response.statusCode == 200 || response.statusCode == 403) {
        await prefs.setInt(_prefKeyLastCheck, now);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
        // Find the direct APK download URL from the assets
        String? apkUrl;
        if (data['assets'] != null) {
          for (var asset in data['assets']) {
            if (asset['name'].toString().toLowerCase().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }
        }

        // 3. Compare the versions and ensure we found an APK
        if (_isNewerVersion(currentVersion, latestVersion) && apkUrl != null) {
          // 4. Show the Mandatory Auto-Download Dialog
          if (context.mounted) {
            _showMandatoryUpdateDialog(context, latestVersion, apkUrl);
          }
        } else if (_isNewerVersion(currentVersion, latestVersion) && apkUrl == null) {
          if (showNoUpdateFeedback && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('New version v$latestVersion available, but installation package is still preparing.')),
            );
          }
        } else {
          if (showNoUpdateFeedback && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AR Expense Tracker is up to date (v$currentVersion)')),
            );
          }
        }
      } else if (response.statusCode == 403) {
        if (showNoUpdateFeedback && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update check rate limited by GitHub. Please try again later.')),
          );
        }
      } else {
        if (showNoUpdateFeedback && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to check for updates (Status ${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (showNoUpdateFeedback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking for updates: $e')),
        );
      }
    }
  }

  static String _cleanVersion(String version) {
    // Strip leading 'v' or 'V'
    var clean = version.trim().replaceAll(RegExp(r'^[vV]'), '');
    // Take part before '+' (build metadata) and '-' (pre-release tag)
    clean = clean.split(RegExp(r'[\+-]')).first.trim();
    return clean;
  }

  static bool _isNewerVersion(String current, String latest) {
    try {
      final cleanCurrent = _cleanVersion(current);
      final cleanLatest = _cleanVersion(latest);

      final currentParts = cleanCurrent.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final latestParts = cleanLatest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      
      final maxLen = currentParts.length > latestParts.length ? currentParts.length : latestParts.length;
      for (int i = 0; i < maxLen; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static void _showMandatoryUpdateDialog(BuildContext context, String newVersion, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents dismiss on tap outside
      builder: (context) => PopScope(
        canPop: false, // Prevents dismiss on back button press
        child: _DownloadDialog(version: newVersion, url: apkUrl),
      ),
    );
  }
}

class _DownloadDialog extends StatefulWidget {
  final String version;
  final String url;

  const _DownloadDialog({required this.version, required this.url});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0.0;
  bool _downloading = true;
  bool _hasError = false;
  bool _isDownloaded = false;
  String _statusText = 'Starting download...';
  String? _savedApkPath;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;
  int _lastReportedPercent = -1;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _downloadAndInstall();
  }

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notificationsPlugin.initialize(initSettings);

      // Request notification permissions for Android 13+
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      }
      _notificationsInitialized = true;
    } catch (_) {}
  }

  Future<void> _updateProgressNotification(double progress) async {
    if (!_notificationsInitialized) return;
    final percent = (progress * 100).toInt().clamp(0, 100);
    if (percent == _lastReportedPercent) return; // Throttle IPC calls
    _lastReportedPercent = percent;

    final androidDetails = AndroidNotificationDetails(
      'update_channel',
      'App Updates',
      channelDescription: 'Download progress for app updates',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: percent,
      ongoing: true,
    );

    try {
      await _notificationsPlugin.show(
        999,
        'Downloading Update (v${widget.version})',
        '$percent%',
        NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }

  Future<void> _completeNotification() async {
    if (!_notificationsInitialized) return;
    const androidDetails = AndroidNotificationDetails(
      'update_channel',
      'App Updates',
      channelDescription: 'Download progress for app updates',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
    );

    try {
      await _notificationsPlugin.show(
        999,
        'Update Download Complete',
        'Tap to install v${widget.version}',
        const NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }

  Future<void> _errorNotification() async {
    if (!_notificationsInitialized) return;
    const androidDetails = AndroidNotificationDetails(
      'update_channel',
      'App Updates',
      channelDescription: 'Download progress for app updates',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
    );

    try {
      await _notificationsPlugin.show(
        999,
        'Update Download Failed',
        'Check your connection and tap to retry v${widget.version}',
        const NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }

  Future<void> _downloadAndInstall() async {
    if (mounted) {
      setState(() {
        _downloading = true;
        _hasError = false;
        _progress = 0.0;
        _statusText = 'Starting download...';
        _lastReportedPercent = -1;
      });
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/update_v${widget.version}.apk';
      _savedApkPath = savePath;

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      int receivedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      response.stream.listen(
        (List<int> chunk) {
          receivedBytes += chunk.length;
          sink.add(chunk);
          if (contentLength > 0 && mounted) {
            final currentProgress = receivedBytes / contentLength;
            setState(() {
              _progress = currentProgress;
              _statusText = 'Downloading... ${(_progress * 100).toStringAsFixed(1)}%';
            });
            _updateProgressNotification(currentProgress);
          }
        },
        onDone: () async {
          await sink.close();
          client.close();

          await _completeNotification();

          if (mounted) {
            setState(() {
              _downloading = false;
              _isDownloaded = true;
              _statusText = 'Download complete! Installing update...';
            });
          }

          _launchInstaller(savePath);
        },
        onError: (e) async {
          await sink.close();
          client.close();
          await _errorNotification();

          if (mounted) {
            setState(() {
              _downloading = false;
              _hasError = true;
              _statusText = 'Download failed. Please check your internet connection.';
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      await _errorNotification();
      if (mounted) {
        setState(() {
          _downloading = false;
          _hasError = true;
          _statusText = 'Error initializing download. Tap Retry.';
        });
      }
    }
  }

  Future<void> _launchInstaller(String path) async {
    final result = await OpenFilex.open(path);

    if (result.type != ResultType.done && mounted) {
      setState(() {
        _statusText = 'Ready to install. Tap below if the package installer did not open automatically.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Icon(
            _hasError
                ? Icons.error_outline_rounded
                : (_isDownloaded ? Icons.system_update_rounded : Icons.system_update_rounded),
            size: 54,
            color: _hasError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _hasError ? 'Download Interrupted' : 'Update Available!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _hasError
                ? 'The update download could not complete due to a network interruption. Tap Retry to continue.'
                : 'Version ${widget.version} is downloading. We are preparing everything for you in the background.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (_downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _hasError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
            ),
          ),
          if (_hasError) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _downloadAndInstall,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Download'),
            ),
          ],
          if (_isDownloaded && !_downloading) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (_savedApkPath != null) {
                  _launchInstaller(_savedApkPath!);
                }
              },
              icon: const Icon(Icons.download_done_rounded),
              label: const Text('Install Now'),
            ),
          ],
        ],
      ),
    );
  }
}
