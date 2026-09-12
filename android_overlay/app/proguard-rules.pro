# ProGuard/R8 keep rules for Schedule Phoner.
#
# flutter_local_notifications (via Gson) needs generic type signatures preserved
# for SCHEDULED notifications to deserialize at runtime. Without these, release
# (R8-shrunk) builds crash with "TypeToken must be created with a type argument"
# the moment a scheduled notification is created — while instant notifications
# still work. These are the plugin's officially recommended rules.

## Gson rules
-keepattributes Signature
-keepattributes *Annotation*
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

## flutter_local_notifications
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
