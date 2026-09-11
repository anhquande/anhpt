# Keep ML Kit/Firebase component registrars used through reflection.
#
# Release APKs are processed by R8. ML Kit discovers these registrars via
# AndroidX/Firebase component discovery, so they can look unused to the
# optimizer even though they are required at process startup.
#
# Without these rules Android release builds can crash before Flutter starts
# with NoSuchMethodException for registrar no-arg constructors.
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keep class com.google.firebase.components.ComponentRegistrar { *; }

# Keep ML Kit registrar classes and their constructors/members. The { *; }
# body is intentional: R8 full mode does not implicitly retain constructors
# just because a class is retained.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

# Preserve metadata used by generated ML Kit/Firebase component discovery.
-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature
