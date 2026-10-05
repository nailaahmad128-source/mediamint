# FFmpegKit uses reflection for its native bridge — keep its classes intact
# under R8/ProGuard so release builds don't strip anything the JNI layer
# needs at runtime.
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.** { *; }

# file_picker / share_plus / open_filex plugin embedding classes
-keep class io.flutter.plugins.** { *; }
