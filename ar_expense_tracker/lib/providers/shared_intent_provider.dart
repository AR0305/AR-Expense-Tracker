import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedIntentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPath(String path) {
    state = path;
  }
  
  void clear() {
    state = null;
  }
}

final sharedImagePathProvider = NotifierProvider<SharedIntentNotifier, String?>(() => SharedIntentNotifier());

class PendingWidgetUriNotifier extends Notifier<Uri?> {
  @override
  Uri? build() => null;

  void setUri(Uri uri) {
    state = uri;
  }

  void clear() {
    state = null;
  }
}

final pendingWidgetUriProvider = NotifierProvider<PendingWidgetUriNotifier, Uri?>(() => PendingWidgetUriNotifier());
