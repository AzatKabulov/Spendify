# Spendly R8/ProGuard keep rules (Phase 12).
#
# Flutter's own default rules (bundled with the Gradle plugin) already cover the
# engine and embedding. These are the app-specific additions.

# --- Flutter deferred components / Play Core -------------------------------
# flutter.jar references these even when the app has no dynamic feature modules.
# Without the keep, R8 warns and can strip the split-install shim.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# --- Hive -----------------------------------------------------------------
# Adapters are generated Dart (compiled to native), not reflected over on the
# JVM side, so Hive itself needs nothing here. Listed for the next maintainer:
# if a TypeAdapter ever moves to reflection, add its keep here.

# --- Firebase (Auth + Firestore) ----------------------------------------
# Firestore serialises model classes via reflection. Spendly only ever writes
# Map<String,Object?> (see data/remote/firestore_mappers.dart), so no app model
# is reflected — but keep Firebase's own annotated types and enum valueOf().
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- Gemini calls go over plain https (package:http) --------------------
# No generated gRPC/proto stubs; nothing to keep. OkHttp is not used.

# --- Tink / flutter_secure_storage ------------------------------------
# The encrypted-Hive key lives in the Android Keystore via this plugin, which
# pulls in Tink. Tink uses reflection + protos for its key registry.
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-keep class * extends com.google.crypto.tink.shaded.protobuf.GeneratedMessageLite { *; }

# --- Keep source file + line numbers for readable crash traces ---------
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
