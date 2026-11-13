-dontwarn com.google.mlkit.vision.text.**
-dontwarn es.antonborri.home_widget.**

# Keep Flutter plugin registration
-keep class io.flutter.plugins.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep class com.example.ar_expense_tracker.** { *; }

# Keep SQLite native bindings for Drift
-keep class net.simonvt.schematic.** { *; }
-keep class io.requery.android.database.sqlite.** { *; }

# Keep Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
