## Flutter-specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

## Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

## Google Play Core (needed for Flutter deferred components / R8)
-dontwarn com.google.android.play.core.**

## Suppress warnings for common libraries
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.** { *; }
