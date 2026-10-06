# Release builds shrink code with R8. flutter_local_notifications stores
# scheduled notifications with Gson, which needs generic type info kept, or
# the app crashes on any notification call (schedule / cancel) in release.
# See the plugin README "Release build configuration" and Gson's rules.

-keep class com.dexterous.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod,InnerClasses
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# WorkManager (used for the background widget/nudge refresh) creates its Room
# database by reflection; R8 removed the no-arg constructor and the app
# crashed at startup ("NoSuchMethodException: WorkDatabase_Impl.<init>").
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }
