# flutter_local_notifications (daily Guddi reminder) — the plugin stores scheduled notifications
# as JSON via Gson and reads them back with `new TypeToken<ArrayList<NotificationDetails>>(){}`.
# Without these rules R8 strips the generic Signature and obfuscates the stored field names, so in
# release builds every schedule/cancel after the first threw "Missing type parameter" (swallowed
# by the app's try/catch) and reboot rescheduling failed the same way. Verified in the held v1.3
# APK: the plugin's TypeToken subclass had no Signature annotation.
-keep class com.dexterous.** { *; }

# Gson — from google/gson's android-proguard-example
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
