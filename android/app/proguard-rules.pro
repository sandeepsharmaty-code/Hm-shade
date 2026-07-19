# Hue Muse Shade AI — ProGuard / R8 rules.
#
# Currently INERT: android/app/build.gradle has minifyEnabled false /
# shrinkResources false for the release build type, so R8 does not
# run and these rules have no effect on the current build. This file
# exists so that (a) the release configuration checklist item is
# satisfied, and (b) if code shrinking is ever turned on later, the
# standard keep rules for this app's dependency set are already in
# place instead of being discovered via a crash.
#
# Flutter's own embedding classes are kept automatically by the
# Flutter Gradle plugin's default consumer ProGuard rules; the rules
# below only cover this app's specific dependencies that are known to
# need explicit keep rules under R8 (reflection-based JSON parsing,
# sqflite's native bindings).

# sqflite (SQLite bindings)
-keep class com.tekartik.sqflite.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep this app's own model classes that use dynamic Map-based
# (de)serialization (see lib/models/*_model.dart fromMap/toMap),
# since R8 cannot statically trace reflection-free Map<String,dynamic>
# field access, but member names are still worth preserving for
# stack-trace readability in crash reports.
-keepclassmembers class com.huemuse.hue_muse_shade_ai.** { *; }
