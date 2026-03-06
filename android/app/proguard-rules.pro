-keepattributes Signature
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class com.google.gson.** { *; }

# device_calendar plugin — Gson uses reflection to serialize these models.
# Without this, R8 obfuscates field names and the Dart side gets null fields.
-keep class com.builttoroam.devicecalendar.** { *; }
