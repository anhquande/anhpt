# Keep Android startup components that are discovered or generated through reflection.
#
# Release APKs are processed by R8. AndroidX Startup, WorkManager, Room, and
# ML Kit/Firebase component discovery all instantiate classes indirectly during
# process startup, before Flutter is initialized. If constructors or generated
# database implementations are optimized away, the app can crash immediately on
# Android release builds.

# AndroidX Startup / Initializer classes.
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }

# WorkManager owns androidx.work.impl.WorkDatabase, which Room instantiates at
# startup through generated implementation classes.
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class **_Impl { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# ML Kit/Firebase component registrars used through reflection.
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keep class com.google.firebase.components.ComponentRegistrar { *; }

# Keep ML Kit registrar classes and their constructors/members. The { *; }
# body is intentional: R8 full mode does not implicitly retain constructors
# just because a class is retained.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

# Preserve metadata used by generated AndroidX/Room/ML Kit/Firebase code.
-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature
